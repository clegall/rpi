#!/usr/bin/env python

import max7219.led as led
import max7219.font as font
import sys
import time
import fileinput
import datetime

sys.path.insert(0, '..')
import connected

device = led.matrix(cascaded=8)
device.orientation(90)
device.brightness(3)

isConnected = False
last = ''
while True:
    t = datetime.datetime.now().strftime('%H:%M:%S')
    if t[-2:] == '00':
        isConnected = connected.test()
    t.replace(':', ';')
    if last == t:
        continue
    #print t
    device.show_message(t, delay=0)
    last = t
