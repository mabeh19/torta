package view

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "base:runtime"
import "core:c"
import "core:strconv"
import "core:log"
import "core:bytes"
import "core:sync"

import ue "../user_events"
import pe "../process_events"
import s "../state"
import conf "../configuration"

import rb "../ringbuffer"
import ev "../event"

import mu "vendor:microui"
import backend "backends/microui"


EXPORT_NAMESPACE :: "view_"


SCREEN_WIDTH    :: 640
SCREEN_HEIGHT   :: 480


ViewState :: struct {
    font: mu.Font,
    font_size: f32,
    font_spacing: f32,
    font_line_spacing: f32,
    in_settings: bool,
    auto_scroll: bool,

    data: struct {
        lines: u32,
    },
}

view_state_ := ViewState{}

@(export, link_prefix=EXPORT_NAMESPACE)
init :: proc ()
{
    backend.init(SCREEN_WIDTH, SCREEN_HEIGHT)
    init_settings()
}

labelf :: proc(ctx: ^mu.Context, f: string, args: ..any)
{
    s := fmt.aprintf(f, args)
    defer delete(s)
    mu.label(ctx, s)
}

@(export, link_prefix=EXPORT_NAMESPACE)
draw :: proc (ctx: ^mu.Context)
{
    // Drawing logic
    opts := mu.Options {
        //.NO_FRAME,
        .NO_RESIZE,
        .NO_SCROLL,
        .NO_CLOSE,
        .NO_TITLE,
    }
    state := s.get_state()
    width := backend.window_width()
    height := backend.window_height()
    if mu.begin_window(ctx, "MUTERM", {0, 0, width, height}, opts) {
        defer mu.end_window(ctx)
        win := mu.get_current_container(ctx)
        win.rect = {0, 0, width, height}

        if view_state_.in_settings {
            draw_settings(ctx)
        }
        else {
            mu.layout_row(ctx, {-80, -1}, -1)
            // Column 1
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)
                draw_data_view(ctx)

                if state.bufferedMode {
                    draw_input_field(ctx)
                }
            }

            // Column 2
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)

                if mu.button(ctx, "Settings") == {.SUBMIT} {
                    view_state_.in_settings = true
                    tmp_settings_ = settings_
                }
                draw_port_toggle(ctx)

                // Clear
                if mu.button(ctx, "Clear") == {.SUBMIT} {
                    ev.signal(&ue.clearEvent)
                    view_state_.data.lines = 0
                }

                // Autoscroll
                mu.checkbox(ctx, "Autoscroll", &view_state_.auto_scroll)

                // Text settings
                mu.checkbox(ctx, "Append nl", &state.appendNewLine)
                mu.checkbox(ctx, "Append cr", &state.appendCarriageReturn)
                mu.checkbox(ctx, "Append 0", &state.appendNullByte)
                mu.checkbox(ctx, "Buffered", &state.bufferedMode)

                // File I/O
                draw_file_io(ctx)
            }
        }
    }
}

@(export, link_prefix=EXPORT_NAMESPACE)
close :: proc ()
{
    backend.close_window()
}


@(export, link_prefix=EXPORT_NAMESPACE)
should_close :: proc () -> bool
{
    return backend.window_should_close()
}


@(private)
draw_port_toggle :: proc(ctx: ^mu.Context)
{
    BUTTON_TEXTS := [2]string { "Open Port", "Close Port"}
    isOpen := s.port_is_open()

    if mu.button(ctx, BUTTON_TEXTS[int(isOpen)]) == {.SUBMIT} {
        ev.signal(&ue.openEvent, !isOpen)
    }
}


@(private)
to_cstring :: proc(buf: []u8) -> cstring 
{
    return cstring(raw_data(buf))
}


@(private)
draw_data_view :: proc(ctx: ^mu.Context)
{
    @static displayBuffer : [dynamic]u8
    @static prevRead := 0

    state := s.get_state()

    if prevRead != state.bytesRead {
        sync.lock(&state.dataBufferLock)
        defer sync.unlock(&state.dataBufferLock)

        resize(&displayBuffer, s.data_buffer_size())

        first, second := rb.parts(state.dataBuffer)

        copy(displayBuffer[:len(first)], first[:])

        if len(second) > 0 {
            copy(displayBuffer[len(first):], second[:])
        }
    }

    mu.layout_row(ctx, {-1}, -40)
    mu.begin_panel(ctx, "Data window")
    panel := mu.get_current_container(ctx)
    mu.layout_row(ctx, {-1}, -1)
    mu.text(ctx, transmute(string)displayBuffer[:])
    mu.end_panel(ctx)
    
    if view_state_.auto_scroll {
        panel.scroll.y = panel.content_size.y
    }
}


@(private)
draw_input_field :: proc(ctx: ^mu.Context)
{
    @static input := [4096]u8{}
    @static strlen := 0

    submit := false
    mu.layout_row(ctx, {-60, -1}, -1)
    for e in mu.textbox(ctx, input[:], &strlen) {
        if e == .SUBMIT {
            mu.set_focus(ctx, ctx.last_id)
            submit = true
        }
        else if e == .CHANGE && !s.get_state().bufferedMode {
            mu.set_focus(ctx, ctx.last_id)
            submit = true
        }
    }

    if mu.button(ctx, "submit") == {.SUBMIT} {
        submit = true
    }

    if submit {
        ev.signal(&ue.sendEvent, input[:strlen])
        mem.set(raw_data(input[:]), 0, strlen)
        strlen = 0
    }
}

@(private)
draw_file_io :: proc(ctx: ^mu.Context)
{
    state := s.get_state()

    // Send file
    {
        @static filepath := [1024]u8{}
        @static filepath_len := 0

        mu.layout_row(ctx, {-1}, 60)
        mu.layout_begin_column(ctx)
        defer mu.layout_end_column(ctx)
        mu.textbox(ctx, filepath[:], &filepath_len)
        if .SUBMIT in mu.button(ctx, "Send file") {
            ev.signal(&ue.sendFile, transmute(string)filepath[:])
        }
    }

    // Trace to file
    {
        @static filepath := [1024]u8{}
        @static filepath_len := 0

        mu.layout_row(ctx, {-1}, 60)
        mu.layout_begin_column(ctx)
        defer mu.layout_end_column(ctx)
        mu.textbox(ctx, filepath[:], &filepath_len)
        disabled := mu.Options { .NO_INTERACT, .ALIGN_CENTER }
        enabled := mu.Options { .ALIGN_CENTER }
        start_opts := state.tracing ? disabled : enabled
        stop_opts  := state.tracing ? enabled : disabled
        if .SUBMIT in mu.button(ctx, "Start", opt = start_opts) {
            ev.signal(&ue.startTrace, transmute(string)filepath[:])
            mu.set_focus(ctx, 0)
        }
        if .SUBMIT in mu.button(ctx, "Stop", opt = stop_opts) {
            ev.signal(&ue.stopTrace)
            mu.set_focus(ctx, 0)
        }
    }
}

@(private)
register_event_handlers :: proc()
{
    // empty
}


//draw_bml :: proc(ctx: ^mu.Context)
//{
//    state := s.get_state()
//    bml_widget.drawCreator(ctx, state.bml_protocol, &state.bml_packet)
//}
