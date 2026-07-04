# ------------------------------------------------------------------------------------------
# Functions for Ghostty's shell integration
# ------------------------------------------------------------------------------------------

"""
    page(text::AbstractString; lessargs=String[]) -> Nothing
    page(x; lessargs=String[]) -> Nothing

Display `text` in the `less` pager (flags `-RKS`: keep ANSI colors, quit on interrupt, chop
long lines instead of wrapping). The prompt shows the line range like less's default `-M`
prompt (`lines %lt-%lb/%L`) plus, once you scroll right, the leftmost visible column.
`less` reads its keystrokes from `/dev/tty`, so it coexists with the REPL being mid-
keystroke, and its alternate screen restores the prior view on quit so nothing lingers.

`lessargs` passes extra arguments to `less`; give a single string or a collection of
strings, e.g. `page(text; lessargs="--header=1,4")`.

The second form renders any object `x` to its full REPL (`text/plain`) representation — with
color and no truncation — before paging it, e.g. `rand(200, 100) |> page`.
"""
function page(text::AbstractString; lessargs = String[])
    isempty(text) && return nothing
    prompt = raw"lines %lt-%lb?L/%L.?e (END):?pB %pB\%..?c │ first char #%c."
    try
        open(`less -RKS -PM$prompt $lessargs`, "w", stdout) do io
            write(io, text)
        end
    catch err
        # Quitting the pager before all input is read closes the pipe mid-write; ignore that.
        err isa Base.IOError && err.code == Base.UV_EPIPE || rethrow()
    end
    return nothing
end

function page(x; lessargs = String[])
    buf = IOBuffer()
    # No :displaysize/:limit -> render `x` in full and let `less -S` scroll wide output.
    io = IOContext(buf, :color => true)
    show(io, MIME("text/plain"), x)
    page(String(take!(buf)); lessargs)
    return nothing
end

"""
    pbcopy(x) -> Nothing

Copy the object `x` to the system pasteboard as text.
This uses OSC 52 and thus works via ssh.
"""
function pbcopy(x)
    print("\e]52;c;", base64encode(string(x)), "\a")
    return nothing
end

"""
    pbpaste() -> String

Query the system pasteboard and return its content as `String`.
This uses OSC 52 and thus works via ssh.
Returns `""` if stdin isn't a tty or the terminal doesn't answer the query.
"""
function pbpaste()
    stdin isa Base.TTY || return ""
    term = REPL.Terminals.TTYTerminal("xterm", stdin, stdout, stderr)
    REPL.Terminals.raw!(term, true)
    Base.start_reading(stdin)
    print(stdout, "\e]52;c;?\a")
    data = readuntil(stdin, "\e\\")
    startswith(data, "\e]52;c;") || return ""
    return String(base64decode(chopprefix(data, "\e]52;c;")))
end

function set_terminal_title()
    remote_host = haskey(ENV, "SSH_TTY") ? split(gethostname(), '.')[1] * " — " : ""
    project = dirname(Base.active_project())
    title = contains(project, "/.julia/environments/") ? "julia @" : "julia "
    print("\e]2;", remote_host, title, basename(project), "\e\\")
    return nothing
end

function shellintegration(repl)
    # Notes:
    # 1. prompt_prefix & prompt_suffix may get fired many times when editing a command or
    #    scrolling through the command history. We use `isexecuting` to track the current
    #    state and print the post-exec mark only once.
    # 2. We use `project` similarly. Base.ACTIVE_PROJECT is very cheap to access and we
    #    read it frequently to check if the project has changed. If it has, we call the
    #    relatively expensive set_terminal_title().
    # 3. Ghostty clears the prompt on window resize and sends SIGWINCH, expecting the shell
    #    to redraw the prompt. Since the REPL doesn't catch signals at all, we ask Ghostty
    #    not to clear the prompt with the parameter redraw=0 inside the prompt start mark.
    # 4. Ghostty v1.3.0+ emits mouse click events to move the cursor within the prompt.
    #    Expl.: `\e[<0;6;20M` -> press left button, column 6, row 20 of the terminal window
    #    The REPL doesn't understand this sequence and we must fall back to a number of
    #    left/right arrow presses. Moving up/down on a multi-line prompt doesn't work
    #    either (this would be the OSC 133 A option `cl=m` or `cl=v`). So what's left is
    #    moving left or right on the exact line the cursor is on (option `cl=line`).
    #    See:
    #    https://github.com/ghostty-org/ghostty/blob/2502ca294efe5aa9722c36e25b2252b0150054e9/src/terminal/osc/parsers/semantic_prompt.zig#L218
    isexecuting = true
    project::Union{Nothing, String} = "not initialized yet"

    # Prompt marking and cursor shaping for the first three modes julia>, shell>, help?>.
    for mode in repl.interface.modes[1:3]
        prefix = mode.prompt_prefix
        mode.prompt_prefix = function ()
            if isexecuting
                isexecuting = false
                # Print the post-exec mark, set the cursor shape to bar:
                print("\e]133;D\a", "\e[5 q")
            end
            if project ≠ Base.ACTIVE_PROJECT.x
                project = Base.ACTIVE_PROJECT.x
                set_terminal_title()
            end
            # Prepend the prompt start mark:
            return "\e]133;A;cl=line;redraw=0\a" * (prefix isa Function ? prefix() : prefix)
        end

        suffix = mode.prompt_suffix
        mode.prompt_suffix = function ()
            # Append the prompt end mark:
            return (suffix isa Function ? suffix() : suffix) * "\e]133;B\a"
        end

        of = mode.on_done
        mode.on_done = function (args...)
            isexecuting = true
            # Set the cursor shape to block, print the pre-exec mark:
            print("\e[0 q", "\e]133;C\a")
            return of(args...)
        end
    end
    return nothing
end
