# ------------------------------------------------------------------------------------------
# A new AbstractDisplay and functions for inline plotting with Plots.jl
# ------------------------------------------------------------------------------------------

struct KittyDisplay <: AbstractDisplay end

"""
    inlineplotting() -> Nothing
    inlineplotting(false) -> Nothing

Switch to inline plotting in the terminal or back to the default behavior.
"""
function inlineplotting(inline=true)
    while KittyDisplay() ∈ Base.Multimedia.displays
        Base.Multimedia.popdisplay(KittyDisplay())
    end
    if inline
        Base.Multimedia.pushdisplay(KittyDisplay())
        ENV["GKSwstype"] = "nul" # suppress launching of the GKSQT app (GR backend)
    else
        delete!(ENV, "GKSwstype")
    end
    return nothing
end

function display(d::KittyDisplay, x)
    if showable(MIME"image/png"(), x)
        if isa(x, Vector{UInt8})
            display(d, MIME"image/png"(), x)
            return nothing
        elseif isa(x, Main.Plots.Plot)
            io = IOBuffer()
            Main.Plots.png(x, io)
            display(d, MIME"image/png"(), take!(io))
            return nothing
        end
    end
    throw(MethodError(display, (x,)))
end

function display(d::KittyDisplay, m::MIME"image/png", png::Vector{UInt8})
    # https://sw.kovidgoyal.net/kitty/graphics-protocol/#control-data-reference
    # We place the plot a few pixels below the preceding prompt line with `Y=5`.
    # At the end, we print a newline to avoid the next prompt overlapping the plot.
    partitions = Iterators.partition(base64encode(png), 4096)
    io = IOBuffer()
    for (i, payload) in enumerate(partitions)
        c = i == 1 ? "f=100,a=T,q=1,Y=5," : ""
        m = i < length(partitions) ? "m=1;" : "m=0;"
        write(io, "\e_G", c, m, payload, "\e\\")
    end
    write(stdout, take!(io), '\n')
    return nothing
end

"""
    pixelsize() -> Tuple(width::Int, height::Int)
    pixelsize(relative_height)
    pixelsize(relative_height, relative_width)
    pixelsize(relative_height; ratio=width_to_height_ratio)

Return the size of the terminal window in pixels. With arguments, return a tuple that can be
passed to a plot command to set the size of the figure.

# Examples

Make plots that are a bit smaller than half of the terminal height to fit two plots in the
window. Make them twice as wide as they are tall. Add scaling to make the font bigger on
high resolution screens like Macs with Retina displays.
```
using Plots
default(; size=pixelsize(0.45; ratio=2), thickness_scaling=1.5)
plot(plot(rand(33)), heatmap(rand(33,33)), layout=(1,2), xlab="(X)", ylab="(Y)")
```

Make a plot that is a third of the terminal height and as wide as possible.
```
plot(rand(10); size=pixelsize(1/3))
```

The terminal's cell size can be calculated with:
```
height, width = pixelsize()
rows, columns = displaysize(stdout)
cell_height = height ÷ rows
cell_width = width ÷ columns
```
"""
function pixelsize()
    term = REPL.Terminals.TTYTerminal("xterm", stdin, stdout, stderr)
    REPL.Terminals.raw!(term, true)
    Base.start_reading(stdin)
    print(stdout, "\e[14t")
    data = readuntil(stdin, "t")
    startswith(data, "\e[4;") || return (0, 0)
    height, width = split(chopprefix(data, "\e[4;"), ';')
    return parse(Int, width), parse(Int, height)
end

function pixelsize(relative_height, relative_width=1; ratio=0)
    width, height = pixelsize()
    rows, columns = displaysize(stdout)
    cell_height = height ÷ rows
    h = floor(relative_height * rows) * cell_height # always fill whole rows
    w = iszero(ratio) ? relative_width * width : ratio * h
    return w, h
end
