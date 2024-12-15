package torta

import "core:fmt"
import "core:log"
import "base:runtime"

import "view"
import "state"
import "configuration"
import backend "view/backends/microui"

import ev "event"
import pe "process_events"
import "core:thread"
import "core:time"

main :: proc()
{
    log_level := runtime.Logger_Level.Debug when ODIN_DEBUG else runtime.Logger_Level.Info
    context.logger = log.create_console_logger(log_level)
    configuration.load()
    state.init()
    view.init()

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

    for !view.should_close() {
        backend.draw(view.draw)
    }

    view.close()
}
