#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

#pragma comment(lib, "OneCore.lib")

struct settings {
    uint32_t baudrate;
    char parity;         // 'N' for None, 'E' for Even, 'O' for Odd
    char stopBits;       // '1' for 1 stop bit, '2' for 2 stop bits
    bool blocking;       // true for blocking, false for non-blocking
    bool controlflow;    // true for RTS/CTS hardware control, false for no control
};


int OpenPort(const char *port_name, struct settings *config, HANDLE* file) 
{
    HANDLE hSerial;
    DCB dcbSerialParams = {0};
    COMMTIMEOUTS timeouts = {0};
    char fullPortName[40] = {};

    snprintf(fullPortName, sizeof fullPortName, "\\\\.\\%s", port_name);

    // Open the serial port
    hSerial = CreateFile(fullPortName, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (hSerial == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error opening serial port: %d\n", GetLastError());
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
