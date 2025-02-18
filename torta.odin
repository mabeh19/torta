package torta

import "app"

import "core:fmt"
import "core:mem"

main :: proc()
{
when ODIN_DEBUG {
    ta : mem.Tracking_Allocator
    mem.tracking_allocator_init(&ta, context.allocator)
    defer mem.tracking_allocator_destroy(&ta)
    context.allocator = mem.tracking_allocator(&ta)
}
    
    app.run()

when ODIN_DEBUG {
    for _, leak in ta.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
}
}
