package internal

import "core:log"
import "core:os"
import "core:strings"

import "libusb"

get_serial_ports :: proc() -> []string 
{
    NUM_PORTS_SUPPORTED :: 1024
    @static ports := [NUM_PORTS_SUPPORTED]string{}
    numPorts := 0
    if dir, err := os.open("/dev/"); dir > -1 {
        if fi, rd_err := os.read_dir(dir, 1); err == .NONE {
            for f in fi {
                if  strings.starts_with(f.name, "ttyUSB") ||
                    strings.starts_with(f.name, "ttyACM") {

                    log.debug("Adding ", f.fullpath)
                    ports[numPorts] = f.fullpath
                    numPorts += 1

                    if numPorts == NUM_PORTS_SUPPORTED {
                        break
                    }
                }
            }
        }
    }

    return ports[:numPorts]
}
