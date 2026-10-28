#!/bin/bash
# installer: gping, ping with a live graph
# systems: all
# Installs gping from the package manager when this system has a package, else the latest static (musl) release
# binary from GitHub into ~/.local/bin (sha256 checked). Safe to run again: the package stays, the binary is replaced
# by the latest one.
#   gping.sh
# category: base
# check: gping
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install gping; then
  gping --version
  exit 0
fi

case $DOT_ARCH in
  amd64) target=musl-x86_64 ;;
  arm64) target=musl-arm64 ;;
  armv7) target=musleabihf-armv7 ;;
  *) dot_die "gping has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no gping package on $DOT_OS, installing the latest release binary ($target)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch orf/gping "/gping-Linux-$target\.tar\.gz$" "$tmp/gping.tar.gz" || dot_die "could not download gping"
tar -xzf "$tmp/gping.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/gping" ~/.local/bin/gping ||
  dot_die "could not unpack gping into ~/.local/bin"
~/.local/bin/gping --version
