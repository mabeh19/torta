package torta

import "app"

import "core:fmt"
import "core:mem"
import "core:mem/virtual"

main :: proc()
{
when ODIN_DEBUG {
    ta : mem.Tracking_Allocator
    mem.tracking_allocator_init(&ta, context.allocator)
    defer mem.tracking_allocator_destroy(&ta)
    context.allocator = mem.tracking_allocator(&ta)
}

    // Arena for all temporary allocations
    temp_allocs : virtual.Arena
    va_err := virtual.arena_init_growing(&temp_allocs)
    context.temp_allocator = virtual.arena_allocator(&temp_allocs)

    app.run()

when ODIN_DEBUG {
    for _, leak in ta.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
}
}
