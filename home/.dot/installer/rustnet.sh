#!/bin/bash
# installer: rustnet, live network connections per process in the terminal
# systems: amd64 arm64
# Installs rustnet from the package manager on Arch and Alpine (edge), elsewhere the latest static (musl) release
# binary from GitHub into /usr/local/bin (sha256 checked; root-owned, because it gets capabilities). Then grants the
# capabilities rustnet documents for capturing without root: cap_net_raw (packet capture, read-only, no promiscuous
# mode) plus cap_bpf and cap_perfmon (eBPF process attribution). Where that fails (old libcap, unprivileged
# container), rustnet still runs with sudo. Only root and the group rustnet may run the binary, the caller is added
# to the group. Safe to run again: the binary is replaced by the latest one. On Arch and Alpine an update of the
# package puts back its own owner, mode and capabilities: run rustnet.sh again after it.
#   rustnet.sh
# category: base
# check: rustnet
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# Sets the file capabilities on the rustnet binary; libcap before 2.43 (Ubuntu 20.04) does not know cap_bpf and
# cap_perfmon, then only cap_net_raw (process names then come from /proc instead of eBPF).
# The binary becomes root:rustnet 0750 first, so only members of the group rustnet capture (28.10.26: on a 0755
# binary every user of the host could read the traffic); chown and chgrp drop file capabilities, so they come before.
grant_caps() {
  local pkg caps user
  case $DOT_PKG in apt) pkg=libcap2-bin ;; pacman) pkg=libcap ;; apk) pkg=libcap-setcap ;; *) pkg= ;; esac
  [ -z "$pkg" ] || dot_pkg_install "$pkg" >/dev/null || dot_info "could not install $pkg (setcap)"
  getent group rustnet >/dev/null || dot_sudo groupadd -r rustnet 2>/dev/null || dot_sudo addgroup -S rustnet ||
    dot_die "could not create the group rustnet"
  dot_sudo chown root:rustnet "$1" && dot_sudo chmod 0750 "$1" || dot_die "could not restrict $1 to the group rustnet"
  user=$(dot_user)
  if [ "$user" != root ] && ! id -nG "$user" | grep -qw rustnet; then
    # usermod lives in /usr/sbin, outside a normal user's PATH on Debian; busybox has addgroup
    if dot_sudo usermod -aG rustnet "$user" 2>/dev/null || dot_sudo addgroup "$user" rustnet 2>/dev/null; then
      dot_info "added $user to the group rustnet: log out and in again to run rustnet without sudo"
    else
      echo "warning: could not add $user to the group rustnet" >&2
    fi
  fi
  # A container whose bounding set lacks a capability refuses to exec the binary (EPERM), as root too (checked
  # 28.10.26): run it as root to see that it still starts, the caller may not be in the group yet in this session
  for caps in 'cap_net_raw,cap_bpf,cap_perfmon+eip' 'cap_net_raw+eip'; do
    dot_sudo setcap "$caps" "$1" 2>/dev/null && dot_sudo "$1" --version >/dev/null 2>&1 &&
      { dot_sudo getcap "$1"; return 0; }
  done
  dot_sudo setcap -r "$1" 2>/dev/null
  dot_info "could not set capabilities on $1 (unprivileged container?), run it as: sudo rustnet"
}

bin=
case $DOT_PKG in
  pacman|apk) dot_pkg_install rustnet && bin=$(command -v rustnet) ;;
esac

if [ -z "$bin" ]; then
  case $DOT_ARCH in
    amd64) triple=x86_64-unknown-linux-musl ;;
    arm64) triple=aarch64-unknown-linux-musl ;;
    *) dot_die "rustnet has no package on $DOT_OS and no static release binary for architecture $DOT_ARCH" ;;
  esac
  dot_info "no rustnet package on $DOT_OS, installing the latest release binary ($triple)"
  dot_need curl tar
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_github_fetch domcyrus/rustnet "/rustnet-v[^/]*-$triple\.tar\.gz$" "$tmp/rustnet.tar.gz" ||
    dot_die "could not download rustnet"
  tar -xzf "$tmp/rustnet.tar.gz" -C "$tmp" && dot_sudo install -D -m 755 "$tmp"/rustnet-*/rustnet /usr/local/bin/rustnet ||
    dot_die "could not unpack rustnet into /usr/local/bin"
  bin=/usr/local/bin/rustnet
fi

grant_caps "$bin"
dot_sudo "$bin" --version
[ "$bin" = /usr/local/bin/rustnet ] ||
  dot_info "rustnet comes from the $DOT_PKG package: run rustnet.sh again after each update of it (group, capabilities)"
