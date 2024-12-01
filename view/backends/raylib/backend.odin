package backend



InputText :: struct {
    bounds: rl.Rectangle, 
    buf: []u8, 
    len: int,
    cursorIndex: int,
    editMode: bool,
    autoCursorCooldownCounter: int,
    autoCursorDelayCounter: int,
    alpha: f32,
}









// Expose raygui constants for custom widgets

DEFAULT :: rl.GuiControl.DEFAULT
TEXT_WRAP_MODE :: i32(rl.GuiDefaultProperty.TEXT_WRAP_MODE)
TEXTBOX :: rl.GuiControl.TEXTBOX
TEXT_SPACING :: i32(rl.GuiDefaultProperty.TEXT_SPACING)
TEXT_SIZE :: i32(rl.GuiDefaultProperty.TEXT_SIZE)
BORDER_WIDTH :: i32(rl.GuiControlProperty.BORDER_WIDTH)
BASE_COLOR_PRESSED :: i32(rl.GuiControlProperty.BASE_COLOR_PRESSED)
BASE_COLOR_DISABLED :: i32(rl.GuiControlProperty.BASE_COLOR_DISABLED)
BORDER_COLOR_PRESSED :: i32(rl.GuiControlProperty.BORDER_COLOR_PRESSED)
TEXT_READONLY :: i32(rl.GuiTextBoxProperty.TEXT_READONLY)
TEXT_ALIGNMENT :: i32(rl.GuiControlProperty.TEXT_ALIGNMENT)
BORDER :: 0
BASE :: 1
TEXT :: 2




