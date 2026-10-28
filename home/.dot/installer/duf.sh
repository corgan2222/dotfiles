#!/bin/bash
# installer: duf, disk usage overview
# systems: all
# Installs duf from the package manager when this system has a package (not on Ubuntu 20.04 and stable Alpine), else
# the latest static release binary from GitHub into ~/.local/bin (sha256 checked). Safe to run again: the package
# stays, the binary is replaced by the latest one.
#   duf.sh
# category: base
# check: duf
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install duf; then
  duf --version
  exit 0
fi

case $DOT_ARCH in
  amd64) target=x86_64 ;;
  arm64|armv7|armv6) target=$DOT_ARCH ;;
  *) dot_die "duf has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no duf package on $DOT_OS, installing the latest release binary (linux_$target)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch muesli/duf "_linux_$target\.tar\.gz$" "$tmp/duf.tar.gz" || dot_die "could not download duf"
tar -xzf "$tmp/duf.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/duf" ~/.local/bin/duf ||
  dot_die "could not unpack duf into ~/.local/bin"
~/.local/bin/duf --version
