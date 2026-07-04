module GhosttyExtensions

using Base64: base64decode, base64encode
using REPL
using REPL.LineEdit
import Base: display

export inlineplotting, pixelsize
export page, pbcopy, pbpaste

include("lineedit.jl")
include("plotting.jl")
include("shellintegration.jl")

"""
    GhosttyExtensions.keyreader() -> Nothing

Put the terminal in raw mode and show the keyboard input (including escape sequences) in a
human readable form. This function is intended for debugging and is not exported. Errors if
stdin isn't a tty.
"""
function keyreader()
    stdin isa Base.TTY || error("keyreader() requires an interactive terminal")
    println("Press backspace twice to exit the key reader...")
    term = REPL.Terminals.TTYTerminal("xterm", stdin, stdout, stderr)
    REPL.Terminals.raw!(term, true)
    exit_on_next_bksp = false
    while true
        c = read(stdin, Char)
        if isprint(c)
            print(c)
        else
            printstyled('\n', escape_string(string(c)); color = :red)
        end
        if c == '\x7f'
            exit_on_next_bksp && break
            exit_on_next_bksp = true
        else
            exit_on_next_bksp = false
        end
    end
    println()
    return nothing
end

function _atreplinit_hook(repl)
    if isinteractive() && repl isa REPL.LineEditREPL
        shellintegration(repl)
        inlineplotting()
    end
    return nothing
end

function __init__()
    atreplinit(_atreplinit_hook)
    return nothing
end

# Write `request` to the terminal and block for its answer up to `terminator`, in raw mode
# so the response bytes don't leak into the REPL buffer.
# Returns `nothing` if stdin isn't a tty, or if the terminal doesn't answer within `timeout`
# seconds. Most terminals answer these queries in well under a millisecond; half a second
# is a generous bound for a slow/loaded terminal while still capping the wait instead of
# blocking forever (e.g. tmux/screen without escape-sequence passthrough).
function query_terminal(request::AbstractString, terminator; timeout = 0.5)
    stdin isa Base.TTY || return nothing
    term = REPL.Terminals.TTYTerminal("xterm", stdin, stdout, stderr)
    REPL.Terminals.raw!(term, true)
    Base.start_reading(stdin)
    print(stdout, request)
    task = @async readuntil(stdin, terminator)
    timer = Timer(timeout) do _
        istaskdone(task) || Base.schedule(task, InterruptException(); error = true)
    end
    return try
        fetch(task)
    catch
        nothing
    finally
        close(timer)
    end
end

# Precompile statements for the code paths that run on every REPL startup
# (`_atreplinit_hook` is what Julia's `atreplinit` machinery actually calls — it's a
# regular top-level function rather than a closure specifically so it *can* be targeted
# here) plus the functions users are likely to call right from `startup.jl`.
precompile(_atreplinit_hook, (REPL.LineEditREPL,))
precompile(shellintegration, (REPL.LineEditREPL,))
precompile(inlineplotting, ())
precompile(inlineplotting, (Bool,))
precompile(display, (KittyDisplay, Vector{UInt8}))
precompile(display, (KittyDisplay, MIME"image/png", Vector{UInt8}))
precompile(pixelsize, ())
precompile(pixelsize, (Float64,))
precompile(pixelsize, (Float64, Float64))
precompile(cellsize, ())
precompile(pbcopy, (String,))
precompile(pbpaste, ())
precompile(page, (String,))
precompile(set_terminal_title, ())
precompile(keyreader, ())

end # module GhosttyExtensions
