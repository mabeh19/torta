package view

import s "../state"
import ue "../user_events"
import ev "../event"
import "../serial"
import "../configuration"

import "core:fmt"
import "core:c"
import "core:mem"
import "core:strconv"
import "core:log"
import "core:math"

import mu "vendor:microui"


Parity :: enum {
    None    = 0,
    Even    = 1,
    Odd     = 2
}


Settings :: struct {
    selectedPort: string,
    ports: [1024]u8,
    baudrate: [256]u8,
    baudrateLen: int,
    baudrateParsed: int,
    baudrateIsValid: bool,
    stopBits: f32,
    parity: Parity,
    flowControl: bool,
}


settings_ := Settings {
    baudrate = {0 = '9', 1 = '6', 2 = '0', 3 = '0', 4..<256 = 0},
    baudrateParsed = 9600,
    baudrateIsValid = true,
}

tmp_settings_ := Settings {}

init_settings :: proc()
{
    config := &configuration.config
    settings_ = convert_settings(config.defaultPortSettings)
    tmp_settings_ = settings_
    ev.signal(&ue.settingsChanged, config.defaultPortSettings)
}

draw_settings :: proc(ctx: ^mu.Context)
{
    state := s.get_state()

    // Refresh
    if .SUBMIT in mu.button(ctx, "Refresh Ports") {
        ev.signal(&ue.refreshPortsEvent)
    }
    if .ACTIVE in mu.header(ctx, "Ports") {
        mu.layout_begin_column(ctx)
        defer mu.layout_end_column(ctx)

        mu.layout_row(ctx, {80, -1}, -100)
        mu.label(ctx, "Selected port: ")
        mu.label(ctx, tmp_settings_.selectedPort)

        mu.layout_row(ctx, {-1}, 200)
        mu.begin_panel(ctx, "Port list")
        for port in state.ports {
            if .ACTIVE in mu.treenode(ctx, port.port_name) {
                // TODO: add info about port here
                if .SUBMIT in mu.button(ctx, "Select") {
                    tmp_settings_.selectedPort = port.port_name
                }
            }
        }
        mu.end_panel(ctx)
    }


    mu.layout_row(ctx, {80, -1}, 24)
    mu.label(ctx, "Baudrate")
    if .CHANGE in mu.textbox(ctx, tmp_settings_.baudrate[:], &tmp_settings_.baudrateLen) {
        tmp_settings_.baudrateParsed, tmp_settings_.baudrateIsValid = strconv.parse_int(transmute(string)tmp_settings_.baudrate[:tmp_settings_.baudrateLen])
    }

    mu.layout_row(ctx, {80, -1}, 8)
    mu.label(ctx, "Stop Bits")
    mu.slider(ctx, &tmp_settings_.stopBits, 0, 2, 1.0, "%.0f")
    

    mu.layout_row(ctx, {80, -1}, 8)
    mu.label(ctx, "Parity")
    parity(ctx, &tmp_settings_.parity)

    mu.layout_row(ctx, {80, -1}, 24)
    mu.checkbox(ctx, "Flow Control", &tmp_settings_.flowControl)

    mu.layout_row(ctx, {-1}, -50)
    mu.label(ctx, "")

    mu.layout_row(ctx, {-200, 100, -1}, -1)
    mu.label(ctx, "")
    button_flags : mu.Options = tmp_settings_.baudrateIsValid ? {} : { .NO_INTERACT }
    if .SUBMIT in mu.button(ctx, "Save", opt = button_flags | { .ALIGN_CENTER }) {
        view_state_.in_settings = false

        settings_ = tmp_settings_
        ev.signal(&ue.settingsChanged, convert_settings(tmp_settings_))
    }
    if .SUBMIT in mu.button(ctx, "Cancel") {
        view_state_.in_settings = false
    }
}

parity :: proc(ctx: ^mu.Context, value: ^Parity, opt: mu.Options = {.ALIGN_CENTER}) -> (res: mu.Result_Set) {
	last := value^
    fmt_string := "%s"
    low := Parity.None
    high := Parity.Odd
	v := last
    step := 1
    diff := i32(high - low)
	id := mu.get_id(ctx, uintptr(value))
	base := mu.layout_next(ctx)

	/* handle normal mode */
	mu.update_control(ctx, id, base, opt)

	/* handle input */
	if ctx.focus_id == id && ctx.mouse_down_bits == {.LEFT} {
		v = Parity(f32(low) + mu.Real(ctx.mouse_pos.x - base.x) * f32(diff) / mu.Real(base.w))
		if step != 0.0 {
			v = Parity(int(math.floor((f32(v) + f32(step)/2.0) / f32(step)) * f32(step)))
		}
	}
	v = clamp(v, low, high); value^ = Parity(v)
	if last != v {
		res += {.CHANGE}
	}

	/* draw base */
	mu.draw_control_frame(ctx, id, base, .BASE, opt)
	/* draw thumb */
	w := ctx.style.thumb_size
	x := i32((f32(v) - f32(low)) * mu.Real(base.w - w) / f32(diff))
	thumb := mu.Rect{base.x + x, base.y, w, base.h}
	mu.draw_control_frame(ctx, id, thumb, .BUTTON, opt)
	/* draw text  */
	text_buf: [4096]byte
	mu.draw_control_text(ctx, fmt.bprintf(text_buf[:], fmt_string, v), base, .TEXT, opt)

	return
}

convert_settings :: proc {convert_settings_view2serial, convert_settings_serial2view}

convert_settings_view2serial :: proc(settings: Settings) -> serial.PortSettings
{
    parityAsChar := [Parity]u8{
        .None = 'n', 
        .Odd = 'o', 
        .Even = 'e',
    }
    return serial.PortSettings {settings.selectedPort, settings.baudrateParsed, parityAsChar[settings.parity], u8(settings.stopBits), true, settings.flowControl}
}

convert_settings_serial2view :: proc(portSettings: serial.PortSettings) -> Settings
{
    charAsParity :: proc(c: u8) -> Parity {
        switch c {
        case 'n':
            return .None
        case 'o':
            return .Odd
        case 'e':
            return .Even
        case:
            log.warn("Unknown parity:", c)
            return .None
        }
    }
    settings := Settings {portSettings.port, {}, {}, 0, portSettings.baudrate, true, f32(portSettings.stopBits), charAsParity(portSettings.parity), portSettings.flowControl}

    bs := fmt.bprint(settings.baudrate[:], settings.baudrateParsed)
    settings.baudrateLen = len(bs)

    return settings
}
