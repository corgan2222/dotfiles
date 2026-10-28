#!/bin/bash
# installer: tldr, short man pages (tealdeer client)
# systems: all
# Installs tealdeer, a tldr client, from the package manager when this system has a recent one, else the latest
# static (musl) release binary from GitHub into ~/.local/bin (sha256 checked). Then downloads the pages into
# the user's cache. Safe to run again (refreshes the pages).
#   tldr.sh
# category: sysop
# check: tldr
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

# true unless apt offers only a tealdeer older than 1.7: those cannot read the current tldr pages archive
# (Debian 12 ships 1.5, Ubuntu 24.04 1.6); pacman and apk carry current versions
pkg_recent() {
  [ "$DOT_PKG" = apt ] || return 0
  local v
  v=$(LC_ALL=C apt-cache policy tealdeer 2>/dev/null | sed -n 's/^ *Candidate: //p')
  [ -n "$v" ] && [ "$v" != '(none)' ] && dpkg --compare-versions "$v" ge 1.7
}

if [ "$DOT_PKG" != none ] && pkg_recent && dot_pkg_install tealdeer; then
  :
else
  case $DOT_ARCH in
    amd64) asset=tealdeer-linux-x86_64-musl ;;
    arm64) asset=tealdeer-linux-aarch64-musl ;;
    armv7) asset=tealdeer-linux-armv7-musleabihf ;;
    armv6) asset=tealdeer-linux-arm-musleabihf ;;
    *) dot_die "tealdeer has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
  esac
  dot_info "no recent tealdeer package on $DOT_OS, installing the latest release binary ($asset)"
  dot_need curl
  # the latest/download URL needs no GitHub API call (rate limit)
  url="https://github.com/tealdeer-rs/tealdeer/releases/latest/download/$asset"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$asset" "$url" && curl -fsSL -o "$tmp/$asset.sha256" "$url.sha256" ||
    dot_die "download of $url failed"
  echo "$(cut -d' ' -f1 "$tmp/$asset.sha256")  $tmp/$asset" | sha256sum -c --quiet ||
    dot_die "checksum of $asset does not match, aborting"
  install -D -m 755 "$tmp/$asset" ~/.local/bin/tldr || dot_die "could not install tldr into ~/.local/bin"
fi
tldr --update || dot_die "tldr is installed, but downloading the pages failed (no network?)"
tldr --version
