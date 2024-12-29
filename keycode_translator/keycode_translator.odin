package keycode_translator

import "core:encoding/ansi"
import sdl "vendor:sdl2"

translate_symbol :: proc(sym: sdl.Keysym) -> (encoded: string = "", ok: bool = true)
{
    #partial switch sym.sym {
    case .TAB:
        encoded = "\t"
    case .BACKSPACE:
        encoded = "\b"
    case .DELETE:
        encoded = "\x7F"
    case .RETURN:
        encoded = "\n"
    case .LEFT:
        encoded = ansi.CSI + ansi.CUB + ansi.SGR
    case .RIGHT:
        encoded = ansi.CSI + ansi.CUF + ansi.SGR
    case .UP:
        encoded = ansi.CSI + ansi.CUU + ansi.SGR
    case .DOWN:
        encoded = ansi.CSI + ansi.CUD + ansi.SGR
    case:
        ok = false
    }

    return
}
