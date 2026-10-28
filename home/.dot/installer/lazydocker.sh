#!/bin/bash
# installer: lazydocker, terminal UI for Docker and compose
# systems: all
# Installs lazydocker from the package manager on Arch and Alpine, elsewhere (Debian, Ubuntu, Kali have no package)
# the latest static release binary from GitHub into ~/.local/bin (sha256 checked). Docker itself is not installed
# (docker.sh). Safe to run again: the package stays, the binary is replaced by the latest one.
#   lazydocker.sh
# category: base
# check: lazydocker
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

case $DOT_PKG in
  pacman|apk) dot_pkg_install lazydocker && { lazydocker --version | head -n 1; exit 0; } ;;
esac

case $DOT_ARCH in
  amd64) target=x86_64 ;;
  arm64|armv7|armv6) target=$DOT_ARCH ;;
  *) dot_die "lazydocker has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no lazydocker package on $DOT_OS, installing the latest release binary (Linux_$target)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch jesseduffield/lazydocker "_Linux_$target\.tar\.gz$" "$tmp/lazydocker.tar.gz" ||
  dot_die "could not download lazydocker"
tar -xzf "$tmp/lazydocker.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/lazydocker" ~/.local/bin/lazydocker ||
  dot_die "could not unpack lazydocker into ~/.local/bin"
~/.local/bin/lazydocker --version | head -n 1
