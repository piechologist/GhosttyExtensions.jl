module GhosttyExtensions

using Base64: base64decode, base64encode
using REPL
using REPL.LineEdit
using TerminalPager
import Base: display

export TerminalPager, pager, @help, @out2pr, @stdout_to_pager
export inlineplotting, pixelsize
export pbcopy, pbpaste
public keyreader

include("lineedit.jl")
include("plotting.jl")
include("shellintegration.jl")

# Extra key bindings.
#
# Tip: the following keys are not used in LineEdit.jl and can be bound to custom functions:
# - Meta + all capital letters except O and W
# - Meta + any of aghijkoqrsvxz
# - ^o and ^v
#
# Note: the history keymap is active when the cursor is at the end of the buffer. It will
# swallow the first part of certain bindings and the remaining part will leak into the
# terminal. We need to add wildcards for these bindings to let them pass through.
# See `LineEdit.prefix_history_keymap` for the default wildcards.
const extra_keymap = Dict{Any,Any}(
    "\eOP" => (s, o...) -> invoke_help(s), # F1
    "\eOQ" => (s, o...) -> parenthesize(s), # F2
    "\e[24~" => (s, o...) -> toggle_prefix(s, "@time"), # F12
    "\e[24;2~" => (s, o...) -> toggle_prefix(s, "@code_warntype"), # Shift-F12
    "\eC" => (s, o...) -> copy_region(s),
    "\eX" => (s, o...) -> cut_region(s),
    "\eV" => (s, o...) -> run_pasteboard(s),
    # Shift-Option-Up/Down/Right/Left:
    "\e[1;4A" => (s, o...) -> select_to_start_of_buffer(s),
    "\e[1;4B" => (s, o...) -> select_to_end_of_buffer(s),
    "\e[1;4C" => (s, o...) -> LineEdit.edit_shift_move(s, LineEdit.edit_move_word_right),
    "\e[1;4D" => (s, o...) -> LineEdit.edit_shift_move(s, LineEdit.edit_move_word_left),
    # Shift-Command-Right/Left:
    "\e[1;10C" => (s, o...) -> select_to_end_of_line(s),
    "\e[1;10D" => (s, o...) -> select_to_start_of_line(s),
)

const extra_wildcards = Dict{Any,Any}(
    "\e[24~" => "*",    # F12
    "\e[24;2~" => "*",  # Shift-F12
    "\e[1;4*" => "*",   # Shift-Option-ArrowKeys
    "\e[1;10*" => "*",  # Shift-Command-ArrowKeys
)

"""
    GhosttyExtensions.keyreader() -> nothing

Put the terminal in raw mode and show the keyboard input (including escape sequences) in a
human readable form. This function is intended for debugging and is not exported.
"""
function keyreader()
    println("Press backspace twice to exit the key reader...")
    term = REPL.Terminals.TTYTerminal("xterm", stdin, stdout, stderr)
    REPL.Terminals.raw!(term, true)
    exit_on_next_bksp = false
    while true
        c = read(stdin, Char)
        if isprint(c)
            print(c)
        else
            printstyled('\n', escape_string(string(c)); color=:red)
        end
        if c == '\x7f'
            exit_on_next_bksp && break
            exit_on_next_bksp = true
        else
            exit_on_next_bksp = false
        end
    end
    println()
end

function __init__()
    atreplinit() do repl
        if isinteractive() && repl isa REPL.LineEditREPL
            if isdefined(repl, :interface)
                error("another package has already initialized the REPL")
            end

            # Set up the REPL with the custom key bindings.
            merge!(LineEdit.prefix_history_keymap, extra_wildcards)
            repl.interface = REPL.setup_interface(repl; extra_repl_keymap=extra_keymap)

            # Set up the shell integration and KittyDisplay.
            shellintegration(repl)
            inlineplotting()
        end
    end
    return nothing
end

end # module GhosttyExtensions
