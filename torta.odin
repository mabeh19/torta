package torta

import "core:log"

import "view"
import "state"
import "configuration"
import backend "view/backends/microui"


main :: proc()
{
    context.logger = log.create_console_logger()
    configuration.load()
    state.init()
    view.init()

    for !view.should_close() {
        backend.draw(view.draw)
    }

    view.close()
}
