#!/bin/bash
# installer: lazygit, terminal UI for git
# systems: all
# Installs lazygit from the package manager when this system has a package (Debian 13, Arch, Alpine; not Ubuntu up to
# 24.04, Debian 12, Fedora, Rocky), else the latest release binary from GitHub into ~/.local/bin (sha256 checked).
# Safe to run again: the package stays, the binary is replaced by the latest one.
#   lazygit.sh
# category: base
# check: lazygit
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install lazygit; then
  lazygit --version
  exit 0
fi

# static Go binaries; armv6 runs on armv7 too
case $DOT_ARCH in
  amd64) target=x86_64 ;;
  arm64) target=arm64 ;;
  armv7|armv6) target=armv6 ;;
  *) dot_die "lazygit has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no lazygit package on $DOT_OS, installing the latest release binary (linux_$target)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
# older releases spell it Linux, newer ones linux
dot_github_fetch jesseduffield/lazygit "_[Ll]inux_$target\.tar\.gz$" "$tmp/lazygit.tar.gz" ||
  dot_die "could not download lazygit"
tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/lazygit" ~/.local/bin/lazygit ||
  dot_die "could not unpack lazygit into ~/.local/bin"
~/.local/bin/lazygit --version
