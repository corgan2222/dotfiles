#!/bin/bash

sudo cp /home/pi/.dot/installer/fanSpeed/calib_fan.py /usr/bin/
sudo cp /home/pi/.dot/installer/fanSpeed/fan_ctrl.py /usr/bin/
sudo cp /home/pi/.dot/installer/fanSpeed/fanctrl.service /lib/systemd/system/
sudo systemctl enable fanctrl.service
sudo service fanctrl start
