#!/usr/bin/env python3

from datetime import datetime
import serial


def main():
    # Open serial port
    ser = serial.Serial('/dev/ttyACM0', 115200)

    # Send some AT commands
    ser.write(b'+++')
    ser.write(b'AT+HELLO=349\n')
    ser.write(b'AT+PASSCODE=1234\n')
    ser.write(b'AT+RESUME\n')

    # Log activity to a file
    log = open('./locklog.txt', 'w')
    while (True):
        line = ser.readline()
        print(line)
        timestr = datetime.now().strftime('%m/%d/%Y, %H:%M:%S')
        if line.startswith(b'Unlock'):
            log.write('Unlocked ' + timestr + '\n')
        elif line.startswith(b'Lock'):
            log.write('Locked ' + timestr + '\n')

    # Cleanup
    log.close()
    ser.close()


if __name__ == '__main__':
    main()
