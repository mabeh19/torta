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
import "core:mem/virtual"
import "core:unicode"
import "core:time"

import ue "../user_events"
import pe "../process_events"
import s "../state"
import conf "../configuration"
import "../errors"

import rb "../ringbuffer"
import ev "../event"

import mu "vendor:microui"
import backend "backends/microui"


EXPORT_NAMESPACE :: "view_"


SCREEN_WIDTH    :: 640
SCREEN_HEIGHT   :: 480

DisplaySetting :: enum {
    Auto_Scroll,
    Show_Times
}

DisplaySettings :: bit_set[DisplaySetting]

ViewState :: struct {
    frame_memory: virtual.Arena,
    font: mu.Font,
    font_size: f32,
    font_spacing: f32,
    font_line_spacing: f32,
    in_settings: bool,
    display_settings: DisplaySettings,
    error_message: string,

    data: struct {
        lines: u32,
    },

    displayBuffer : [dynamic]u8
}

view_state_ := ViewState{}

@(export, link_prefix=EXPORT_NAMESPACE)
init :: proc ()
{
    _ = virtual.arena_init_growing(&view_state_.frame_memory)
    backend.init(SCREEN_WIDTH, SCREEN_HEIGHT)
    init_settings()
    register_event_handlers()

    view_state_.displayBuffer = make([dynamic]u8)

    if conf.config.font.name == "" {
        conf.config.font = conf.DEFAULT_CONFIG.font
    }
    backend.set_data_font(conf.config.font.name, conf.config.font.size)

    clear_error_message()
}

set_error_message :: proc(msg: string)
{
    view_state_.error_message = msg
}

clear_error_message :: proc()
{
    view_state_.error_message = ""
}

labelf :: proc(ctx: ^mu.Context, f: string, args: ..any)
{
    s := fmt.aprintf(f, ..args)
    defer delete(s)
    mu.label(ctx, s)
}

event_pending :: proc() -> bool
{
    return backend.event_pending()
}

@(export, link_prefix=EXPORT_NAMESPACE)
draw :: proc (ctx: ^mu.Context)
{
    context.allocator = virtual.arena_allocator(&view_state_.frame_memory)
    // Drawing logic
    opts := mu.Options {
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

        if view_state_.error_message != "" {
            mu.layout_row(ctx, {-1}, -40)
            mu.text(ctx, view_state_.error_message)

            mu.layout_row(ctx, {-1}, 40)
            if .SUBMIT in mu.button(ctx, "OK") {
                clear_error_message()
            }
            
        }
        else if view_state_.in_settings {
            draw_settings(ctx)
        }
        else {
            mu.layout_row(ctx, {-100, -1}, -1)
            // Column 1
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)

                draw_port_info(ctx)
                height : i32 = state.bufferedMode ? -90 : -1
                mu.layout_row(ctx, {-1}, height)
                draw_data_view(ctx)

                if state.bufferedMode {
                    mu.layout_row(ctx, {-90, -1}, 20)
                    draw_input_field(ctx)
                }

                mu.layout_row(ctx, {-1}, 10)
                mu.layout_next(ctx)

                // File I/O
                draw_file_io(ctx)
            }

            // Column 2
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)

                mu.layout_row(ctx, {-1}, 20)
                if mu.button(ctx, "Settings") == {.SUBMIT} {
                    view_state_.in_settings = true
                    tmp_settings_ = settings_
                }
                draw_port_toggle(ctx)

                // Clear
                mu.layout_row(ctx, {-1}, 20)
                if mu.button(ctx, "Clear") == {.SUBMIT} {
                    ev.signal(&ue.clearEvent)
                    view_state_.data.lines = 0
                }

                // Autoscroll
                mu.layout_row(ctx, {-1}, 20)
                @static autoscroll := true
                mu.checkbox(ctx, "Autoscroll", &autoscroll)
                update_viewsettings(.Auto_Scroll, autoscroll)

                // Show timestamps
                mu.layout_row(ctx, {-1}, 20)
                @static timestamps := true
                mu.checkbox(ctx, "Timestamps", &timestamps)
                update_viewsettings(.Show_Times, timestamps)

                // Text settings
                mu.layout_row(ctx, {-1}, 20)
                mu.checkbox(ctx, "Echo", &state.echo)
                mu.layout_row(ctx, {-1}, 20)
                mu.checkbox(ctx, "Append nl", &state.appendNewLine)
                mu.layout_row(ctx, {-1}, 20)
                mu.checkbox(ctx, "Append cr", &state.appendCarriageReturn)
                mu.layout_row(ctx, {-1}, 20)
                mu.checkbox(ctx, "Append 0", &state.appendNullByte)

                mu.layout_row(ctx, {-1}, 20)
                if .CHANGE in mu.checkbox(ctx, "Buffered", &state.bufferedMode) {
                    backend.forward_input(!state.bufferedMode)
                }
            }
        }
    }
    virtual.arena_destroy(&view_state_.frame_memory)
}

