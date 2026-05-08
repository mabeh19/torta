package serial

import "core:c"
import "core:strings"
import "core:os"
import "core:log"


Port :: struct {
    file: Maybe(^os.File)
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

    fd, f_err := os.open(settings.port, { os.File_Flag.Write, os.File_Flag.Read, os.File_Flag.Sync, os.File_Flag.Non_Blocking })
    if f_err != nil {
        log.errorf("Unable to open port: %v", f_err)
    }

    ok = fd != nil
    port.file = fd

    return port, ok
}

close_port :: proc(port: ^Port) 
{
    if fd, ok := port.file.?; ok {
        err := os.close(fd)
        if err != nil {
            log.errorf("Unable to close port: %v", err)
        }
        else {
            port.file = nil
        }
    }
}

is_open :: proc(port: Port) -> bool
{
    return port.file != nil
}

send :: proc(port: Port, data: []u8) -> (ok: bool)
{
    if fd, exists := port.file.?; exists {
        _, err := os.write(fd, data)
        if err != nil {
            log.errorf("Error writing to port: %v", err)
        }
        ok = err == nil
    }

    return
}

read :: proc(port: Port) -> (data: u8, ok: bool)
{
    b := [1]u8{}

    if fd, ok := port.file.?; ok {
        if n, err := os.read(fd, b[:]); err == nil && n > 0 {
            return b[0], true
        }
    }

    return {}, {}
}
