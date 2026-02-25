#include <windows.h>
#include <setupapi.h>
#include <devguid.h>
#include <regstr.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

#pragma comment(lib, "OneCore.lib")
#pragma comment(lib, "setupapi.lib")

struct settings {
    uint32_t baudrate;
    char parity;         // 'N' for None, 'E' for Even, 'O' for Odd
    char stopBits;       // '1' for 1 stop bit, '2' for 2 stop bits
    bool blocking;       // true for blocking, false for non-blocking
    bool controlflow;    // true for RTS/CTS hardware control, false for no control
};

struct DeviceInfo {
    char manufacturer[256];
    char product[256];
    char driver[256];
    char serialnum[256];
    char id[10];
    char revision[10];
};

int OpenPort(const char *port_name, struct settings *config, HANDLE* file, void (*log)(const char* fmt, ...)) 
{
    HANDLE hSerial;
    DCB dcbSerialParams = {0};
    COMMTIMEOUTS timeouts = {0};
    char full_port_name[40] = {0};

    snprintf(full_port_name, sizeof full_port_name, "\\\\.\\%s", port_name);

    // Open the serial port
    hSerial = CreateFile(full_port_name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hSerial == INVALID_HANDLE_VALUE) {
        log("Error opening serial port %s: %ld\n", full_port_name, GetLastError());
        return 0;
    }

    // Set the DCB (Device Control Block) structure
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
    if (!GetCommState(hSerial, &dcbSerialParams)) {
        log("Error getting current serial port state: %d\n", GetLastError());
        CloseHandle(hSerial);
        return 0;
    }

    // Configure baud rate
    dcbSerialParams.BaudRate = config->baudrate;

    // Configure parity
    switch (config->parity) {
        case 'n': dcbSerialParams.Parity = NOPARITY; break;
        case 'e': dcbSerialParams.Parity = EVENPARITY; break;
        case 'o': dcbSerialParams.Parity = ODDPARITY; break;
        default:
            log("Invalid parity setting\n");
            CloseHandle(hSerial);
            return 0;
    }

    // Configure stop bits
    dcbSerialParams.StopBits = (config->stopBits == 2) ? TWOSTOPBITS : ONESTOPBIT;

    // Configure byte size (assuming 8 bits here, adjust if needed)
    dcbSerialParams.ByteSize = 8;

    // Configure control flow
    if (config->controlflow) {
        dcbSerialParams.fRtsControl = RTS_CONTROL_HANDSHAKE;
    } else {
        dcbSerialParams.fRtsControl = RTS_CONTROL_DISABLE;
    }

    if (!SetCommState(hSerial, &dcbSerialParams)) {
        log("Error setting serial port parameters: %d\n", GetLastError());
        CloseHandle(hSerial);
        return 0;
    }

    // Set timeouts
    if (config->blocking) {
        timeouts.ReadIntervalTimeout = 0;
        timeouts.ReadTotalTimeoutConstant = 0;
        timeouts.ReadTotalTimeoutMultiplier = 0;
        timeouts.WriteTotalTimeoutConstant = 0;
        timeouts.WriteTotalTimeoutMultiplier = 0;
    } else {
        timeouts.ReadIntervalTimeout = 50;
        timeouts.ReadTotalTimeoutConstant = 50;
        timeouts.ReadTotalTimeoutMultiplier = 10;
        timeouts.WriteTotalTimeoutConstant = 50;
        timeouts.WriteTotalTimeoutMultiplier = 10;
    }

    if (!SetCommTimeouts(hSerial, &timeouts)) {
        log("Error setting timeouts: %d\n", GetLastError());
        CloseHandle(hSerial);
        return 0;
    }

    *file = hSerial;

    return 1;
}


ULONG GetPorts(PULONG lpPortNumbers, ULONG uPortNumbersCount, PULONG puPortNumbersFound)
{
    return GetCommPorts(lpPortNumbers, uPortNumbersCount, puPortNumbersFound);
}

void ClosePort(HANDLE handle)
{
    CloseHandle(handle);
}

