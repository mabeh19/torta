package internal

import "core:fmt"
import "core:log"
import "core:os"
import "core:c"

import usb "libusb"

NUM_PORTS_SUPPORTED :: 1024


DeviceInfo :: struct {
    manufacturer:       [256]byte,
    product:            [256]byte,
    driver:             [256]byte,
    serialnum:          [256]byte,
    id:                 [10]byte,
    revision:           [10]byte,
}

SerialPort :: struct {
    port_name:  [256]byte,
    info:       DeviceInfo,
}

UsbContext :: struct {
    //ctx:            usb.Context,
    //devices:        [^]usb.Device,
    num_devices:    int,
}

ctx_ := UsbContext{}


get_serial_ports :: proc() -> []SerialPort
{
    @static ports := [NUM_PORTS_SUPPORTED]SerialPort{}
    
    // reset ports
    ports = {}

    num_ports := get_serial_ports_internal(ports[:])

    return ports[:num_ports]
}

