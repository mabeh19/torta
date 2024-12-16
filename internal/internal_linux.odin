package internal

import "core:log"
import "core:os"
import "core:strings"

import "libusb"

get_serial_ports_internal :: proc(ports: []SerialPort) -> int
{
    numPorts := 0

    if dir, err := os.open("/dev/"); dir > -1 {
        if fi, rd_err := os.read_dir(dir, 1); err == .NONE {
            for f in fi {
                if  strings.starts_with(f.name, "ttyUSB") ||
                    strings.starts_with(f.name, "ttyACM") {

                    log.debug("Adding ", f.fullpath)
                    ports[numPorts] = SerialPort {
                        port_name = f.fullpath,
                        info = get_device_info(f.fullpath),
                    }
                    numPorts += 1

                    if numPorts == len(ports) {
                        break
                    }
                }
            }
        }
    }

    return numPorts
}
