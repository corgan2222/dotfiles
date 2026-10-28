#!/bin/bash
# installer: glow, renders Markdown in the terminal
# systems: all
# Installs glow from the package manager when this system has a package (Debian 13, Fedora, Arch; not Ubuntu up to
# 24.04, Debian 12, Rocky, Alpine), else the latest release binary from GitHub into ~/.local/bin (sha256 checked).
# Safe to run again: the package stays, the binary is replaced by the latest one.
#   glow.sh
# category: base
# check: glow
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install glow; then
  glow --version
  exit 0
fi

# static Go binaries; the arm build runs on armv6 and armv7
case $DOT_ARCH in
  amd64) target=x86_64 ;;
  arm64) target=arm64 ;;
  armv7|armv6) target=arm ;;
  *) dot_die "glow has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no glow package on $DOT_OS, installing the latest release binary (Linux_$target)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch charmbracelet/glow "_Linux_$target\.tar\.gz$" "$tmp/glow.tar.gz" || dot_die "could not download glow"
tar -xzf "$tmp/glow.tar.gz" -C "$tmp" && install -D -m 755 "$tmp"/glow_*/glow ~/.local/bin/glow ||
  dot_die "could not unpack glow into ~/.local/bin"
~/.local/bin/glow --version
