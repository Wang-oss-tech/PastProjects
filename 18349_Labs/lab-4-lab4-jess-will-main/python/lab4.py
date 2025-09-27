"""
File: lab4.py

Brief: This Python script communicates with a device over a serial port to control a lock.
       It sends AT commands to perform operations like unlocking, locking, and setting a passcode.
       It also logs the activity to a file named locklog.txt.

Date: 2023-11-09

Author: William Wang (www2) and Jessica Chan (jchan4)
"""

from datetime import datetime
import serial
import time


def main():
    # Open serial port
    ser = serial.Serial('/dev/tty.usbmodem1103', 115200)

    ser.flushInput()
    ser.flushOutput()

    # Send some AT commands
    print(ser.readline())
    ser.write(b'+++')
    time.sleep(2)
    ser.write(b'AT+HELLO=349\r\n')
    time.sleep(2)
    ser.write(b'AT+PASSCODE=1234\r\n')
    time.sleep(2)
    ser.write(b'AT+RESUME\r\n')
    time.sleep(5)

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
    log.close()
    ser.close()


if __name__ == '__main__':
    main()
