#include <errno.h>
#include <stdint.h>
#include <stdbool.h>
#include <fcntl.h> 
#include <termios.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define error_message(...) do { \
        FILE* log = fopen(".log", "a+"); \
        fprintf(log, __VA_ARGS__); \
        fclose(log);    \
    } while (0)

int set_interface_attribs (int fd, int speed, char parity, int stopbits, bool controlflow)
{
    struct termios tty = {};
    if (tcgetattr(fd, &tty) != 0)
    {
        error_message("error %d from tcgetattr", errno);
        return -1;
    }

    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
    // disable IGNBRK for mismatched speed tests; otherwise receive break
    // as \000 chars
    tty.c_iflag &= ~IGNBRK;         // disable break processing
    tty.c_lflag = 0;                // no signaling chars, no echo,
    // no canonical processing
    tty.c_oflag = 0;                // no remapping, no delays
    tty.c_cc[VMIN]  = 0;            // read doesn't block
    tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

    tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

    tty.c_cflag |= (CLOCAL | CREAD);// ignore modem controls,
    // enable reading
    tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
    switch (tolower(parity)) {
        case 'n': break;
        case 'o': tty.c_cflag |= PARENB | PARODD; break;
        case 'e': tty.c_cflag |= PARENB; break;
        default: break;
    }
    tty.c_cflag &= ~CSTOPB;

    if (stopbits == 2) tty.c_cflag |= CSTOPB;
    tty.c_cflag &= ~CRTSCTS;

    if (tcsetattr(fd, TCSANOW, &tty) != 0)
    {
        error_message("error %d from tcsetattr", errno);
        return -1;
    }
    return 0;
}

void set_blocking(int fd, int should_block)
{
    struct termios tty = {};
    if (tcgetattr(fd, &tty) != 0)
    {
        error_message("error %d from tggetattr", errno);
        return;
    }

    tty.c_cc[VMIN]  = should_block ? 1 : 0;
    tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

    if (tcsetattr(fd, TCSANOW, &tty) != 0)
        error_message ("error %d setting term attributes", errno);
}

speed_t baudrate_to_flag(int baudrate) {
    switch (baudrate) {
        case 0: return B0;
        case 50: return B50;
        case 75: return B75;
        case 110: return B110;
        case 134: return B134;
        case 150: return B150;
        case 200: return B200;
        case 300: return B300;
        case 600: return B600;
        case 1200: return B1200;
        case 1800: return B1800;
        case 2400: return B2400;
        case 4800: return B4800;
        case 9600: return B9600;
        case 19200: return B19200;
        case 38400: return B38400;
        case 57600: return B57600;
        case 115200: return B115200;
        case 230400: return B230400;
        case 460800: return B460800;
        case 500000: return B500000;
        case 576000: return B576000;
        case 921600: return B921600;
        case 1000000: return B1000000;
        case 1152000: return B1152000;
        case 1500000: return B1500000;
        case 2000000: return B2000000;
        case 2500000: return B2500000;
        case 3000000: return B3000000;
        case 3500000: return B3500000;
        case 4000000: return B4000000;
        default:
            error_message("Unsupported baud rate: %d\n", baudrate);
            return -1;
    }
}

struct PortSettings {
    uint32_t baudrate;
    char parity;
    uint8_t stopBits;
    bool blocking;
    bool controlflow;
};

int OpenPort(const char* portname, const struct PortSettings* settings, int* file)
{
    int fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0)
    {
        error_message ("error %d opening %s: %s", errno, portname, strerror (errno));
        return 0;
    }

    speed_t baudrate = baudrate_to_flag(settings->baudrate);

    if (baudrate < 0) return 0;

    set_interface_attribs(fd, baudrate, settings->parity, settings->stopBits, settings->controlflow);
    set_blocking(fd, settings->blocking);                // set no blocking

    *file = fd;

    return 1;
}

void ClosePort(int fd)
{
    close(fd);
}

