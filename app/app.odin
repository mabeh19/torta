package app

import "../view"
import "../state"
import "../configuration"
import backend "../view/backends/microui"

import ev "../event"
import pe "../process_events"

import "core:thread"
import "core:time"
import "core:fmt"
import "core:log"
import "base:runtime"

run :: proc()
{
    log_level := runtime.Logger_Level.Debug when ODIN_DEBUG else runtime.Logger_Level.Info
    logger := log.create_console_logger(log_level)
    context.logger = logger
    defer log.destroy_console_logger(logger)
    configuration.load()
    state.init()
    view.init()

when configuration.LOCAL_TEST {
    thread.create_and_start(proc() {
        iter := 0
        for {
            str : string = "this is a very long line of text that will surely cause a line break and fill a lot\n"
            msg := fmt.aprintf("[%v] %v", iter, str)
            defer delete(msg)
            ev.signal(&pe.dataReceivedEvent, transmute([]u8)msg)

            iter += 1
            time.sleep(20 * time.Millisecond)
        }
    })
}

    for !view.should_close() {
        backend.draw(view.draw)
    }

    view.close()
    state.cleanup()
    configuration.cleanup()
}
