#!/bin/bash
# installer: WiringPi GPIO library (WiringPi/WiringPi release)
# systems: raspi
# Installs the .deb of the latest WiringPi release for this architecture (arm64 or armhf), checksum-verified.
# DOT_FORCE_RASPI=1 installs on a system that is not a Raspberry Pi (for tests).
# category: raspberry
# check: gpio
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

[ "$DOT_OS" = raspi ] || [ "${DOT_FORCE_RASPI:-}" = 1 ] || dot_die "this is not a Raspberry Pi (set DOT_FORCE_RASPI=1 to install anyway)"
[ "$DOT_PKG" = apt ] || dot_die "WiringPi comes as .deb, this system has no apt"
arch=$(dpkg --print-architecture)
case $arch in arm64|armhf) ;; *) dot_die "WiringPi has no package for $arch" ;; esac
dot_need curl

url=$(dot_github_asset WiringPi/WiringPi "_${arch}\.deb$")
[ -n "$url" ] || dot_die "no WiringPi .deb for $arch in the latest release"
file=${url##*/}
version=$(echo "$file" | sed -n 's/^wiringpi_\(.*\)_.*\.deb$/\1/p')
if [ "$(dpkg-query -W -f '${Version}' wiringpi 2>/dev/null)" = "$version" ]; then
  dot_info "WiringPi $version is installed"
  exit 0
fi

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$file" "$url" && curl -fsSL -o "$tmp/sums" "${url%/*}/SHA256SUMS-$arch" ||
  dot_die "download of $url failed"
(cd "$tmp" && grep " \*\{0,1\}$file\$" sums | sha256sum -c --quiet) || dot_die "checksum of $file does not match, aborting"
chmod a+r "$tmp" "$tmp/$file"
# the armhf package needs libatomic1 but does not declare it
[ "$arch" = armhf ] && { dot_pkg_install libatomic1 || dot_die "could not install libatomic1"; }
dot_pkg_install "$tmp/$file" || dot_die "installing $file failed"
dot_info "installed WiringPi $(dpkg-query -W -f '${Version}' wiringpi)"
