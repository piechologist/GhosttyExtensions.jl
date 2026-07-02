# ------------------------------------------------------------------------------------------
# Functions supplementing Julia's REPL.LineEdit.jl
# ------------------------------------------------------------------------------------------

"""Copied over from LineEdit.jl. Patched to match words containing @ or . (dot)."""
is_non_word_char(c::Char) = c in """ \t\n\"\\'`\$><=:;|&{}()[],+-*/?%^~"""

"""Copied over from LineEdit.jl. Patched to use the modified is_non_word_char()."""
function current_word_with_dots(buf)
    pos = position(buf)
    if eof(buf) || is_non_word_char(peek(buf, Char))
        LineEdit.char_move_word_left(buf, is_non_word_char)
    end
    LineEdit.char_move_word_right(buf, is_non_word_char)
    pend = position(buf)
    LineEdit.char_move_word_left(buf, is_non_word_char)
    pbegin = position(buf)
    word = pend > pbegin ? String(buf.data[(pbegin + 1):pend]) : ""
    seek(buf, pos)
    return length(word) == 1 ? word : lstrip(word, '!') # strip negation prefix
end

"""Render the native `?` help for `word` to a string with ANSI color."""
function help_text(word)
    buf = IOBuffer()
    io = IOContext(buf, :color => true, :displaysize => displaysize(stdout))
    try
        doc = Core.eval(Main, REPL.helpmode(io, word))
        show(io, MIME("text/plain"), doc)
    catch err
        showerror(io, err) # page the error rather than crashing the keymap
    end
    return String(take!(buf))
end

"""Look up the native `?` help for the selection or the word under the cursor and page it."""
function invoke_help(s)
    mode_name = LineEdit.guess_current_mode_name(s)
    if mode_name ≡ :julia
        if LineEdit.is_region_active(s)
            word = LineEdit.content(s, LineEdit.region(s))
        else
            word = current_word_with_dots(LineEdit.buffer(s))
        end
        if !isempty(word)
            page(help_text(word))
            LineEdit.refresh_line(s)
        end
    elseif mode_name ≡ :help
        LineEdit.move_input_start(s)
        write(stdin.buffer, "\b")
        startswith(LineEdit.content(s), "?") && LineEdit.edit_delete(s)
        LineEdit.refresh_line(s)
    end
    return nothing
end

"""Copy the selection or the whole buffer to the system pasteboard."""
function copy_region(s)
    if LineEdit.is_region_active(s)
        pbcopy(LineEdit.content(s, LineEdit.region(s)))
        LineEdit.edit_copy_region(s)
    else
        pbcopy(LineEdit.content(s))
    end
    return nothing
end

"""Cut the selection or the whole buffer to the system pasteboard."""
function cut_region(s)
    if LineEdit.is_region_active(s)
        pbcopy(LineEdit.content(s, LineEdit.region(s)))
        LineEdit.edit_kill_region(s)
    else
        pbcopy(LineEdit.content(s))
        LineEdit.edit_clear(s)
    end
    return nothing
end

"""Wrap the whole buffer in parentheses and move the cursor to the start."""
function parenthesize(s)
    LineEdit.move_input_end(s)
    LineEdit.edit_insert(s, ')')
    LineEdit.move_input_start(s)
    LineEdit.edit_insert(s, '(')
    LineEdit.move_input_start(s)
    LineEdit.refresh_line(s)
    return nothing
end

"""Paste the system pasteboard using bracketed paste and execute it."""
function run_pasteboard(s)
    LineEdit.edit_clear(s)
    write(stdin.buffer, "\e[200~", strip(pbpaste()), "\e[201~\n")
    return nothing
end

"""Begin or extend a selection to the start of the previous word."""
function select_previous_word(s)
    LineEdit.edit_shift_move(s, LineEdit.edit_move_word_left)
    return nothing
end

"""Begin or extend a selection to the end of the next word."""
function select_next_word(s)
    LineEdit.edit_shift_move(s, LineEdit.edit_move_word_right)
    return nothing
end

"""Begin or extend a selection to the start of the buffer."""
function select_to_start_of_buffer(s)
    while position(s) > 0
        LineEdit.edit_shift_move(s, LineEdit.edit_move_word_left)
    end
    return nothing
end

"""Begin or extend a selection to the end of the buffer."""
function select_to_end_of_buffer(s)
    while !eof(LineEdit.buffer(s))
        LineEdit.edit_shift_move(s, LineEdit.edit_move_word_right)
    end
    return nothing
end

"""Begin or extend a selection to the start of the line."""
function select_to_start_of_line(s)
    while position(s) > 0
        LineEdit.edit_shift_move(s, LineEdit.edit_move_left)
        position(s) == 0 && break
        LineEdit.buffer(s).data[position(s)] == 0x0a && break
    end
    return nothing
end

"""Begin or extend a selection to the end of the line."""
function select_to_end_of_line(s)
    while !eof(LineEdit.buffer(s))
        LineEdit.edit_shift_move(s, LineEdit.edit_move_right)
        LineEdit.buffer(s).data[position(s)] == 0x0a && break
    end
    return nothing
end

"""Prefix the buffer with `prefix ` or remove it if it's already there."""
function toggle_prefix(s, prefix)
    LineEdit.move_input_start(s)
    if startswith(LineEdit.content(s), prefix * " ")
        LineEdit.edit_delete_next_word(s)
        LineEdit.edit_delete(s)
    else
        LineEdit.edit_insert(s, prefix * " ")
        LineEdit.edit_move_left(s)
    end
    LineEdit.refresh_line(s)
    return nothing
end

"""Append `suffix` to the buffer or remove it if it's already there."""
function toggle_suffix(s, suffix)
    LineEdit.move_input_end(s)
    if endswith(LineEdit.content(s), suffix)
        for _ in 1:length(suffix)
            LineEdit.edit_backspace(s)
        end
    else
        LineEdit.edit_insert(s, suffix)
    end
    LineEdit.refresh_line(s)
    return nothing
end
