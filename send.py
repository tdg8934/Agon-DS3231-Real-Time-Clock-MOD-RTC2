## Title:       send.py
## Author:      Jeroen Venema
## Created:     25/10/2022
## Last update: 25/10/2022

## Modinfo:
## 25/10/2022 initial version
## 03/8/2023 Added delay into send routine - Richard Turnnidge

import sys
import serial
import time
import os.path

## syntax
## send.py FILENAME <PORT> <BAUDRATE>
## 

if len(sys.argv) == 1 or len(sys.argv) >4:
  sys.exit('Usage: send.py FILENAME <PORT> <BAUDRATE>')

if not os.path.isfile(sys.argv[1]):
  sys.exit(f'Error: file \'{sys.argv[1]}\' not found')

if len(sys.argv) == 2:
  serialport = 'COM11'

if len(sys.argv) >= 3:
  serialport = sys.argv[2]

if len(sys.argv) == 4:
  baudrate = int(sys.argv[3])
else:
  baudrate = 115200   

print(f'Sending {sys.argv[1]}')
print(f'Using port {serialport}')
print(f'Baudrate {baudrate}')

f = open(sys.argv[1], "r")

content = f.readlines()
numLines = len(content)
print("num lines: " + str(numLines))

try:
  with serial.Serial(serialport, baudrate,rtscts=False,dsrdtr=False) as ser:
    ##ser.setDTR(None)
    print('Opening serial port')
    time.sleep(1)
    print('Writing textfile to serial port:')
    c=0
    for line in content:
        ser.write(str(line).encode('ascii'))
        time.sleep(0.008)
        c=c+1
        p=int(c/numLines*100)
        #print(chr(13) + ' Sent ' + str(p) + '%', flush="True", end ="")
    f.close()
    c=c-1
    print('\n Total ' + str(c) + ' records')
except serial.SerialException:
  print('Error: serial port unavailable')





