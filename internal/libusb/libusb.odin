package libusb 

import "core:c"

foreign import lib "libusb"

Device :: distinct rawptr
Device_Handle :: distinct rawptr
Context :: distinct rawptr

Speed :: enum {
    UNKNOWN = 0,
    LOW = 1,
    FULL = 2,
    HIGH = 3,
    SUPER = 4,
    SUPER_PLUS = 5
}

Error :: enum {
    SUCCESS,
    IO,
    INVALID_PARAM,
    ACCESS,
    NO_DEVICE,
    NOT_FOUND,
    BUSY,
    TIMEOUT,
    OVERFLOW,
    PIPE,
    INTERRUPTED,
    NO_MEM,
    NOT_SUPPORTED,
    OTHER
}

Options :: struct {
    
}

foreign lib {
    get_device_list     :: proc "c" (ctx: Context, list: ^Device) -> c.ssize_t ---
    free_device_list    :: proc "c" (list: ^Device, unref_devices: c.int) ---
    get_bus_number      :: proc "c" (dev: ^Device) -> c.uint8_t ---
    get_port_number     :: proc "c" (dev: ^Device) -> c.uint8_t ---
    open                :: proc "c" (dev: ^Device, handle: ^Device_Handle) -> c.int ---
    close               :: proc "c" (handle: ^Device_Handle) ---
    get_device          :: proc "c" (handle: ^Device_Handle) -> Device ---
    strerror            :: proc "c" (errcode: Error) -> cstring ---
    init_context        :: proc "c" (ctx: ^Context, options: [^]Options, num_options: c.int) -> c.int ---
}

