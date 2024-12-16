package internal

import "core:log"

import usb "libusb"

NUM_PORTS_SUPPORTED :: 1024

DeviceInfo :: struct {
    manufacturer:       string,
    product:            string,
    device_name:        string,
}

SerialPort :: struct {
    port_name:  string,
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

when false {
    if ctx_.ctx == nil {
        usb.init_context(&ctx_.ctx, nil, 0)
    }

    ctx_.num_devices = usb.get_device_list(ctx_.ctx, &ctx_.devices)

    for dev in ctx_.devices[:ctx_.num_devices] {
        log.debugf("Address: %v, Bus number: %v, Port number: %v", usb.get_device_address(dev), usb.get_bus_number(dev), usb.get_port_number(dev))
    }
}
    // reset ports
    ports = {}

    num_ports := get_serial_ports_internal(ports[:])

    return ports[:num_ports]
}

get_device_info :: proc(port: string) -> (info: DeviceInfo)
{
    

    return
}