LONG GetDeviceInfo(struct DeviceInfo *info, const char *path) {
    HDEVINFO hDevInfo;
    SP_DEVINFO_DATA DeviceInfoData;
    DWORD i, DataT;
    CHAR portName[MAX_PATH];
    CHAR deviceInstanceID[MAX_PATH];
    DWORD size = 0;

    // Get handle to the device information set for all present COM ports.
    // GUID_DEVINTERFACE_COMPORT targets serial/virtual COM devices; using the
    // USB class (GUID_DEVCLASS_USB) usually returns an empty set when scanning
    // for `COMx` ports, which is why enumeration always failed.
    hDevInfo = SetupDiGetClassDevs(&GUID_DEVINTERFACE_COMPORT,
                                   0,
                                   0,
                                   DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (hDevInfo == INVALID_HANDLE_VALUE) {
        return 1;
    }

    // Walk the set and look for the matching port name.
    DeviceInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
    for (i = 0; ; i++) {
        if (!SetupDiEnumDeviceInfo(hDevInfo, i, &DeviceInfoData)) {
            DWORD err = GetLastError();
            if (err == ERROR_NO_MORE_ITEMS) {
                break;  // reached end normally
            }
            SetupDiDestroyDeviceInfoList(hDevInfo);
            return 1;
        }

        if (!SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData,
                                               SPDRP_FRIENDLYNAME, &DataT,
                                               (PBYTE)portName, sizeof(portName), NULL)) {
            continue;
        }

        if (!strstr(portName, path))
            continue;

        // --- common information from the device instance ID ---
        if (SetupDiGetDeviceInstanceIdA(hDevInfo, &DeviceInfoData,
                                        deviceInstanceID, sizeof(deviceInstanceID), &size)) {
            // extract VID/PID for `info->id`
            char *vid = strstr(deviceInstanceID, "VID_");
            char *pid = strstr(deviceInstanceID, "PID_");
            if (vid && pid) {
                snprintf(info->id, sizeof info->id, "%.4s:%.4s", vid + 4, pid + 4);
            }

            // attempt to pull a serial number from the instance ID; this is
            // typically the substring after the second backslash
            char *s = strchr(deviceInstanceID, '\\');
            if (s) {
                s = strchr(s + 1, '\\');
                if (s) {
                    strncpy(info->serialnum, s + 1, sizeof info->serialnum - 1);
                    info->serialnum[sizeof info->serialnum - 1] = '\0';
                }
            }
        }

        // --- properties that correspond to udev attributes ---

        // manufacturer (ID_VENDOR)
        info->manufacturer[0] = '\0';
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData,
                                          SPDRP_MFG, &DataT,
                                          (PBYTE)info->manufacturer,
                                          sizeof(info->manufacturer), NULL);
        if (info->manufacturer[0] == '\0')
            strcpy(info->manufacturer, "Not Available");

        // product/model (ID_MODEL)
        info->product[0] = '\0';
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData,
                                          SPDRP_DEVICEDESC, &DataT,
                                          (PBYTE)info->product,
                                          sizeof(info->product), NULL);
        if (info->product[0] == '\0')
            strcpy(info->product, "Not Available");

        // driver (ID_USB_DRIVER)
        info->driver[0] = '\0';
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData,
                                          SPDRP_DRIVER, &DataT,
                                          (PBYTE)info->driver,
                                          sizeof(info->driver), NULL);
        if (info->driver[0] == '\0')
            strcpy(info->driver, "Not Available");

        // revision (ID_REVISION) -- try hardware ID string for REV_ token
        info->revision[0] = '\0';
        {
            CHAR hardwareId[MAX_PATH] = {0};
            if (SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData,
                                                  SPDRP_HARDWAREID, &DataT,
                                                  (PBYTE)hardwareId,
                                                  sizeof(hardwareId), NULL)) {
                char *rev = strstr(hardwareId, "REV_");
                if (rev) {
                    rev += 4;
                    char *end = rev;
                    while (*end && *end != '&' && *end != '\\') end++;
                    size_t len = end - rev;
                    if (len >= sizeof info->revision)
                        len = sizeof info->revision - 1;
                    memcpy(info->revision, rev, len);
                    info->revision[len] = '\0';
                }
            }
            if (info->revision[0] == '\0')
                strcpy(info->revision, "Unknown");
        }

        // We only need the first matching device
        break;
    }

    SetupDiDestroyDeviceInfoList(hDevInfo);
    return 0;
}

int Poll(HANDLE handle) {
    COMSTAT comStat;
    DWORD errors;

    if (!ClearCommError(handle, &errors, &comStat)) {
        return -1;
    }

    return comStat.cbInQue;
}
