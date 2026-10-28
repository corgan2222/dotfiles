#!/usr/bin/env python3
"""Sets the fan to speeds typed in by hand, to find FAN_MIN and the speed steps for fan_ctrl.py.
Stop fanctrl.service first (sudo systemctl stop fanctrl), then run: sudo calib_fan.py
"""
from fan_ctrl import open_fan, settings


# Reads speeds in % from the keyboard and applies them until Ctrl+C or end of input.
def main():
    fan = open_fan(settings())
    try:
        while True:
            fan.value = min(max(float(input("Fan speed [%]: ")), 0), 100) / 100
    except (KeyboardInterrupt, EOFError):
        print()
    finally:
        fan.close()


if __name__ == "__main__":
    main()
