# ------------------------------------------------------------------------------------------
# Functions for Ghostty's shell integration
# ------------------------------------------------------------------------------------------

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
"""
function pbpaste()
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
    # 2. We use `project` similarily. Base.ACTIVE_PROJECT is very cheap to access and we
    #    read it frequently to check if the project has changed. If it has, we call the
    #    relatively expensive set_terminal_title().
    # 3. Ghostty clears the prompt on window resize and sends SIGWINCH, expecting the shell
    #    to redraw the prompt. Since the REPL doesn't catch signals at all, we ask Ghostty
    #    not to clear the prompt with the parameter redraw=0 inside the prompt start mark.
    isexecuting = true
    project::Union{Nothing,String} = "not initialized yet"

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
            return "\e]133;A;redraw=0\a" * (prefix isa Function ? prefix() : prefix)
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
