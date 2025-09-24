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
    char driver[266];
    char usb_model[256];
    char id[10];
};

int OpenPort(const char *port_name, struct settings *config, HANDLE* file) 
{
    HANDLE hSerial;
    DCB dcbSerialParams = {0};
    COMMTIMEOUTS timeouts = {0};
    char full_port_name[40] = {0};

    snprintf(full_port_name, sizeof full_port_name, "\\\\.\\%s", port_name);

    // Open the serial port
    hSerial = CreateFile(full_port_name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hSerial == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error opening serial port %s: %ld\n", full_port_name, GetLastError());
        return 0;
    }

    // Set the DCB (Device Control Block) structure
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
    if (!GetCommState(hSerial, &dcbSerialParams)) {
        fprintf(stderr, "Error getting current serial port state: %d\n", GetLastError());
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
            fprintf(stderr, "Invalid parity setting\n");
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
        fprintf(stderr, "Error setting serial port parameters: %d\n", GetLastError());
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
        fprintf(stderr, "Error setting timeouts: %d\n", GetLastError());
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

    // Get handle to the device information set for all present USB devices
    hDevInfo = SetupDiGetClassDevs(&GUID_DEVCLASS_USB, 0, 0, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (hDevInfo == INVALID_HANDLE_VALUE) {
        return 1;
    }

    // Enumerate through all devices in the set
    DeviceInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
    for (i = 0; SetupDiEnumDeviceInfo(hDevInfo, i, &DeviceInfoData); i++) {
        if (!SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData, SPDRP_FRIENDLYNAME, &DataT,
                                               (PBYTE)portName, sizeof(portName), NULL))
            continue;
        
        if (!strstr(portName, path))
            continue;

        // Get the device instance ID
        if (SetupDiGetDeviceInstanceIdA(hDevInfo, &DeviceInfoData, deviceInstanceID, sizeof(deviceInstanceID), &size)) {
            // Extract VID and PID
            char *vid = strstr(deviceInstanceID, "VID_");
            char *pid = strstr(deviceInstanceID, "PID_");

            if (vid && pid) {
                snprintf(info->id, sizeof info->id, "%s:%s", vid, pid);
            }
        }

        // Retrieve the device friendly name
        char friendlyName[MAX_PATH] = "Not Available\0";
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData, SPDRP_FRIENDLYNAME, &DataT,
                                              (PBYTE)friendlyName, sizeof(friendlyName), NULL);
        snprintf(info->product, sizeof info->product, "%s", friendlyName);

        // Retrieve Manufacturer Name
        char manufacturer[MAX_PATH] = "Not Available\0";
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData, SPDRP_MFG, &DataT,
                                              (PBYTE)manufacturer, sizeof(manufacturer), NULL);
        snprintf(info->manufacturer, sizeof info->manufacturer, "%s", manufacturer);

        // Retrieve Device Model
        char model[MAX_PATH] = "Not Available\0";
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData, SPDRP_DEVICEDESC, &DataT,
                                              (PBYTE)model, sizeof(model), NULL);
        snprintf(info->usb_model, sizeof info->usb_model, "%s", model);

        // Retrieve Driver Name
        char driver[MAX_PATH] = "Not Available\0";
        SetupDiGetDeviceRegistryPropertyA(hDevInfo, &DeviceInfoData, SPDRP_DRIVER, &DataT,
                                              (PBYTE)driver, sizeof(driver), NULL);
        snprintf(info->driver, sizeof info->driver, "%s", driver);
    }

    // Cleanup
    SetupDiDestroyDeviceInfoList(hDevInfo);

    return 0;
}

bool Poll(HANDLE handle) {
    COMSTAT comStat;
    DWORD errors;

    if (!ClearCommError(handle, &errors, &comStat)) {
        fprintf(stderr, "Error clearing comm error: %d\n", GetLastError());
        return false;
    }

    return comStat.cbInQue > 0;
}
