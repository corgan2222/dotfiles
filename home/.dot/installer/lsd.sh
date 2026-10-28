#!/bin/bash
# installer: lsd, ls with colors, icons and a tree view
# systems: all
# Installs lsd from the package manager when this system has a package of version 1.0 or newer (Ubuntu 24.04,
# Debian 13, Fedora, Rocky with EPEL, Arch, Alpine), else the latest static (musl) release binary from GitHub into
# ~/.local/bin (sha256 checked). Debian 12 ships 0.23.1 from 2022 and gets the release. ls itself stays as it is.
# Safe to run again: the package stays, the binary is replaced by the latest one.
#   lsd.sh
# category: base
# check: lsd
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

pkg=lsd
if [ "$DOT_PKG" = apt ]; then
  dot_apt_update
  # only a version: "(none)" would pass dpkg --compare-versions
  v=$(LC_ALL=C apt-cache policy lsd 2>/dev/null | sed -n 's/^ *Candidate: \([0-9]\)/\1/p')
  dpkg --compare-versions "$v" ge 1.0 || pkg=
fi
dot_epel
if [ "$DOT_PKG" != none ] && [ -n "$pkg" ] && dot_pkg_install lsd; then
  lsd --version
  exit 0
fi

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-musl ;;
  armv7|armv6) triple=arm-unknown-linux-gnueabihf ;;
  *) dot_die "lsd has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no lsd package of version 1.0 or newer on $DOT_OS, installing the latest release binary ($triple)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch lsd-rs/lsd "-$triple\.tar\.gz$" "$tmp/lsd.tar.gz" || dot_die "could not download lsd"
tar -xzf "$tmp/lsd.tar.gz" -C "$tmp" && install -D -m 755 "$tmp"/lsd-*/lsd ~/.local/bin/lsd ||
  dot_die "could not unpack lsd into ~/.local/bin"
~/.local/bin/lsd --version
