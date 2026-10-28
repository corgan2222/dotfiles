#!/bin/bash
# installer: btop resource monitor
# systems: all
# Installs btop from the package manager when this system has a package, else the latest static (musl) release
# binary from GitHub into ~/.local/bin (sha256 checked).
# Safe to run again: the package stays, the binary is replaced by the latest one.
#   btop.sh
# category: base
# check: btop
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install btop; then
  btop --version | head -n 1
  exit 0
fi

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-musl ;;
  armv7) triple=armv7-unknown-linux-musleabi ;;
  armv6) triple=arm-unknown-linux-musleabi ;;
  *) dot_die "btop has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no btop package on $DOT_OS, installing the latest release binary ($triple)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch aristocratos/btop "/btop-$triple\.tar\.gz$" "$tmp/btop.tar.gz" || dot_die "could not download btop"
# only the binary: btop has its default theme built in, the bundled themes are optional
tar -xzf "$tmp/btop.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/btop/bin/btop" ~/.local/bin/btop ||
  dot_die "could not unpack btop into ~/.local/bin"
~/.local/bin/btop --version | head -n 1
