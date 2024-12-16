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

    GetPorts(&portNums[0], len(ports), &portsFound)

    for i in 0..<portsFound {
        log.debugf("Adding port: COM%v", portNums[i])
        ports[i] = fmt.aprintf("COM%v", portNums[i])
    }

    return portsFound
}
