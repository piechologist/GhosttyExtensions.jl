# GhosttyExtensions

A Julia package that supports some advanced features of the
[Ghostty](https://ghostty.org) terminal emulator.
[WezTerm](https://wezfurlong.org/wezterm/index.html) or
[Kitty](https://sw.kovidgoyal.net/kitty/) should work as well.

All features work over ssh. There's no external dependency and _TTFP_, the time
it adds to the first prompt, should not be noticeable.

It works fine alongside TerminalPager.jl but has **not** been tested for
compatibility with other packages that alter the REPL.

> [!IMPORTANT]
>
> **BREAKING CHANGES IN VERSION 0.9.0**
>
> This version is tested on Julia 1.12 and 1.13. The `[compat]` bound also allows 1.10 and
> 1.11 since nothing in the code appears to require newer internals, but this is
> **untested** — try at your own risk.
>
> GhosttyExtensions v0.8.1 is still compatible with Julia 1.10–1.12. Refer to the README on
> the v0.8.1 branch.
>
> Some bad hacks have been removed in this version to make the package more robust. The
> order of `using GhosttyExtensions` and `using TerminalPager` does not matter anymore.
> On the other hand, you can no longer bind F12, Shift-Command-ArrowKey etc.
>
> The key bindings that were defined in v0.8.1 and earlier have been removed. You need to
> set up your own keymap, see the example in [Installation](#installation) below.
>
> See the new feature [Pager](#pager) that calls the system's `less` command-line tool.

## Features

### Shell integration

The terminal title shows the active project and — if the environment variable
`SSH_TTY` is set — the remote user@hostname (OSC 2).

`pbcopy(x)` and `pbpaste()` add pasteboard support for copy'n'paste that works
over ssh (OSC 52).

Prompt marking (OSC 133) for the prompt modes `julia>`, `shell>`, and `help?>`
enables jumping back and forth through the prompts (Ghostty defaults:
Shift-Command-Up/Down) or selecting & copying the output between two prompts
(Command-Triple-Click).

Mouse click events move the cursor to the clicked position in the command
buffer. This requires Ghostty 1.3.0+. Limitation: the cursor does not move up or
down on multi-line prompts — it only moves left or right on the line it's on.

### Inline plotting

This feature implements the Kitty graphics protocol for use with Plots.jl. Plots
are shown in the terminal window as PNGs in their original sizes. There is no
scaling, which makes plots less blurred, and there's no need for any
dependencies. Use KittyTerminalImages.jl if you need more features.

Inline plotting is automatically activated in interactive sessions and works
over ssh. In non-interactive scripts, call `inlineplotting()` once to
initialize, and remember to wrap the plot commands with `display(...)`. Switch
back to the default (e.g., GKSQT.app on macOS) with `inlineplotting(false)` —
this only works on the local machine.

Get the size of the terminal window in pixels with `pixelsize()`. See the
docstring (`?pixelsize`) for examples about adjusting the plot size or setting
default sizes. There's also an example in [Installation](#installation) below.

### Pager

You can ignore this feature if you have TerminalPager.jl installed.

`page(x)` or `x |> page` sends anything to the `less` command-line tool that
usually comes with BSD, Linux, and macOS. It renders the full REPL
representation of `x` — colored and not truncated — and pages it with horizontal
scrolling for wide output (using `less -S` to chop long lines). A string is
paged verbatim.

Extra arguments can be passed to `less` with the `lessargs` keyword, e.g.
`page(x; lessargs="--header=1,8")` for 1 frozen header line and 8 frozen
columns.

The F1 help also uses this pager via `invoke_help` (see below).

### Extra functions for key bindings (not exported)

- `invoke_help` shows the help for the selection or the word under the cursor in the pager.

- `parenthesize` wraps the buffer in parentheses and moves the cursor to the start.

- `copy_region` copies the selection or the whole buffer to the system clipboard via OSC 52.

- `cut_region` cuts the selection or the whole buffer to the system clipboard via OSC 52.

- `toggle_prefix` prepends a string to the buffer, e.g. `@time`, or removes it
  if it's already there.

- `toggle_suffix` appends a string to the buffer, e.g. `|> page` to send the
  line's result to the pager, or removes it if it's already there.

- `run_pasteboard` pastes from the system clipboard via OSC 52 and executes.
  This is intended for automation. For instance, you may want to use AppleScript
  or another tool to copy code from your GUI editor and paste & execute it in
  Ghostty.

  Each time, you'll be asked for permission to access the system clipboard,
  unless you opt in permanently in `~/.config/ghostty/config.ghostty`:

  `clipboard-read = allow`

  Note that allowing it permanently is a security risk as any program running in
  the terminal — including a rogue AI agent — can stalk your clipboard.

- `select_previous_word`, `select_next_word` start or extend a selection by word.

- `select_to_start_of_line`, `select_to_end_of_line` start or extend a selection
  up to the start/end of the line.

- `select_to_start_of_buffer`, `select_to_end_of_buffer` start or extend a
  selection up to the start/end of the buffer.

### Utility functions (not exported)

Explore key strokes (inspired by
[fish_keyreader](https://fishshell.com/docs/current/cmds/fish_key_reader.html),
useful for making your own keybinds):

```julia
julia> GhosttyExtensions.keyreader()
```

Return the size of a terminal cell in pixels. A cell is the space that's
occupied by one character (useful for debugging):

```julia
julia> GhosttyExtensions.cellsize()
```

## Installation

This package is not available in Julia's general registry. It can be added or dev'd with:

```julia
Pkg> add https://github.com/piechologist/GhosttyExtensions.jl
```

You need to set up your own key bindings in `~/.julia/config/startup.jl`.
A comprehensive example:

```julia
using GhosttyExtensions

# Example: make plots with a height 45 % of the terminal window and twice as wide as high.
# The IdDict precompiles faster than a regular Dict in this case.
# Note: `PLOTS_DEFAULTS` will be renamed to `PLOTSBASE_DEFAULTS` in Plots.jl v2.
if get(ENV, "TERM", "") == "xterm-ghostty"
    PLOTS_DEFAULTS = IdDict(:size => pixelsize(0.45; ratio = 2), :thickness_scaling => 1.5)
end

const mykeys = Dict{Any, Any}(
    # Bind F1 to the internal pager (drop this if you use TerminalPager.jl):
    "\eOP" => (s, o...) -> GhosttyExtensions.invoke_help(s), # F1
    "\eOQ" => (s, o...) -> GhosttyExtensions.parenthesize(s), # F2
    "\eC" => (s, o...) -> GhosttyExtensions.copy_region(s), # Meta-C
    "\eX" => (s, o...) -> GhosttyExtensions.cut_region(s), # Meta-X
    "\eT" => (s, o...) -> GhosttyExtensions.toggle_prefix(s, "@time"), # Meta-T
    "\eW" => (s, o...) -> GhosttyExtensions.toggle_prefix(s, "@code_warntype"), # Meta-W
    "\eP" => (s, o...) -> GhosttyExtensions.toggle_suffix(s, "|> page"), # Meta-P
    "\eV" => (s, o...) -> GhosttyExtensions.run_pasteboard(s), # Meta-V
    # Example: Shift-Option-B on a US Mac keyboard (@btime requires BenchmarkTools.jl):
    "ı" => (s, o...) -> GhosttyExtensions.toggle_prefix(s, "@btime"),
    # Control-Up/Down/Right/Left:
    "\e[1;5A" => (s, o...) -> GhosttyExtensions.select_to_start_of_buffer(s),
    "\e[1;5B" => (s, o...) -> GhosttyExtensions.select_to_end_of_buffer(s),
    "\e[1;5C" => (s, o...) -> GhosttyExtensions.select_next_word(s),
    "\e[1;5D" => (s, o...) -> GhosttyExtensions.select_previous_word(s),
    # Control-End/Home:
    "\e[1;5F" => (s, o...) -> GhosttyExtensions.select_to_end_of_line(s),
    "\e[1;5H" => (s, o...) -> GhosttyExtensions.select_to_start_of_line(s),
)

atreplinit() do repl
    # Set up the keymap from above.
    repl.interface = GhosttyExtensions.REPL.setup_interface(repl; extra_repl_keymap = mykeys)

    # Bonus: print only a few lines of large arrays etc., don't fill the whole terminal
    # window (similar to `R`'s REPL). Use `|> page` to browse through the whole object.
    lines, columns = displaysize(stdout)
    repl.options.iocontext[:displaysize] = min(15, lines), columns
end
```

> [!TIP]
>
> The following keys are not used in the REPL by default (defined in LineEdit.jl in the
> REPL stdlib) and can be bound to custom functions:
>
> - F1, F2, F3, F4 (`\eOP`, `\eOQ`, `\eOR`, `\eOS`)
> - Meta + all capital letters except O and W (`\eA` ... `\eZ`)
> - Meta + any of a, g, h, i, j, k, o, q, r, s, v, x, z (`\ea` ... `\ez`)
> - ^o and ^v
>
> Other key combinations can be problematic because the history keymap is active
> when the cursor is at the end of the buffer. It will swallow the first part of certain
> bindings and the remaining part will leak into the terminal.
>
> See `GhosttyExtensions.LineEdit.prefix_history_keymap |> page` for the default wildcards
> that prevent this kind of leaking. Avoid bindings that are not covered there.

> [!IMPORTANT]
>
> Loading GhosttyExtensions manually after the REPL has been initialized won't work.

## Credits

- [Ghostty](https://github.com/ghostty-org/ghostty)

- [TerminalExtensions.jl](https://github.com/Keno/TerminalExtensions.jl)

- [TerminalPager.jl](https://github.com/ronisbr/TerminalPager.jl)

- [KittyTerminalImages.jl](https://github.com/simonschoelly/KittyTerminalImages.jl)

- [Kitty terminal graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)

- The Julia Documentation:
  [The Julia REPL](https://docs.julialang.org/en/v1.13.0/stdlib/REPL/#Customizing-keybindings)

- The Julia 1.13 source, particularly `edit(Sys.STDLIB * "/REPL/src/LineEdit.jl")`
