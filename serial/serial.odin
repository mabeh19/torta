package serial

import "core:c"
import "core:strings"
import "core:os"

when ODIN_OS == .Linux {
foreign import sl "serial_linux_backend.a"
}
else when ODIN_OS == .Windows {

foreign import sl "serial_windows_backend.lib"
}


foreign sl {
    OpenPort :: proc(cstring, ^PortSettingsInternal, ^os.Handle) -> bool ---
    ClosePort :: proc(fd: c.int) ---
}


Port :: struct {
    file: os.Handle
}


@private
PortSettingsInternal :: struct {
    baudrate: c.uint32_t,
    parity: c.char,
    stopBits: c.uint8_t,
    blocking: c.bool,
    controlflow: c.bool,
};


PortSettings :: struct {
    port: string,
    baudrate: int,
    parity: u8,
    stopBits: u8,
    blocking: bool,
    flowControl: bool,
};


open_port :: proc(settings: PortSettings) -> (port: Port, ok: bool)
{
    settings_internal := PortSettingsInternal {
        baudrate = u32(settings.baudrate),
        parity = settings.parity,
        stopBits = settings.stopBits,
        blocking = settings.blocking,
        controlflow = false,
    }

    cport := strings.clone_to_cstring(settings.port)
    defer delete(cport)

    ok = OpenPort(cport, &settings_internal, &port.file)

    return port, ok
}

close_port :: proc(port: ^Port) 
{
    ClosePort(c.int(port.file))
}
