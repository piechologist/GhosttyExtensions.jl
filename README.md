# GhosttyExtensions

A Julia package that supports some advanced features of the [Ghostty](https://ghostty.org) terminal emulator.
[WezTerm](https://wezfurlong.org/wezterm/index.html) or [Kitty](https://sw.kovidgoyal.net/kitty/) should work as well.

All features work over ssh. There's no external dependency and _TTFP_, the time it adds to the first prompt, 
should not be noticeable.

This package requires Julia 1.10 or higher. It has **not** been tested for compatibility with
other packages that alter the REPL e.g., OhMyREPL.

> [!IMPORTANT]
>
> ## [BREAKING] News for GhosttyExtensions 0.8.0
>
> The F1 key binding to invoke the Julia help and the dependency on TerminalPager.jl has been removed. 
> TerminalPager 0.6.5 comes with its own, smart F1 binding and should be installed separately. Mind the
> note in the [Installation](#installation) section below!
>
> The size of plots is slightly smaller now (5 pixels) because Ghostty 1.2 places images differently.
>
> Control-Command-C and Control-Command-X can be used alternatively to Meta-C and Meta-X. I'm still
> looking for an easy solution for my pet peeve: I just want to press Command-C without thinking how
> I made the selection (with the mouse in Ghostty or with the keyboard in the REPL). Currently, I
> use Karabiner Elements to rebind Command-C to Control-Command-C for Ghostty. Ghostty's config must
> contain `keybind = performable:ctrl+cmd+c=copy_to_clipboard`. GhosttyExtensions 0.8.0 takes care of
> the rest. This works reliably and is not laggy (it's possible to do this with macOS Shortcuts but
> it's too sluggish to be useful). If you are reading this and your muscle memory can't deal with
> two different key combinations for the same, simple task ("Just copy this selection!"), please open 
> an issue and I'll share the details.

## Features

Shell integration:

- OSC 2 terminal title.
  Shows the active project and the remote hostname when connected via ssh.

- OSC 52 pasteboard support with `pbcopy(x)` and `pbpaste()`.
  Copy'n'paste that works over ssh.

- OSC 133 prompt marking for the prompt modes `julia>`, `shell>`, and `help?>`.
  Jump back and forth through the prompts or copy the output between two prompts.

Inline plotting:

- Kitty graphics protocol for use with Plots.jl. Plots are shown as PNGs in their original
  sizes. There is no scaling. Adjust the plot size within Plots.jl (see below). This
  approach makes plots less blurred and there's no need for any dependencies. Use
  KittyTerminalImages.jl if you need more features.

- Inline plotting is automatically activated in interactive sessions and works over ssh.

- Switch back to the default (e.g., GKSQT.app on macOS) with `inlineplotting(false)`.
  Plotting to a GUI app works only on the local machine.

- In non-interactive scripts, call `inlineplotting()` once to initialize.
  Remember to wrap the plot commands with `display(...)`.

- Get the size of the terminal window in pixels with `pixelsize()`. Invoke `?pixelsize`
  for examples about adjusting the plot size or setting default sizes.

Extra key bindings:

- **F2:** wrap the buffer in parentheses and move the cursor to the start

- **F12:** toggle the prefix `@time`

- **Shift-F12:** toggle the prefix `@code_warntype`

- **Meta-C or Control-Command-C:** copy the selection or buffer to the system pasteboard (via OSC 52)

- **Meta-X or Control-Command-X:** cut the selection or buffer to the system pasteboard (via OSC 52)

- **Meta-V:** paste from the system pasteboard and execute (via OSC 52)

- **Shift-Option-Left, Shift-Option-Right:** select by word

- **Shift-Command-Left, Shift-Command-Right:** select to the start/end of the line

- **Shift-Option-Up, Shift-Option-Down:** select to the start/end of the buffer

Sorry for the Mac specific key bindings. You can change the `extra_keymap` in
`src/GhosttyExtensions.jl`.

Meta-C and Meta-X can be made much more convenient by binding them to Command-C/Command-X in
Ghostty's `~/.config/ghostty/config`. Currently, we need a separate keybind to copy GUI
selections made with the mouse as we overwrite the default binding:

```
keybind = opt+cmd+c=copy_to_clipboard
keybind = cmd+c=esc:C
keybind = cmd+x=esc:X
```

Meta-V is intended for automation. For instance, you may want to use AppleScript,
[Hammerspoon](https://hammerspoon.org), [Karabiner](https://karabiner-elements.pqrs.org), 
or some other app to copy code from your GUI editor and paste & execute it in Ghostty. 
You'll be asked for permission to access the system clipboard or you can opt in permanently 
in `~/.config/ghostty/config`:

```
clipboard-read = allow
```

## Unexported functions

Explore key strokes (inspired by [fish_keyreader](https://fishshell.com/docs/current/cmds/fish_key_reader.html), 
useful for making own keybinds):

```julia
GhosttyExtensions.keyreader()
```

Return the size of a terminal cell in pixels. A cell is the space that's occupied by one
character (useful for debugging):

```julia
GhosttyExtensions.cellsize()
```

## Installation

This package is not available in Julia's general registry. It can be added or dev'ed with:

```julia
Pkg> develop https://github.com/piechologist/GhosttyExtensions.jl
```

Add the following lines to your `~/.julia/config/startup.jl`:

```julia
using TerminalPager # optional, recommended
using GhosttyExtensions
```

Note that loading GhosttyExtensions manually after the REPL has been initialized won't work. 
Also, TerminalPager must be loaded before GhosttyExtensions! The REPL in general is pretty 
hacky and both packages use different kinds of hacks for their key bindings.

## Credits

- [Ghostty](https://github.com/ghostty-org/ghostty)

- [TerminalExtensions.jl](https://github.com/Keno/TerminalExtensions.jl)

- [TerminalPager.jl](https://github.com/ronisbr/TerminalPager.jl)

- [KittyTerminalImages.jl](https://github.com/simonschoelly/KittyTerminalImages.jl)

- [Kitty terminal graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)

- The Julia 1.10 REPL, see `edit(Sys.STDLIB * "/REPL/src/LineEdit.jl")`
