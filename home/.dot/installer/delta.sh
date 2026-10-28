#!/bin/bash
# installer: delta, syntax-highlighting pager for git diff
# systems: all
# Installs delta from the package manager when this system has a package of version 0.17 or newer (git-delta on
# Debian 13, Fedora, Rocky with EPEL, Arch; delta on Alpine), else the latest release binary from GitHub into
# ~/.local/bin (sha256 checked). Ubuntu 24.04 ships 0.16.5 from 2023 and gets the release, Ubuntu 22.04 and Debian 12
# have none. Debian's package "delta" is another program. ~/.gitconfig is not touched: the end shows how to make
# delta the git pager. Safe to run again: the package stays, the binary is replaced by the latest one.
#   delta.sh
# category: base
# check: delta
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

hint() {
  dot_info "delta as the pager of git (not set by this installer):"
  echo "  git config --global core.pager delta"
  echo "  git config --global interactive.diffFilter 'delta --color-only'"
  echo "  git config --global delta.navigate true"
  echo "  git config --global merge.conflictStyle zdiff3"
}

case $DOT_PKG in
  apt|dnf|yum|pacman) pkg=git-delta ;;
  apk) pkg=delta ;;
  *) pkg= ;;
esac
if [ "$DOT_PKG" = apt ]; then
  dot_apt_update
  # only a version: "(none)" would pass dpkg --compare-versions
  v=$(LC_ALL=C apt-cache policy git-delta 2>/dev/null | sed -n 's/^ *Candidate: \([0-9]\)/\1/p')
  dpkg --compare-versions "$v" ge 0.17 || pkg=
fi
dot_epel
if [ -n "$pkg" ] && dot_pkg_install "$pkg"; then
  delta --version
  hint
  exit 0
fi

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-gnu ;;
  armv7|armv6) triple=arm-unknown-linux-gnueabihf ;;
  *) dot_die "delta has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
esac
dot_info "no delta package of version 0.17 or newer on $DOT_OS, installing the latest release binary ($triple)"
dot_need curl tar

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch dandavison/delta "-$triple\.tar\.gz$" "$tmp/delta.tar.gz" || dot_die "could not download delta"
tar -xzf "$tmp/delta.tar.gz" -C "$tmp" && install -D -m 755 "$tmp"/delta-*/delta ~/.local/bin/delta ||
  dot_die "could not unpack delta into ~/.local/bin"
~/.local/bin/delta --version
hint
