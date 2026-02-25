package state


import ev "../event"
import ue "../user_events"
import pe "../process_events"
import rb "../ringbuffer"
import "../serial"
import "../internal"
import "../configuration"
import "../errors"

import "core:log"
import "core:thread"
import "core:os"
import "core:io"
import "core:slice"
import "core:time"
import "core:strings"
import mem "core:mem/virtual"

Line :: struct {
    data: [dynamic]u8,
    timestamp: time.Time
}

Lines :: distinct [dynamic]Line
RawData :: distinct [dynamic]u8

State :: struct {
    // Base
    arena: mem.Arena,

    // Data
    data: union #no_nil {
        Lines,
        RawData,
    },
    bytes_read: int,
    dataAllocator: mem.Arena, // dedicated arena for serial data

    // Options
    echo: bool,
    appendNewLine: bool,
    appendCarriageReturn: bool,
    appendNullByte: bool,
    bufferedMode: bool,

    // File IO
    tracing: bool,
    traceWriter: io.Writer,
    traceListener: ev.EventSub([]u8),

    // Port
    selectedPort: string,
    port: serial.Port,
    portSettings: serial.PortSettings,
    ports: []internal.SerialPort,
}

state := State {
    appendNewLine = true,
    echo = true,
    bufferedMode = true,
}

port_is_open :: proc() -> bool {
    return serial.is_open(state.port)
}

data_buffer_size :: proc() -> (l: int) {
    switch d in state.data {
    case Lines:
        l = len(d)
    case RawData:
        l = len(d)
    }
    return
}

read_new_data :: proc() -> (new_data: bool) {
    if port_is_open() {
        b := [1]u8{}
        ok := false
        for {
            if b[0], ok = serial.read(state.port); !ok {
                break
            }
            new_data = true
            ev.signal(&pe.dataReceivedEvent, b[:])
        }
    }

    return
}

init :: proc()
{
    _ = mem.arena_init_growing(&state.arena)
    context.allocator = mem.arena_allocator(&state.arena)

    _ = mem.arena_init_growing(&state.dataAllocator)

    state.portSettings = configuration.config.defaultPortSettings
    state.data = make(Lines)

    ev.listen(&ue.clearEvent, proc() {
        switch &d in state.data {
        case Lines:
            clear(&d)
        case RawData:
            clear(&d)
        }
        mem.arena_free_all(&state.dataAllocator)
    })

    ev.listen(&pe.dataReceivedEvent, proc(data: []u8) {
        context.allocator = mem.arena_allocator(&state.dataAllocator)
        state.bytes_read += len(data)

        switch &d in state.data {
        case Lines:
            lines, err := strings.split(string(data), "\n")
            defer delete(lines)
            if err != nil {
                break
            }

            // append first line to the end of the last line
            if len(d) == 0 {
                line := Line {
                    data = make([dynamic]u8),
                    timestamp = time.now()
                }
                append(&line.data, lines[0])
                append(&d, line)
            }
            else {
                append(&d[len(d)-1].data, lines[0])
            }

            if len(lines) == 1 {
                break
            }

            for l in lines[1:] {
                line := Line {
                    data = make([dynamic]u8),
                    timestamp = time.now()
                }
                append(&line.data, l)
                append(&d, line)
            }
        case RawData:
            append(&d, ..data)
        }
    })

    ev.listen(&ue.settingsChanged, proc(settings: serial.PortSettings) {
        log.debugf("New settings: %v", settings)
        if port_is_open() {
            ev.signal(&ue.openEvent, false)
        }
        state.portSettings = settings

        try_autoconnect()
    })

    ev.listen(&ue.openEvent, proc(open: bool) {
        if open {
            log.debugf("Opening port %v with settings", state.portSettings)
            ok := false

            if state.port, ok  = serial.open_port(state.portSettings); ok {
                log.debug("Starting reader")
            }
            else {
                log.debug("Failed to open port")
            }
        }
        else {
            log.debug("Closing port")
            serial.close_port(&state.port)
        }
    })

    ev.listen(&ue.sendEvent, proc(data: []u8) {
        send :: proc(data: []u8) {
            log.debugf("Pushing %v bytes: %v", len(data), data)
            
            if !serial.send(state.port, data) {
                return
            }
            if state.echo {
                ev.signal(&pe.dataReceivedEvent, data)
            }
        }
        send_byte :: proc(data: u8) {
            log.debugf("Pushing byte: %v", data)
            
            if !serial.send(state.port, {data}) {
                return
            }

            if state.echo {
                ev.signal(&pe.dataReceivedEvent, []u8{data})
            }
        }

        send(data)
        if state.appendCarriageReturn {
            send_byte('\r')
        }
        if state.appendNewLine {
            send_byte('\n')
        }
        if state.appendNullByte {
            send_byte(0)
        }
    })

    ev.listen(&ue.refreshPortsEvent, proc() {
        ports := internal.get_serial_ports()

        state.ports = ports
    })

    ev.listen(&ue.sendFile, proc(fp: string) {
        data, ok := os.read_entire_file(fp)
        log.debugf("Sending file %v .. %v", fp, ok)
        if !ok { return }
        ev.signal(&ue.sendEvent, data)
    })

    {
        trace_data :: proc(data: []u8) {
            log.debug("Tracing ", data)

            if n, err := io.write(state.traceWriter, data); err != .None {
                log.errorf("Unable to write to writer (%v)", err)
            }
        }

        ev.listen(&ue.startTrace, proc(fp: string) {
            when ODIN_OS == .Linux {
                accessFlags := os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
            }
            else when ODIN_OS == .Windows {
                accessFlags := 0
            }
            if file, err := os.open(fp, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, accessFlags); err != nil {
                log.errorf("Unable to open file (%v) for writing given path %v", err, fp)
                return
            }
            else {
                context.allocator = mem.arena_allocator(&state.arena)
                state.traceWriter = os.stream_from_handle(file)
                state.tracing = true

                ev.listen(&pe.dataReceivedEvent, trace_data)
            }
        })

        ev.listen(&ue.stopTrace, proc() {
            state.tracing = false
            io.close(state.traceWriter)
            if sub, allocced := ev.unlisten(&pe.dataReceivedEvent, trace_data); allocced {
                free(sub)
            }
        })
    }

    ev.listen(&ue.quitEvent, proc() {
        if state.tracing {
            io.close(state.traceWriter)
        }
    })

    // Load ports at startup
    ev.signal(&ue.refreshPortsEvent)
}

cleanup :: proc()
{
    if !errors.is_raised(.CONFIG_LOAD_ERROR) && configuration.config.saveLatestPortSettings {
        configuration.config.defaultPortSettings = state.portSettings
        configuration.save()
    }
    mem.arena_destroy(&state.arena)
    mem.arena_destroy(&state.dataAllocator)
}

get_state :: proc() -> ^State 
{
    return &state
}

@private
try_autoconnect :: proc()
{
    for &port in state.ports {
        if strings.string_from_null_terminated_ptr(raw_data(port.port_name[:]), len(port.port_name)) == configuration.config.defaultPortSettings.port {
            ev.signal(&ue.openEvent, true)
        }
    }
}
