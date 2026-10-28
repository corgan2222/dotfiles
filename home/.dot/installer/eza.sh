#!/bin/bash
# installer: eza, modern ls replacement
# systems: all
# Installs eza from the package manager when this system has a package, else the latest release binary
# from GitHub into ~/.local/bin (sha256 checked).
# Safe to run again: the package stays, the binary is replaced by the latest one.
#   eza.sh
# category: base
# check: eza
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install eza; then
  eza --version | sed -n 2p
  exit 0
fi

# musl on amd64: static, runs on every libc; the arm builds exist only for glibc
case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-gnu ;;
  armv7|armv6) triple=arm-unknown-linux-gnueabihf ;;
  *) dot_die "eza has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no eza package on $DOT_OS, installing the latest release binary ($triple)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch eza-community/eza "/eza_$triple\.tar\.gz$" "$tmp/eza.tar.gz" || dot_die "could not download eza"
tar -xzf "$tmp/eza.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/eza" ~/.local/bin/eza ||
  dot_die "could not unpack eza into ~/.local/bin"
~/.local/bin/eza --version | sed -n 2p
