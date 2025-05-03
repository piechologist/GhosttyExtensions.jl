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
const extra_keymap = Base.AnyDict(
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
    # Kitty Keyboard Protocol:
    "\e[99;9u" => (s, o...) -> copy_region(s), # Command-C
    "\e[120;9u" => (s, o...) -> cut_region(s), # Command-X
)


const extra_wildcards = merge!(
    Base.AnyDict(
        "\e[24~" => "*",    # F12
        "\e[24;2~" => "*",  # Shift-F12
        "\e[1;4*" => "*",   # Shift-Option-ArrowKeys
        "\e[1;10*" => "*",  # Shift-Command-ArrowKeys
    ),
    # Kitty Keyboard Protocol:
    Base.AnyDict("\e[$(n);5u" => "*" for n in 97:122), # ^A..^Z
    Base.AnyDict("\e[$(c)" => "*" for c in 'P':'S'),   # F1..F4
    Base.AnyDict(
        "\e[27u" => "*",    # Escape
        "\e[99;9u" => "*",  # Command-C
        "\e[120;9u" => "*", # Command-X
    ),
)

# This table translates problematic escape sequences from the Kitty Keyboard Protocol to the
# REPL's legacy encoding. The other key bindings should work out of the box.
#
# The Kitty Keyboard Protocol
# https://sw.kovidgoyal.net/kitty/keyboard-protocol/
#   print("\e[>1u") # turn it on
#   print("\e[<u") # turn it off
const kitty_escape_defaults = merge!(
    Base.AnyDict("\e[$(n);5u" => LineEdit.KeyAlias('^' * Char(n - 32)) for n in 97:122),
    Base.AnyDict("\e[$(c)" => LineEdit.KeyAlias("\eO$c") for c in 'P':'S'),
    Base.AnyDict(
        "\e[9;2u" => LineEdit.KeyAlias("\e[Z"),   # Shift-Tab
        "\e[9;3u" => LineEdit.KeyAlias("\e[Z"),   # Option-Tab
        "\e[13;3u" => LineEdit.KeyAlias("\e\r"),  # Option-Return
        "\e[127;3u" => LineEdit.KeyAlias("\e\b"), # Option-Backspace
        "\e[120;5u" => LineEdit.KeyAlias("^X^X"), # ^X (this keeps the REPL from crashing)
        "\e[27u" => LineEdit.KeyAlias("^G"),      # Escape (cancel a selection)
    ),
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
            print("\e[>1u") # tell the terminal to use the Kitty Keyboard Protocol
            merge!(LineEdit.escape_defaults, kitty_escape_defaults)
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
