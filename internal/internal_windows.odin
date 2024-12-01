package internal

import "core:log"
import "core:sys/windows"
import "core:fmt"

foreign import sl "../serial/serial_windows_backend.lib"

foreign sl {
	GetPorts :: proc(lpPortNumbers: windows.PULONG, uPortNumbersCount: windows.ULONG, puPortNumbersFound: windows.PULONG) -> windows.ULONG ---
}

get_serial_ports :: proc() -> []string
{
    portNums := [100]u32{}
    portsFound : u32 = 0

    GetPorts(&portNums[0], 100, &portsFound)

    @static ports := [100]string{}
    ports = {}
    for i in 0..<portsFound {
        log.debugf("Adding port: COM%v", portNums[i])
        ports[i] = fmt.aprintf("COM%v", portNums[i])
    }

    return ports[:]
}
