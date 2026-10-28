#!/bin/bash
# installer: Chromium browser
# systems: debian arch fedora rhel alpine desktop
# Debian, Kali, Raspberry Pi OS, Arch and Fedora ship Chromium as a normal package and get it from there, the RHEL
# family from EPEL.
# Ubuntu's chromium-browser .deb is only a stub that installs the snap. Options there:
#   snap     the official Ubuntu way, needs a running snapd (not in LXC/Docker containers)
#   flatpak  org.chromium.Chromium from Flathub, works without snapd
#   (Debian's package mixed into Ubuntu or third-party PPAs break on upgrades, so they are not offered)
# This installer takes the snap when snapd runs, else Flatpak. Force one with: chromium.sh snap|flatpak
# Safe to run again.
# category: desktop
# check: chromium|chromium-browser
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# installs Chromium from Flathub system-wide and links the command chromium to it
chromium_flatpak() {
  dot_need flatpak
  dot_sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
    dot_die "could not add the Flathub remote"
  dot_sudo flatpak install -y --noninteractive --system flathub org.chromium.Chromium ||
    dot_die "installing org.chromium.Chromium from Flathub failed"
  dot_sudo ln -sfn /var/lib/flatpak/exports/bin/org.chromium.Chromium /usr/local/bin/chromium
  dot_info "Chromium installed from Flathub, start it with: chromium"
  flatpak info --system org.chromium.Chromium | grep -E '^ *(Version|Branch):'
}

case ${1:-} in -h|--help) sed -n '4,10s/^# \{0,1\}//p' "$0"; exit 0 ;; esac

if [ "$DOT_OS_BASE" = ubuntu ]; then
  how=${1:-}
  if [ -z "$how" ]; then
    # "snap version" prints "snapd unavailable" when the daemon does not run
    if snap version 2>/dev/null | grep -q '^snapd *[0-9]'; then how=snap; else how=flatpak; fi
  fi
  case $how in
    snap) dot_sudo snap install chromium || dot_die "snap install chromium failed"; snap list chromium ;;
    flatpak) chromium_flatpak ;;
    *) dot_die "unknown option '$how', use snap or flatpak" ;;
  esac
  exit 0
fi

case $DOT_PKG in
  apt|pacman|apk) dot_pkg_install chromium || dot_die "installing chromium failed" ;;
  dnf|yum) dot_epel && dot_pkg_install chromium || dot_die "installing chromium failed" ;;
  *) dot_die "no Chromium installer for $DOT_OS" ;;
esac
chromium --version 2>/dev/null || chromium-browser --version 2>/dev/null || command -v chromium
