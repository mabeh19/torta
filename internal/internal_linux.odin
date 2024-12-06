package internal

import "core:log"
import "core:os"
import "core:strings"

get_serial_ports :: proc() -> []string 
{
    @static ports := [256]string{}

    portsFound := 0
    if dir, err := os.open("/dev/"); dir > -1 {
        if fi, rd_err := os.read_dir(dir, 1); err == .NONE {
            for f in fi {
                if  strings.starts_with(f.name, "ttyUSB") ||
                    strings.starts_with(f.name, "ttyACM") {
                    log.debug("Adding ", f.fullpath)
                    ports[portsFound] = f.fullpath
                    portsFound += 1
                }
            }
        }
    }

    return ports[:portsFound]
}
