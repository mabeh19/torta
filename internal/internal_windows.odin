package internal

import "core:log"
import "core:sys/windows"
import "core:fmt"

foreign import sl "../serial/serial_windows_backend.lib"

foreign sl {
	GetPorts :: proc(lpPortNumbers: windows.PULONG, uPortNumbersCount: windows.ULONG, puPortNumbersFound: windows.PULONG) -> windows.ULONG ---
}

get_serial_ports_internal :: proc(ports: []SerialPort) -> int
{
    portNums := make([]u32, len(ports))
    defer delete(portNums)
    portsFound : u32 = 0

    GetPorts(&portNums[0], u32(len(ports)), &portsFound)

    for i in 0..<portsFound {
        fullPath := fmt.aprintf("COM%v", portNums[i])
        log.debugf("Adding port: COM%v", portNums[i])
        ports[i] = SerialPort {
            port_name = fullPath,
            info = get_device_info(fullPath),
        }
    }

    return int(portsFound)
}
