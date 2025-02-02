package internal

import "core:log"
import "core:os"
import "core:strings"
import "core:fmt"
import "core:sys/linux"
import "core:c/libc"

import udev "libudev"

get_serial_ports_internal :: proc(ports: []SerialPort) -> int
{
    numPorts := 0

    dir, err := os.open("/dev/"); 
    if dir < 0 {
        return 0
    }

    fi, rd_err := os.read_dir(dir, 1) 
    if err != .NONE {
        log.error("Error reading /dev/:", err)
        return 0
    }

    for f in fi {
        if !(strings.starts_with(f.name, "ttyUSB") ||
             strings.starts_with(f.name, "ttyACM")) {
            continue
        }

        log.debug("Adding ", f.fullpath)
        ports[numPorts] = SerialPort {
            port_name = f.fullpath,
            info = get_device_info(f.name),
        }
        numPorts += 1

        if numPorts == len(ports) {
            break
        }
    }

    return numPorts
}

get_device_info :: proc(port: string) -> (info: DeviceInfo)
{
    device_id_path := fmt.aprintf("/sys/class/tty/%v/dev", port)
    defer delete(device_id_path)

    if device_id, ok := os.read_entire_file(device_id_path); ok {
        trimmed_id := strings.trim(string(device_id), "\n")
        full_id := strings.Builder{}
        strings.builder_init(&full_id)
        defer strings.builder_destroy(&full_id)

        strings.write_byte(&full_id, 'c')           // char device
        strings.write_string(&full_id, trimmed_id)  // major:minor

        device_id := strings.unsafe_string_to_cstring(strings.to_string(full_id))
        log.debug("Device ID:", device_id)

        udv := udev.udev_new()
        defer udev.udev_unref(udv)

        dev := udev.udev_device_new_from_device_id(udv, device_id)
        defer udev.udev_device_unref(dev)

        if dev == nil {
            log.errorf("Error reading device for %v, err: %v", port, libc.strerror(libc.errno()^))
            return
        }

        manufacturer := udev.udev_device_get_property_value(dev, "ID_VENDOR_FROM_DATABASE")
        product := udev.udev_device_get_property_value(dev, "ID_MODEL_FROM_DATABASE")
        vid := udev.udev_device_get_property_value(dev, "ID_VENDOR_ID")
        pid := udev.udev_device_get_property_value(dev, "ID_MODEL_ID")
        driver := udev.udev_device_get_property_value(dev, "ID_USB_DRIVER")
        usb_model := udev.udev_device_get_property_value(dev, "ID_USB_MODEL")

        if manufacturer == nil {
            log.errorf("Error reading manufacturer for %v", port)
            return
        }
        if product == nil {
            log.errorf("Error reading product for %v", port)
            return
        }
        if vid == nil {
            log.errorf("Error reading vid for %v", port)
            return
        }
        if pid == nil {
            log.errorf("Error reading pid for %v", port)
            return
        }
        if driver == nil {
            log.errorf("Error reading driver for %v", port)
            return
        }
        if usb_model == nil {
            log.errorf("Error reading usb model for %v", port)
            return
        }

        fmt.bprintf(info.manufacturer[:], "%v", manufacturer)
        fmt.bprintf(info.product[:], "%v", product)
        fmt.bprintf(info.id[:], "%v:%v", vid, pid)
        fmt.bprintf(info.driver[:], "%v", driver)
        fmt.bprintf(info.usb_model[:], "%v", usb_model)
    }
    else {
        log.errorf("Error reading device ID for %v", port)
    }

    return info
}
