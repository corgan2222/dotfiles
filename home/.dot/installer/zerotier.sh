#!/bin/bash
# installer: ZeroTier One VPN client
# systems: debian arch fedora rhel
# Installs ZeroTier One from its official apt or rpm repository (Arch: distro package) and starts it where systemd runs.
# Joins a network only when one is given:
#   zerotier.sh                     install only
#   zerotier.sh <network id>        install and join
#   ZEROTIER_NETWORK=<id> zerotier.sh
# category: network
# check: zerotier-one.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

net=${1:-${ZEROTIER_NETWORK:-}}
[ -z "$net" ] || [[ $net =~ ^[0-9a-f]{16}$ ]] || dot_die "invalid network ID '$net', expected 16 hex digits"

case $DOT_PKG in
  apt)
    dot_need curl
    code=$DOT_OS_BASE_CODENAME
    # ZeroTier publishes one repo per codename; a release it does not know yet gets the newest one of its family
    if ! curl -fsS -o /dev/null "https://download.zerotier.com/debian/$code/dists/$code/Release" 2>/dev/null; then
      case " $DOT_OS $DOT_OS_LIKE " in *" ubuntu "*) code=noble ;; *) code=trixie ;; esac
      dot_info "ZeroTier has no repository for '$DOT_OS_BASE_CODENAME', using '$code'"
    fi
    dot_apt_repo zerotier https://download.zerotier.com/contact%40zerotier.com.gpg \
      "https://download.zerotier.com/debian/$code" "$code" main
    dot_pkg_install zerotier-one || dot_die "installing zerotier-one failed" ;;
  pacman) dot_pkg_install zerotier-one || dot_die "installing zerotier-one failed" ;;
  dnf|yum)
    # the repository ZeroTier's install.sh writes: redhat/fc/<release> on Fedora, redhat/el/<major> on the RHEL family
    if [ "$DOT_OS_BASE" = fedora ]; then
      repo=fc/$DOT_OS_VERSION
    else
      dot_need curl
      repo=el/${DOT_OS_VERSION%%.*}
      curl -fsS -o /dev/null "https://download.zerotier.com/redhat/$repo/repodata/repomd.xml" 2>/dev/null ||
        { dot_info "ZeroTier has no repository for $repo, using el/9"; repo=el/9; }
    fi
    dot_rpm_repo zerotier "https://download.zerotier.com/redhat/$repo" https://download.zerotier.com/contact%40zerotier.com.gpg
    dot_pkg_install zerotier-one || dot_die "installing zerotier-one failed" ;;
  *) dot_die "no ZeroTier package for $DOT_OS, see https://www.zerotier.com/download/" ;;
esac
dot_sudo zerotier-one -v
# direct peer-to-peer paths need the UDP port open, without it ZeroTier falls back to its relays
dot_firewall_open 9993/udp

if [ ! -d /run/systemd/system ]; then
  dot_info "no systemd running: start the daemon by hand (sudo zerotier-one -d), then join with: sudo zerotier-cli join <network id>"
  exit 0
fi
dot_sudo systemctl enable --now zerotier-one || dot_die "starting zerotier-one failed"
# the daemon needs a moment to create its identity
for _ in 1 2 3 4 5 6 7 8 9 10; do dot_sudo zerotier-cli info >/dev/null 2>&1 && break; sleep 1; done
dot_sudo zerotier-cli info
if [ -n "$net" ]; then
  dot_sudo zerotier-cli join "$net" || dot_die "joining network $net failed"
  dot_info "authorize this node in the network's controller, then check with: sudo zerotier-cli listnetworks"
else
  dot_info "join a network with: sudo zerotier-cli join <network id>  (or run zerotier.sh <network id>)"
fi
# node ID from "200 info <node id> <version> <status>", networks from "200 listnetworks <nwid> …"
node=$(dot_sudo zerotier-cli info | awk '{print $3}')
nets=$(dot_sudo zerotier-cli listnetworks | awk 'NR > 1 {print "network:" $3}')
dot_summary zerotier "node:$node $nets" \
  "none; authorize node $node in the network's controller, status: sudo zerotier-cli listnetworks" zerotier-one
