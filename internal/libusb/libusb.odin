package libusb 

import "core:c"

foreign import lib "libusb-1.0.so"

USE_LIBUSB :: false

when USE_LIBUSB
{

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

Option :: enum {
    LOG_LEVEL   = 0,
    USE_USBDK   = 1,
    NO_DEVICE_DISCOVERY = 2,
    LOG_CB      = 3,
}

Log_Level :: enum {
    NONE    = 0,
    ERROR   = 1,
    WARNING = 2,
    INFO    = 3,
    DEBUG   = 4,
}

InitOptions :: struct {
    option: Option,
    value: struct #raw_union {
        ival: c.int,
        log_cb: proc "c" (Context, Log_Level, cstring)
    }
}

Device_Descriptor :: struct {
    bLength:            c.uint8_t,
    bDescriptorType:    c.uint8_t,
    bcdUSB:             c.uint16_t,
    bDeviceClass:       c.uint8_t,
    bDeviceSubClass:    c.uint8_t,
    bDeviceProtocol:    c.uint8_t,
    bMaxPacketSize0:    c.uint8_t,
    idVendor:           c.uint16_t,
    idProduct:          c.uint16_t,
    bcdDevice:          c.uint16_t,
    iManufacturer:      c.uint8_t,
    iProduct:           c.uint8_t,
    iSerialNumber:      c.uint8_t,
    bNumConfigurations: c.uint8_t,
}

@(link_prefix="libusb_")
foreign lib {
    get_device_list     :: proc "c" (ctx: Context, list: ^[^]Device) -> c.ssize_t ---
    free_device_list    :: proc "c" (list: ^Device, unref_devices: c.int) ---
    get_bus_number      :: proc "c" (dev: Device) -> c.uint8_t ---
    get_port_number     :: proc "c" (dev: Device) -> c.uint8_t ---
    get_device_address  :: proc "c" (dev: Device) -> c.uint8_t ---
    open                :: proc "c" (dev: ^Device, handle: ^Device_Handle) -> c.int ---
    close               :: proc "c" (handle: ^Device_Handle) ---
    get_device          :: proc "c" (handle: ^Device_Handle) -> Device ---
    libusb_strerror     :: proc "c" (errcode: Error) -> cstring ---
    init_context        :: proc "c" (ctx: ^Context, options: [^]InitOptions, num_options: c.int) -> c.int ---

    // Descriptors
    get_device_descriptor           :: proc "c" (dev: Device, desc: ^Device_Descriptor) -> c.int ---
    get_string_descriptor_ascii     :: proc "c" (dev_handle: Device_Handle, desc_index: c.uint8_t, data: cstring, length: c.int) -> int ---
}
}
