#!/bin/bash
# installer: go2rtc camera streaming server
# systems: amd64 arm64 armv7 armv6
# Installs the latest go2rtc release binary from GitHub into ~/.local/bin (sha256 checked), replacing an older one.
# No service is set up: start it with "go2rtc" (config go2rtc.yaml in the current directory, web UI on port 1984).
#   go2rtc.sh
# category: server
# check: go2rtc
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_ARCH in
  amd64|arm64|armv6) asset=go2rtc_linux_$DOT_ARCH ;;
  armv7) asset=go2rtc_linux_arm ;;
  *) dot_die "go2rtc has no release binary for architecture $DOT_ARCH" ;;
esac
dot_need curl

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_info "Downloading $asset"
dot_github_fetch AlexxIT/go2rtc "/$asset$" "$tmp/go2rtc" || dot_die "could not download go2rtc"
install -D -m 755 "$tmp/go2rtc" ~/.local/bin/go2rtc || dot_die "could not install go2rtc into ~/.local/bin"
~/.local/bin/go2rtc -version
