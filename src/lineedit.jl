# ------------------------------------------------------------------------------------------
# Functions supplementing Julia's REPL.LineEdit.jl
# ------------------------------------------------------------------------------------------

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

"""Paste the system pasteboard as bracketed paste and execute it."""
function run_pasteboard(s)
    LineEdit.edit_clear(s)
    write(stdin.buffer, "\e[200~", strip(pbpaste()), "\e[201~\n")
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
