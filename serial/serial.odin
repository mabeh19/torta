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
    file: Maybe(os.Handle)
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

    fd : os.Handle
    ok = OpenPort(cport, &settings_internal, &fd)

    if ok {
        port.file = fd
    }

    return port, ok
}

close_port :: proc(port: ^Port) 
{
    if fd, ok := port.file.?; ok {
        ClosePort(c.int(fd))
        port.file = nil
    }
}

is_open :: proc(port: Port) -> bool
{
    _, ok := port.file.?
    return ok
}

send :: proc(port: Port, data: []u8)
{
    if fd, ok := port.file.?; ok {
        os.write(fd, data)
    }
}

read :: proc(port: Port) -> (data: u8, ok: bool)
{
    b := [1]u8{}

    if fd, ok := port.file.?; ok {
        pfd := os.pollfd {
            fd = c.int(fd),
            events = 1,
            revents = 0
        }
        if avail, err := os.poll({pfd}, 0); avail > 0 && err == nil {
            if n, err := os.read(fd, b[:]); err == nil && n > 0 {
                return b[0], true
            }
        }
    }

    return {}, {}
}
