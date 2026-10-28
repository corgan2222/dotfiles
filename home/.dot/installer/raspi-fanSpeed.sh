#!/bin/bash
# installer: PWM fan control service for a GPIO fan
# systems: raspi
# Installs fan_ctrl.py (gpiozero + lgpio, works on Pi 3, 4 and 5) and calib_fan.py into /usr/local/bin and
# enables fanctrl.service. Settings live in /etc/default/fanctrl, written on the first run only; values given
# as environment variables then replace the defaults, e.g.:
#   FAN_PIN=18 FAN_TEMPS="45 60 70" FAN_SPEEDS="25 50 100" raspi-fanSpeed.sh
# DOT_FORCE_RASPI=1 installs on a system that is not a Raspberry Pi (for tests).
# category: raspberry
# check: /usr/local/bin/fan_ctrl.py
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

src=$(dirname "$(readlink -f "$0")")/fanSpeed
conf=/etc/default/fanctrl

[ "$DOT_OS" = raspi ] || [ "${DOT_FORCE_RASPI:-}" = 1 ] || dot_die "this is not a Raspberry Pi (set DOT_FORCE_RASPI=1 to install anyway)"
[ -f "$src/fan_ctrl.py" ] || dot_die "missing $src/fan_ctrl.py"

dot_pkg_install python3 python3-gpiozero python3-lgpio || dot_die "could not install python3-gpiozero and python3-lgpio"
python3 -c 'import gpiozero, lgpio' || dot_die "gpiozero or lgpio cannot be imported"

dot_sudo install -m 0755 "$src/fan_ctrl.py" "$src/calib_fan.py" /usr/local/bin/ &&
  dot_sudo install -m 0644 "$src/fanctrl.service" /etc/systemd/system/ || dot_die "could not copy the files"
# older versions of this installer put the files into /usr/bin and /lib/systemd/system
dot_sudo rm -f /usr/bin/fan_ctrl.py /usr/bin/calib_fan.py /lib/systemd/system/fanctrl.service

if [ ! -f "$conf" ]; then
  dot_sudo tee "$conf" >/dev/null <<EOF
# Settings of fanctrl.service (fan_ctrl.py), restart it after a change: sudo systemctl restart fanctrl
FAN_PIN=${FAN_PIN:-21}
FAN_FREQ=${FAN_FREQ:-25}
FAN_MIN=${FAN_MIN:-20}
FAN_TEMPS="${FAN_TEMPS:-50 58 70}"
FAN_SPEEDS="${FAN_SPEEDS:-20 25 70}"
FAN_HYST=${FAN_HYST:-1}
FAN_INTERVAL=${FAN_INTERVAL:-1}
# GPIOZERO_PIN_FACTORY=lgpio
EOF
  dot_info "wrote $conf"
else
  dot_info "keeping $conf"
fi

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable fanctrl && dot_sudo systemctl restart fanctrl ||
    dot_die "could not start fanctrl.service, see: journalctl -u fanctrl"
  dot_info "fanctrl.service is running; to calibrate: sudo systemctl stop fanctrl && sudo calib_fan.py"
else
  dot_info "no systemd running: enable it later with: sudo systemctl enable --now fanctrl"
fi
