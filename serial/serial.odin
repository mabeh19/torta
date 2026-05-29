package serial

import "core:c"
import "core:strings"
import "core:os"
import "core:log"
import "core:nbio"

Port :: struct {
    file: Maybe(nbio.Handle)
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

    nbio.acquire_thread_event_loop()
    defer nbio.release_thread_event_loop()

    fd, f_err := nbio.open_sync(settings.port, mode = { .Write, .Read, .Sync })
    if f_err != nil {
        log.errorf("Unable to open port: %v", f_err)
    }

    ok = f_err == nil
    port.file = fd

    return port, ok
}

close_port :: proc(port: ^Port) 
{
    if fd, ok := port.file.?; ok {
        nbio.acquire_thread_event_loop()
        defer nbio.release_thread_event_loop()
        cop := nbio.close(fd)
        nbio.run()
        if cop.close.err != nil {
            log.errorf("Unable to close port: %v", cop.close.err)
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
        nbio.acquire_thread_event_loop()
        defer nbio.release_thread_event_loop()

        wop := nbio.write(fd, 0, data, ignore_cb, timeout = 0)
        nbio.tick(0)
        if wop.write.err != nil {
            log.errorf("Error writing to port: %v", wop.write.err)
        }
        ok = wop.write.err == nil
    }

    return
}

read :: proc(port: Port) -> (data: u8, ok: bool)
{
    b := [1]u8{}

    if fd, ok := port.file.?; ok {
        nbio.acquire_thread_event_loop()
        defer nbio.release_thread_event_loop()

        rop := nbio.read(fd, 0, b[:], ignore_cb, timeout = 0)
        nbio.tick(0)
        if rop.read.err == nil {
            data = b[0]
            ok = true
        }
        else if rop.read.err != .Timeout {
            log.errorf("Error reading from port: %v", rop.read.err)
        }
    }

    return {}, {}
}

@private
ignore_cb :: proc(op: ^nbio.Operation)
{
    // No-op callback 
}