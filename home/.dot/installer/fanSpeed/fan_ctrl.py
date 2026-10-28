#!/usr/bin/env python3
"""PWM control of a GPIO fan by CPU temperature, for Raspberry Pi 3, 4 and 5.

Uses gpiozero (lgpio pin factory on current Raspberry Pi OS, works on the Pi 5 where RPi.GPIO does not).
Settings come from the environment (systemd reads /etc/default/fanctrl), see DEFAULTS.
  fan_ctrl.py          run the control loop
  fan_ctrl.py --test   check the speed calculation, needs no GPIO
Kernel alternative without this service: dtoverlay=gpio-fan,gpiopin=21,temp=55000 in config.txt
(on/off only, no PWM steps).
"""
import os
import sys
import time

DEFAULTS = {
    "FAN_PIN": "21",           # BCM pin that drives the transistor's base
    "FAN_FREQ": "25",          # [Hz] PWM frequency, change it if the fan behaves strangely
    "FAN_MIN": "20",           # [%] minimum speed, lower values (except 0) are not applied
    "FAN_TEMPS": "50 58 70",   # [°C] temperature steps
    "FAN_SPEEDS": "20 25 70",  # [%] fan speed for each temperature step
    "FAN_HYST": "1",           # [°C] speed changes only when the temperature moved more than this
    "FAN_INTERVAL": "1",       # [s] time between two checks
    "FAN_VALUE_FILE": "/tmp/fanSpeed.value",  # current speed for other tools (raspi_info.sh)
}
CONF_FILE = "/etc/default/fanctrl"
TEMP_FILE = "/sys/class/thermal/thermal_zone0/temp"


# Returns the settings: DEFAULTS, overridden by /etc/default/fanctrl, overridden by the environment.
def settings():
    conf = dict(DEFAULTS)
    try:
        with open(CONF_FILE) as f:
            for line in f:
                key, sep, value = line.strip().partition("=")
                if sep and not key.startswith("#"):
                    conf[key.strip()] = value.strip().strip('"\'')
    except OSError:
        pass
    conf.update({k: v for k, v in os.environ.items() if k in DEFAULTS})
    return conf


# Returns the fan speed in % for a temperature: lowest step below the first temperature, highest step from the
# last one on, linear interpolation in between.
def speed_for(temp, temps, speeds):
    if temp < temps[0]:
        return speeds[0]
    if temp >= temps[-1]:
        return speeds[-1]
    for i in range(len(temps) - 1):
        if temps[i] <= temp < temps[i + 1]:
            return round((speeds[i + 1] - speeds[i]) / (temps[i + 1] - temps[i]) * (temp - temps[i]) + speeds[i], 1)


# Reads the CPU temperature in °C.
def cpu_temp():
    with open(TEMP_FILE) as f:
        return float(f.read()) / 1000


# Opens the fan as a gpiozero PWM output from the settings.
def open_fan(conf):
    from gpiozero import PWMOutputDevice
    return PWMOutputDevice(int(conf["FAN_PIN"]), frequency=float(conf["FAN_FREQ"]))


# Runs the control loop until it is stopped.
def main():
    conf = settings()
    temps = [float(t) for t in conf["FAN_TEMPS"].split()]
    speeds = [float(s) for s in conf["FAN_SPEEDS"].split()]
    if len(temps) != len(speeds) or not temps:
        sys.exit("FAN_TEMPS and FAN_SPEEDS need the same number of values")
    fan_min, hyst, interval = float(conf["FAN_MIN"]), float(conf["FAN_HYST"]), float(conf["FAN_INTERVAL"])
    fan = open_fan(conf)
    speed = old_speed = old_temp = 0
    try:
        while True:
            temp = cpu_temp()
            if abs(temp - old_temp) > hyst:
                speed = speed_for(temp, temps, speeds)
                if speed != old_speed and (speed >= fan_min or speed == 0):
                    fan.value = speed / 100
                    old_speed = speed
                old_temp = temp
            with open(conf["FAN_VALUE_FILE"], "w") as f:
                f.write("%d" % old_speed)
            time.sleep(interval)
    except KeyboardInterrupt:
        pass
    finally:
        fan.close()


# Checks speed_for with the default steps.
def test():
    t, s = [50, 58, 70], [20, 25, 70]
    assert speed_for(30, t, s) == 20
    assert speed_for(50, t, s) == 20
    assert speed_for(54, t, s) == 22.5
    assert speed_for(64, t, s) == 47.5
    assert speed_for(70, t, s) == 70
    assert speed_for(90, t, s) == 70
    assert settings()["FAN_PIN"]
    print("fan_ctrl self-test ok")


if __name__ == "__main__":
    test() if sys.argv[1:] == ["--test"] else main()
