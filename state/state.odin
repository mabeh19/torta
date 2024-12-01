package state


import ev "../event"
import ue "../user_events"
import pe "../process_events"
import rb "../ringbuffer"
import "../serial"
import "../internal"
import "../process"
import "../configuration"

import "core:log"
import "core:thread"
import "core:os"
import "core:io"

KB :: 1024
DATA_BUFFER_SIZE :: 1 * KB


State :: struct {
    // Data
    dataBuffer: rb.RingBuffer(u8),
    bytesRead: int,

    // Options
    echo: bool,
    appendNewLine: bool,
    appendCarriageReturn: bool,
    appendNullByte: bool,
    bufferedMode: bool,

    // File IO
    tracing: bool,
    traceWriter: io.Writer,

    // Port
    selectedPort: string,
    port: serial.Port,
    portSettings: serial.PortSettings,
    ports: []string,
    reader: ^thread.Thread,
}

state := State {
    appendNewLine = true,
    echo = true,
    bufferedMode = true,
}

port_is_open :: proc() -> bool {
    return state.reader != nil
}

data_buffer_size :: proc() -> int {
    return len(state.dataBuffer.data)
}

init :: proc()
{
    config := &configuration.config
    state.dataBuffer = rb.new(config.historyLength, u8, config.infiniteHistory)

    ev.listen(&ue.clearEvent, proc() {
        rb.clear(&state.dataBuffer)
    })

    ev.listen(&pe.dataReceivedEvent, proc(data: []u8) {
        log.debug("Data received: ", data)
        rb.push(&state.dataBuffer, data)
        state.bytesRead += len(data)
    })

    ev.listen(&ue.settingsChanged, proc(settings: serial.PortSettings) {
        log.debugf("New settings: %v", settings)
        if port_is_open() {
            ev.signal(&ue.openEvent, false)
        }
        state.portSettings = settings
    })

    ev.listen(&ue.openEvent, proc(open: bool) {
        if open {
            log.debugf("Opening port %v with settings", state.portSettings)
            ok := false

            if state.port, ok  = serial.open_port(state.portSettings); ok {
                log.debug("Starting reader")
                state.reader = process.read_port_async(state.port.file)
            }
            else {
                log.debug("Failed to open port")
                state.reader = nil
            }
        }
        else {
            log.debug("Closing port")
            serial.close_port(&state.port)

            if state.reader != nil {
                thread.terminate(state.reader, 0)
                state.reader = nil
            }
        }
    })

    ev.listen(&ue.sendEvent, proc(data: []u8) {
        send :: proc(data: []u8) {
            log.debugf("Pushing %v bytes: %v", len(data), data)
            if state.echo {
                rb.push(&state.dataBuffer, data)
            }
            os.write(state.port.file, data)
        }
        send_byte :: proc(data: u8) {
            log.debugf("Pushing byte: %v", data)
            if state.echo {
                rb.push(&state.dataBuffer, data)
            }
            os.write_byte(state.port.file, data)
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
        if state.ports != nil {
            delete(state.ports)
        }

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
                state.traceWriter = os.stream_from_handle(file)
                state.tracing = true

                ev.listen(&pe.dataReceivedEvent, trace_data)
            }
        })

        ev.listen(&ue.stopTrace, proc(){
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
}

get_state :: proc() -> ^State 
{
    return &state
}