// Text Box control
// NOTE: Returns true on ENTER pressed (useful for data validation)
GuiInputText :: proc(widget: ^InputText) -> (result: bool)
{
    RAYGUI_TEXTBOX_AUTO_CURSOR_COOLDOWN :: 20        // Frames to wait for autocursor movement
    RAYGUI_TEXTBOX_AUTO_CURSOR_DELAY    :: 1        // Frames delay for autocursor movement 

    state := cast(rl.GuiState)rl.GuiGetState()

    multiline := false     // TODO: Consider multiline text input
    wrapMode := rl.GuiGetStyle(DEFAULT, TEXT_WRAP_MODE)

    bounds := widget.bounds
    textBounds := widget.bounds
    textSize := len(widget.buf)
    thisCursorIndex := widget.cursorIndex
    if thisCursorIndex > widget.len {
        thisCursorIndex = widget.len
    }
    textWidth := rl.MeasureText(to_cstring(widget.buf), i32(view_state_.font_size)) - rl.MeasureText(transmute(cstring)&widget.buf[widget.cursorIndex], i32(view_state_.font_size))
    textIndexOffset := 0    // Text index offset to start drawing in the box

    // Cursor rectangle
    // NOTE: Position X value should be updated
    cursor := rl.Rectangle {
        textBounds.x + f32(textWidth) + f32(rl.GuiGetStyle(DEFAULT, TEXT_SPACING)),
        textBounds.y + f32(textBounds.height)/2.0 - f32(rl.GuiGetStyle(DEFAULT, TEXT_SIZE)),
        2.0,
        f32(rl.GuiGetStyle(DEFAULT, TEXT_SIZE))*2.0,
    }

    if cursor.height >= bounds.height {
        cursor.height = bounds.height - f32(rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH)) * 2.0
    }

    if cursor.y < (bounds.y + f32(rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH))) {
        cursor.y = bounds.y + f32(rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH))
    }

    // Mouse cursor rectangle
    // NOTE: Initialized outside of screen
    mouseCursor := cursor
    mouseCursor.x = -1
    mouseCursor.width = 1

    // Auto-cursor movement logic
    // NOTE: Cursor moves automatically when key down after some time
    if (rl.IsKeyDown(rl.KeyboardKey.LEFT) || rl.IsKeyDown(rl.KeyboardKey.RIGHT) || rl.IsKeyDown(rl.KeyboardKey.UP) || rl.IsKeyDown(rl.KeyboardKey.DOWN) || rl.IsKeyDown(rl.KeyboardKey.BACKSPACE) || rl.IsKeyDown(rl.KeyboardKey.DELETE)) {
        widget.autoCursorCooldownCounter += 1
    }
    else {
        widget.autoCursorCooldownCounter = 0      // GLOBAL: Cursor cooldown counter
        widget.autoCursorDelayCounter = 0         // GLOBAL: Cursor delay counter
    }

    // Blink-cursor frame counter
    //if (!autoCursorMode) blinkCursorFrameCounter++;
    //else blinkCursorFrameCounter = 0;

    // Update control
    //--------------------------------------------------------------------
    // WARNING: Text editing is only supported under certain conditions:
    if ((state != rl.GuiState.STATE_DISABLED) &&                // Control not disabled
        rl.GuiGetStyle(TEXTBOX, i32(rl.GuiTextBoxProperty.TEXT_READONLY)) == 0 &&  // TextBox not on read-only mode
        !rl.GuiIsLocked() &&                               // Gui not locked
        //!guiControlExclusiveMode &&                       // No gui slider on dragging
        (wrapMode == i32(rl.GuiTextWrapMode.TEXT_WRAP_NONE)))               // No wrap mode
    {
        mousePosition := rl.GetMousePosition()

        if (widget.editMode) {
            state = rl.GuiState.STATE_PRESSED

            if widget.cursorIndex > widget.len {
                widget.cursorIndex = widget.len
            }

            // If text does not fit in the textbox and current cursor position is out of bounds,
            // we add an index offset to text for drawing only what requires depending on cursor
            for textWidth >= i32(textBounds.width) {
                nextCodepointSize :i32 = 0
                rl.GetCodepointNext(transmute(cstring)&widget.buf[textIndexOffset], &nextCodepointSize)

                textIndexOffset += int(nextCodepointSize)

                textWidth = rl.MeasureText(transmute(cstring)&widget.buf[textIndexOffset], i32(view_state_.font_size)) - 
                            rl.MeasureText(transmute(cstring)&widget.buf[widget.cursorIndex], i32(view_state_.font_size))
            }

            codepoint := rl.GetCharPressed()       // Get Unicode codepoint
            if multiline && rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
                codepoint = '\n'
            }

            // Encode codepoint as UTF-8
            codepointSize :i32 = 0
            charEncoded := rl.CodepointToUTF8(codepoint, &codepointSize)

            // Add codepoint to text, at current cursor position
            // NOTE: Make sure we do not overflow buffer size
            endOfText := (widget.len + int(codepointSize))
            if (((multiline && (codepoint == '\n')) || (codepoint >= 32)) && (endOfText < textSize)) {
                // Move forward data from cursor position
                for i := endOfText; i > widget.cursorIndex; i -= 1 {
                    widget.buf[i] = widget.buf[i - int(codepointSize)]
                }

                // Add new codepoint in current cursor position
                for i := 0; i < int(codepointSize); i += 1 {
                    widget.buf[widget.cursorIndex + i] = (transmute([^]u8)charEncoded)[i]
                }

                widget.cursorIndex += int(codepointSize)
                widget.len += int(codepointSize)

                // Make sure text last character is EOL
                widget.buf[widget.len] = 0
            }

            // Move cursor to start
            if ((widget.len > 0) && rl.IsKeyPressed(rl.KeyboardKey.HOME)) {
                widget.cursorIndex = 0
            }

            // Move cursor to end
            if ((widget.len > widget.cursorIndex) && rl.IsKeyPressed(rl.KeyboardKey.END)) {
                widget.cursorIndex = widget.len
            }

            // Delete codepoint from text, after current cursor position
            if ((widget.len > widget.cursorIndex) && (rl.IsKeyPressed(rl.KeyboardKey.DELETE) || (rl.IsKeyDown(rl.KeyboardKey.DELETE) && (widget.autoCursorCooldownCounter >= RAYGUI_TEXTBOX_AUTO_CURSOR_COOLDOWN)))) {
                widget.autoCursorDelayCounter += 1

                if (rl.IsKeyPressed(rl.KeyboardKey.DELETE) || (widget.autoCursorDelayCounter % RAYGUI_TEXTBOX_AUTO_CURSOR_DELAY) == 0) {      // Delay every movement some frames
                    nextCodepointSize :i32 = 0
                    rl.GetCodepointNext(transmute(cstring)&widget.buf[widget.cursorIndex], &nextCodepointSize)

                    // Move backward text from cursor position
                    for i := widget.cursorIndex; i < widget.len; i += 1 {
                        widget.buf[i] = widget.buf[i + int(nextCodepointSize)]
                    }

                    widget.len -= int(codepointSize)
                    if widget.cursorIndex > widget.len {
                        widget.cursorIndex = widget.len
                    }

                    // Make sure text last character is EOL
                    widget.buf[widget.len] = 0
                }
            }

            // Delete related codepoints from text, before current cursor position
            if ((widget.len > 0) && rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) && (rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) || rl.IsKeyDown(rl.KeyboardKey.RIGHT_CONTROL))) {
                i := widget.cursorIndex - 1
                accCodepointSize :i32 = 0

                // Move cursor to the end of word if on space already
                for (i > 0) && bytes.is_space(rune(widget.buf[i])) {
                    prevCodepointSize :i32 = 0
                    rl.GetCodepointPrevious(transmute(cstring)&widget.buf[i], &prevCodepointSize)
                    i -= int(prevCodepointSize)
                    accCodepointSize += prevCodepointSize
                }

                // Move cursor to the start of the word
                for (i > 0) && !bytes.is_space(rune(widget.buf[i])) {
                    prevCodepointSize :i32 = 0
                    rl.GetCodepointPrevious(transmute(cstring)&widget.buf[i], &prevCodepointSize)
                    i -= int(prevCodepointSize)
                    accCodepointSize += prevCodepointSize
                }

                // Move forward text from cursor position
                for j := (widget.cursorIndex - int(accCodepointSize)); j < widget.len; j += 1 {
                    widget.buf[j] = widget.buf[j + int(accCodepointSize)]
                }

                // Prevent cursor index from decrementing past 0
                if widget.cursorIndex > 0 {
                    widget.cursorIndex -= int(accCodepointSize)
                    widget.len -= int(accCodepointSize)
                }

                // Make sure text last character is EOL
                widget.buf[widget.len] = 0
            } 
            else if ((widget.len > 0) && (rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) || (rl.IsKeyDown(rl.KeyboardKey.BACKSPACE) && (widget.autoCursorCooldownCounter >= RAYGUI_TEXTBOX_AUTO_CURSOR_COOLDOWN)))) {
                widget.autoCursorDelayCounter += 1

                if (rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) || (widget.autoCursorDelayCounter % RAYGUI_TEXTBOX_AUTO_CURSOR_DELAY) == 0)      // Delay every movement some frames
                {
                    prevCodepointSize :i32 = 0

                    // Prevent cursor index from decrementing past 0
                    if widget.cursorIndex > 0 {
                        rl.GetCodepointPrevious(transmute(cstring)&widget.buf[widget.cursorIndex], &prevCodepointSize)

                        // Move backward text from cursor position
                        for i := (widget.cursorIndex - int(prevCodepointSize)); i < widget.len; i += 1 {
                            widget.buf[i] = widget.buf[i + int(prevCodepointSize)]
                        }

                        widget.cursorIndex -= int(codepointSize)
                        widget.len -= int(codepointSize)
                    }

                    // Make sure text last character is EOL
                    widget.buf[widget.len] = 0
                }
            }

            // Move cursor position with keys
            if (rl.IsKeyPressed(rl.KeyboardKey.LEFT) || (rl.IsKeyDown(rl.KeyboardKey.LEFT) && (widget.autoCursorCooldownCounter > RAYGUI_TEXTBOX_AUTO_CURSOR_COOLDOWN))) {
                widget.autoCursorDelayCounter += 1

                if (rl.IsKeyPressed(rl.KeyboardKey.LEFT) || (widget.autoCursorDelayCounter % RAYGUI_TEXTBOX_AUTO_CURSOR_DELAY) == 0)      // Delay every movement some frames
                {
                    prevCodepointSize :i32 = 0
                    if widget.cursorIndex > 0 {
                        rl.GetCodepointPrevious(transmute(cstring)&widget.buf[widget.cursorIndex], &prevCodepointSize)
                    }

                    if widget.cursorIndex >= int(prevCodepointSize) {
                        widget.cursorIndex -= int(prevCodepointSize)
                    }
                }
            }
            else if (rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || (rl.IsKeyDown(rl.KeyboardKey.RIGHT) && (widget.autoCursorCooldownCounter > RAYGUI_TEXTBOX_AUTO_CURSOR_COOLDOWN)))
            {
                widget.autoCursorDelayCounter += 1

                if (rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || (widget.autoCursorDelayCounter % RAYGUI_TEXTBOX_AUTO_CURSOR_DELAY) == 0)      // Delay every movement some frames
                {
                    nextCodepointSize :i32 = 0
                    rl.GetCodepointNext(transmute(cstring)&widget.buf[widget.cursorIndex], &nextCodepointSize);

                    if (widget.cursorIndex + int(nextCodepointSize)) <= widget.len {
                        widget.cursorIndex += int(nextCodepointSize)
                    }
                }
            }

            // Move cursor position with mouse
            if (rl.CheckCollisionPointRec(mousePosition, textBounds))     // Mouse hover text
            {
                guiFont := rl.GuiGetFont()
                scaleFactor := f32(rl.GuiGetStyle(DEFAULT, TEXT_SIZE))/f32(guiFont.baseSize)
                codepointIndex :i32 = 0
                glyphWidth :f32 = 0.0
                widthToMouseX :f32 = 0.0
                mouseCursorIndex := 0

                for i := textIndexOffset; i < widget.len; i += 1 {
                    codepoint = rl.GetCodepointNext(transmute(cstring)&widget.buf[i], &codepointSize)
                    codepointIndex = rl.GetGlyphIndex(guiFont, codepoint)

                    if (guiFont.glyphs[codepointIndex].advanceX == 0) {
                        glyphWidth = (f32(guiFont.recs[codepointIndex].width)*scaleFactor)
                    }
                    else {
                        glyphWidth = (f32(guiFont.glyphs[codepointIndex].advanceX)*scaleFactor)
                    }

                    if mousePosition.x <= (textBounds.x + (widthToMouseX + glyphWidth/2.0)) {
                        mouseCursor.x = f32(textBounds.x) + widthToMouseX;
                        mouseCursorIndex = i;
                        break;
                    }

                    widthToMouseX += (glyphWidth + f32(rl.GuiGetStyle(DEFAULT, TEXT_SPACING)))
                }

                // Check if mouse cursor is at the last position
                textEndWidth := rl.MeasureText(transmute(cstring)&widget.buf[textIndexOffset], i32(view_state_.font_size))
                if rl.GetMousePosition().x >= (textBounds.x + f32(textEndWidth) - glyphWidth/2.0) {
                    mouseCursor.x = textBounds.x + f32(textEndWidth)
                    mouseCursorIndex = widget.len
                }

                // Place cursor at required index on mouse click
                if (mouseCursor.x >= 0) && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
                    cursor.x = mouseCursor.x
                    widget.cursorIndex = mouseCursorIndex
                }
            }
            else {
                mouseCursor.x = -1
            }

            // Recalculate cursor position.y depending on widget.cursorIndex
            cursor.x = bounds.x + f32(rl.GuiGetStyle(TEXTBOX, i32(rl.GuiControlProperty.TEXT_PADDING))) + f32(rl.MeasureText(transmute(cstring)&widget.buf[textIndexOffset], i32(view_state_.font_size))) - f32(rl.MeasureText(transmute(cstring)&widget.buf[widget.cursorIndex], i32(view_state_.font_size))) + f32(rl.GuiGetStyle(DEFAULT, TEXT_SPACING))
            //if (multiline) cursor.y = GetTextLines()

            // Finish text editing on ENTER or mouse click outside bounds
            if !multiline && rl.IsKeyPressed(rl.KeyboardKey.ENTER)
            {
                widget.cursorIndex = 0     // GLOBAL: Reset the shared cursor index
                result = true
            }
        }
        else {
            if rl.CheckCollisionPointRec(mousePosition, bounds) {
                state = rl.GuiState.STATE_FOCUSED

                if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
                    widget.cursorIndex = widget.len   // GLOBAL: Place cursor index to the end of current text
                    result = true
                }
            }
        }
    }
    //--------------------------------------------------------------------

    // Draw control
    //--------------------------------------------------------------------
    if (state == rl.GuiState.STATE_PRESSED) { 
        GuiDrawRectangle(bounds, rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BORDER + (i32(state)*3)))), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BASE_COLOR_PRESSED))), widget.alpha)
    }
    else if (state == rl.GuiState.STATE_DISABLED) {
        GuiDrawRectangle(bounds, rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BORDER + (i32(state)*3)))), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BASE_COLOR_DISABLED))), widget.alpha)
    }
    else {
        GuiDrawRectangle(bounds, rl.GuiGetStyle(TEXTBOX, BORDER_WIDTH), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BORDER + (i32(state)*3)))), rl.BLANK, widget.alpha)
    }

    // Draw text considering index offset if required
    // NOTE: Text index offset depends on cursor position
    rl.DrawTextEx(view_state_.font, transmute(cstring)&widget.buf[textIndexOffset], {textBounds.x, textBounds.y + (textBounds.height - view_state_.font_size) / 2.0}, view_state_.font_size, view_state_.font_spacing, rl.BLACK)
    //rl.GuiDrawText(transmute(cstring)&widget.buf[textIndexOffset], textBounds, rl.GuiGetStyle(TEXTBOX, TEXT_ALIGNMENT), rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, TEXT + (i32(state)*3)))));
    // Draw cursor
    if (widget.editMode && rl.GuiGetStyle(TEXTBOX, TEXT_READONLY) == 0)
    {
        //if (autoCursorMode || ((blinkCursorFrameCounter/40)%2 == 0))
        GuiDrawRectangle(cursor, 0, rl.BLANK, rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BORDER_COLOR_PRESSED))), widget.alpha)

        // Draw mouse position cursor (if required)
        if mouseCursor.x >= 0 {
            GuiDrawRectangle(mouseCursor, 0, rl.BLANK, rl.GetColor(u32(rl.GuiGetStyle(TEXTBOX, BORDER_COLOR_PRESSED))), widget.alpha)
        }
    }
    //--------------------------------------------------------------------

    return      // Mouse button pressed: result = 1
}

