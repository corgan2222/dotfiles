#!/bin/bash
# installer: Bluetooth tools (BlueZ) for the Raspberry Pi
# systems: raspi
# Installs BlueZ (bluetoothctl, btmgmt), the Pi Bluetooth firmware/setup where available and the Python BLE
# library bleak (python3-bleak) when the distribution has it; adds the calling user to the group bluetooth.
# category: raspberry
# check: bluetoothctl
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

user=$(dot_user)

# true when apt has an installable version of the package
available() { apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [0-9]'; }

[ "$DOT_PKG" = apt ] || dot_die "this installer needs apt"
dot_pkg_install bluez || dot_die "could not install bluez"
# pi-bluetooth: Raspberry Pi OS; bluez-firmware: Debian non-free-firmware
for p in pi-bluetooth bluez-firmware python3-bleak; do
  if available "$p"; then dot_pkg_install "$p" || dot_die "could not install $p"
  else dot_info "skipping $p: not available here"; fi
done
available python3-bleak || dot_info "for bleak without the apt package use a venv: python3 -m venv ~/venv-ble && ~/venv-ble/bin/pip install bleak"

[ "$user" = root ] || id -nG "$user" | grep -qw bluetooth || dot_sudo usermod -aG bluetooth "$user"
if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable --now bluetooth || dot_die "could not start bluetooth.service"
fi
bluetoothctl --version
