#!/bin/bash
# installer: aichat, LLM chat on the command line
# systems: amd64 arm64 armv7 armv6
# Installs the latest static (musl) aichat release binary from GitHub into ~/.local/bin (sha256 checked).
# Does nothing when that version is installed already.
#   aichat.sh
# category: dev
# check: aichat
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-musl ;;
  armv7) triple=armv7-unknown-linux-musleabihf ;;
  armv6) triple=arm-unknown-linux-musleabihf ;;
  *) dot_die "aichat has no release binary for architecture $DOT_ARCH" ;;
esac
dot_need curl tar

tag=$(dot_github_latest sigoden/aichat)
[ -n "$tag" ] || dot_die "cannot read the latest aichat release from GitHub (no network?)"
if [ "$(~/.local/bin/aichat --version 2>/dev/null)" = "aichat ${tag#v}" ]; then
  dot_info "aichat ${tag#v} is already installed"
  exit 0
fi

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_info "Downloading aichat $tag ($triple)"
dot_github_fetch sigoden/aichat "/aichat-$tag-$triple\.tar\.gz$" "$tmp/aichat.tar.gz" "$tag" ||
  dot_die "could not download aichat"
tar -xzf "$tmp/aichat.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/aichat" ~/.local/bin/aichat ||
  dot_die "could not unpack aichat into ~/.local/bin"
~/.local/bin/aichat --version