// Gui draw rectangle using default raygui plain style with borders
GuiDrawRectangle :: proc(rec: rl.Rectangle, borderWidth: i32, borderColor: rl.Color, color: rl.Color, alpha: f32)
{
    if (color.a > 0)
    {
        // Draw rectangle filled with color
        rl.DrawRectangle(i32(rec.x), i32(rec.y), i32(rec.width), i32(rec.height), GuiFade(color, alpha));
    }

    if (borderWidth > 0)
    {
        // Draw rectangle border lines with color
        rl.DrawRectangle(i32(rec.x), i32(rec.y), i32(rec.width), borderWidth, GuiFade(borderColor, alpha));
        rl.DrawRectangle(i32(rec.x), i32(rec.y) + borderWidth, borderWidth, i32(rec.height) - 2*borderWidth, GuiFade(borderColor, alpha));
        rl.DrawRectangle(i32(rec.x) + i32(rec.width) - borderWidth, i32(rec.y) + borderWidth, borderWidth, i32(rec.height) - 2*borderWidth, GuiFade(borderColor, alpha));
        rl.DrawRectangle(i32(rec.x), i32(rec.y) + i32(rec.height) - borderWidth, i32(rec.width), borderWidth, GuiFade(borderColor, alpha));
    }
}


// Color fade-in or fade-out, alpha goes from 0.0f to 1.0f
// WARNING: It multiplies current alpha by alpha scale factor
GuiFade :: proc(color: rl.Color, alpha: f32) -> rl.Color
{
    alpha := alpha
    if alpha < 0.0 { 
        alpha = 0.0
    }
    else if alpha > 1.0 {
        alpha = 1.0
    }

    return {
        color.r,
        color.g,
        color.b,
        u8(f32(color.a) * alpha)
    }
}
