#!/usr/bin/python3
import smbus
import RPi.GPIO as GPIO
import os
import time
from threading import Thread
rev = GPIO.RPI_REVISION


rev = GPIO.RPI_REVISION
if rev == 2 or rev == 3:
        bus = smbus.SMBus(1)
else:
        bus = smbus.SMBus(0)
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
shutdown_pin=4
GPIO.setup(shutdown_pin, GPIO.IN,  pull_up_down=GPIO.PUD_DOWN)

if rev == 2 or rev == 3:
	bus = smbus.SMBus(1)
else:
	bus = smbus.SMBus(0)

address=0x1a

#fan = GPIO.

#try:
	#bus.write_byte(address,block)
	#speed = bus.read_byte(address)
print(bus.read_byte(address))
	
#except IOError:
#	temp=""
#time.sleep(30)