@(export, link_prefix=EXPORT_NAMESPACE)
close :: proc ()
{
    backend.close_window()
    delete(view_state_.displayBuffer)
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
    state := s.get_state()

    mu.begin_panel(ctx, "Data window")
    panel := mu.get_current_container(ctx)
    mu.layout_row(ctx, {-1}, -1)
    if state.bytes_read > 0 {
        switch data in state.data {
        case s.Lines:
            total_lines := len(data)
            line_height := backend.font_height()
            visible_lines := int(panel.rect.h / (line_height + ctx.style.padding)) + 2            
            content_height := (line_height + ctx.style.padding) * i32(total_lines)
            panel.content_size.y =  content_height
            scroll_pct := f32(panel.scroll.y) / (f32(panel.content_size.y) - f32(panel.rect.h))
            line := int(scroll_pct * f32(total_lines))
            if line > total_lines - visible_lines {
                line = total_lines - visible_lines
            }
            if line < 0 {
                line = 0
            }

            d := data[line:min(line + visible_lines, len(data))]

            // compute maximum line width across all lines so panel can be
            // horizontally scrollable (set content_size.x)
            max_w : i32 = 0
            for l_all in data {
                if len(l_all.data) == 0 {
                    continue
                }
                w := backend.text_width(string(l_all.data[:]))
                if w > max_w { max_w = w }
            }

            // add a little padding to content width
            panel.content_size.x = max_w + ctx.style.padding * 2

            offset := panel.scroll.y
            if offset > line_height {
                mu.layout_row(ctx, {-1}, offset)
                mu.text(ctx, "start filler")
            }
            mu.layout_row(ctx, {-1}, panel.body.h)
            mu.layout_begin_column(ctx)
            for l in d {
                if len(l.data) == 0 {
                    continue
                }
                buf: [time.MIN_HMS_LEN]u8 
                mu.layout_row(ctx, {-1}, line_height)
                if .Show_Times in view_state_.display_settings {
                    labelf(ctx, "%s %s", time.time_to_string_hms(l.timestamp, buf[:]), string(l.data[:])) 
                }
                else {
                    labelf(ctx, "%s", string(l.data[:]))
                }
            }
            mu.layout_end_column(ctx)
            mu.layout_row(ctx, {-1}, -1)
            mu.end_panel(ctx)

            panel.content_size.y = content_height

        case s.RawData:
            // Just print the whole buffer for raw data
            mu.text(ctx, string(data[:]))
            mu.end_panel(ctx)
        }        
    }
    else {
        mu.text(ctx, "No data received yet")
        mu.end_panel(ctx)
    }

    
    if .Auto_Scroll in view_state_.display_settings {
        panel.scroll.y = panel.content_size.y
    }
}


@(private)
draw_input_field :: proc(ctx: ^mu.Context)
{
    @static input := [4096]u8{}
    @static strlen := 0

    submit := false
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

    mu.layout_row(ctx, {-1}, 40)
    mu.layout_begin_column(ctx)
    defer mu.layout_end_column(ctx)

    // Send file
    {
        @static filepath := [1024]u8{}
        @static filepath_len := 0

        mu.layout_row(ctx, {80, -80, -1}, 20)
        mu.label(ctx, "Send File")
        mu.textbox(ctx, filepath[:], &filepath_len)
        if .SUBMIT in mu.button(ctx, "Send") {
            ev.signal(&ue.sendFile, transmute(string)filepath[:])
        }
    }

    // Trace to file
    {
        @static filepath := [1024]u8{}
        @static filepath_len := 0

        mu.layout_row(ctx, {80, -80, -40, -1}, 20)
        mu.label(ctx, "Trace")
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

@private
draw_port_info :: proc(ctx: ^mu.Context)
{
    state := s.get_state()
    mu.layout_row(ctx, {-1}, 20)

    if state.portSettings.port == "" {
        labelf(ctx, "No port selected")
        return
    }

    parity := unicode.to_upper(rune(state.portSettings.parity))
    labelf(ctx, "%v - %v %v%v%v", state.portSettings.port, state.portSettings.baudrate, 8, parity, state.portSettings.stopBits)
}
    

import sdl "vendor:sdl2"
import "../keycode_translator"

@(private)
register_event_handlers :: proc()
{
    @static keyPressListener : ev.EventSub(sdl.KeyboardEvent)
    ev.listen(&ue.rawKeypressEvent, &keyPressListener, proc (kev: sdl.KeyboardEvent) {
        encoded_sym, ok := keycode_translator.translate_symbol(kev.keysym)
        if !ok { 
            log.warnf("Input not forwarded: %v", kev.keysym)
            return 
        }

        ev.signal(&ue.sendEvent, transmute([]u8)encoded_sym)
    })

    @static dataReceivedListener : ev.EventSub([]u8)
    ev.listen(&pe.dataReceivedEvent, &dataReceivedListener, proc (data: []u8) {
        backend.push_frame_update_event()
    })
    
    @static errorOccurredListener : ev.EventSub(errors.Error)
    ev.listen(&errors.raised, &errorOccurredListener, proc (err: errors.Error) {
        switch err {
        case .CONFIG_LOAD_ERROR:
            set_error_message("Failed to load configuration file, please check your config file")
        }
    })
}

@(private)
update_viewsettings :: proc(setting: DisplaySetting, on: bool)
{
    if on {
        view_state_.display_settings += { setting }
    }
    else {
        view_state_.display_settings -= { setting }
    }
}
