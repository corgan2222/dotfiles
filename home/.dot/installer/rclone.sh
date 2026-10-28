#!/bin/bash
# installer: rclone cloud sync (Google Drive, S3, OneDrive, ...)
# systems: all
# Installs the latest rclone from downloads.rclone.org into /usr/local/bin, checked against its SHA256SUMS
# (the Debian/Ubuntu packages lag far behind); Arch and Alpine get their current distribution package.
# Safe to run again: updates when a newer release exists. Set up a remote afterwards with: rclone config
# category: sysop
# check: rclone
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# prints how to connect Google Drive, the job the old googledrive.sh (grive) did
rclone_hint() {
  rclone version | head -n 1
  dot_info "Connect Google Drive: rclone config  ->  n (new remote), type drive; then e.g. rclone sync gdrive: ~/gdrive"
  echo "  Without a browser on this machine rclone prints a 'rclone authorize' command to run where one is."
}

case $DOT_OS in
  arch|alpine) dot_pkg_install rclone || dot_die "installing rclone failed"; rclone_hint; exit 0 ;;
esac

case $DOT_ARCH in
  amd64|arm64) a=$DOT_ARCH ;;
  armv7) a=arm-v7 ;;
  armv6) a=arm-v6 ;;
  *) dot_die "rclone has no Linux build for $DOT_ARCH" ;;
esac
dot_need curl unzip
ver=$(curl -fsSL https://downloads.rclone.org/version.txt | awk '{ print $2 }')
[[ $ver == v* ]] || dot_die "could not read the latest rclone version (no network?)"
if [ "$(rclone version 2>/dev/null | awk 'NR == 1 { print $2 }')" = "$ver" ]; then
  dot_info "rclone $ver is already installed"
  rclone_hint
  exit 0
fi

zip=rclone-$ver-linux-$a.zip
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_info "Downloading rclone $ver ($a)"
curl -fsSL -o "$tmp/$zip" "https://downloads.rclone.org/$ver/$zip" &&
  curl -fsSL -o "$tmp/SHA256SUMS" "https://downloads.rclone.org/$ver/SHA256SUMS" || dot_die "download of $zip failed"
(cd "$tmp" && grep " $zip\$" SHA256SUMS | sha256sum -c --quiet) || dot_die "checksum of $zip does not match, aborting"
unzip -q "$tmp/$zip" -d "$tmp" || dot_die "could not unpack $zip"
dot_sudo install -m 755 "$tmp/${zip%.zip}/rclone" /usr/local/bin/rclone &&
  dot_sudo install -D -m 644 "$tmp/${zip%.zip}/rclone.1" /usr/local/share/man/man1/rclone.1 ||
  dot_die "could not install rclone into /usr/local/bin"
hash -r
rclone_hint
