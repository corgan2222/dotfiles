#!/bin/bash
# installer: Go, latest stable release from go.dev
# systems: all
# Installs the latest stable Go from go.dev into /usr/local/go, replacing an older one there.
# Does nothing when that version is already installed. ~/.dot/.exports puts /usr/local/go/bin into PATH.
#   go.sh
# category: dev
# check: /usr/local/go/bin/go
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_ARCH in
  amd64|arm64) arch=$DOT_ARCH ;;
  armv7|armv6) arch=armv6l ;;
  *) dot_die "Go has no build for architecture $DOT_ARCH" ;;
esac
dot_need curl tar

# prints "<filename> <sha256>" of the Linux tarball for $arch of the newest stable release;
# the go.dev list starts with the newest release, sha256 follows filename in every file entry
go_latest() {
  curl -fsSL 'https://go.dev/dl/?mode=json' | awk -v want=".linux-$arch.tar.gz" '
    /"filename":/ { f = $2; gsub(/[",]/, "", f) }
    /"sha256":/ && !done && substr(f, length(f) - length(want) + 1) == want { s = $2; gsub(/[",]/, "", s); print f, s; done = 1 }'
}

read -r file sum < <(go_latest)
[ -n "$sum" ] || dot_die "cannot read the Go release list from go.dev (no network?)"
ver=${file%.linux-*}
if [ "$(head -n 1 /usr/local/go/VERSION 2>/dev/null)" = "$ver" ]; then
  dot_info "$ver is already installed"
  /usr/local/go/bin/go version
  exit 0
fi

tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_info "Downloading $file"
curl -fsSL -o "$tmp/$file" "https://go.dev/dl/$file" || dot_die "download of $file failed"
echo "$sum  $tmp/$file" | sha256sum -c --quiet || dot_die "checksum of $file does not match, aborting"
# the Go docs: never unpack over an old tree, stale files break the toolchain
dot_sudo rm -rf /usr/local/go && dot_sudo tar -C /usr/local -xzf "$tmp/$file" || dot_die "could not unpack $file into /usr/local/go"
/usr/local/go/bin/go version
