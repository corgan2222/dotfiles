#!/bin/bash
# installer: WireGuard tools (wg, wg-quick) with an example config wg0
# systems: debian arch fedora rhel alpine
# modes: native
# category: network
# ports: WIREGUARD_PORT=51820/udp
# check: wg
# Installs wireguard-tools from the distro; the kernel brings WireGuard itself since Linux 5.6 (in an LXC container
# the module comes from the host). Writes /etc/wireguard/wg0.conf (0600) with a new private key and placeholders for
# the peer, only when no wg0.conf exists. Brings no tunnel up and enables no service.
#   wireguard.sh              install, example config
#   WG_CONFIG=0 wireguard.sh  install only, no key and no config
#   WG_LISTEN=1 wireguard.sh  also open the port in firewalld or ufw, for a host that peers connect to
#   WIREGUARD_PORT=51820      UDP port of wg0 (ListenPort, written on the first run only)
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

conf=/etc/wireguard/wg0.conf
port=${WIREGUARD_PORT:-51820}
case $port in ''|*[!0-9]*) dot_die "WIREGUARD_PORT must be a number, got '$port'" ;; esac
case $DOT_PKG in
  # Debian recommends wireguard-dkms where no kernel package is installed (containers): not needed since Linux 5.6
  apt) dot_pkg_install --no-install-recommends wireguard-tools ;;
  dnf|yum|pacman|apk) dot_pkg_install wireguard-tools ;;
  *) dot_die "no WireGuard package for $DOT_OS, see https://www.wireguard.com/install/" ;;
esac || dot_die "installing wireguard-tools failed"
wg --version

if [ "${WG_CONFIG:-1}" != 0 ]; then
  dot_sudo install -d -m 0700 /etc/wireguard
  if dot_sudo test -e "$conf"; then
    dot_info "keeping $conf"
  else
    # addresses from the documentation ranges (RFC 5737): 198.51.100.0/24 inside the tunnel, where a real tunnel takes
    # a private range, and 192.0.2.1 as the peer's endpoint
    printf '%s\n' "# written by wireguard.sh: replace the <placeholders> and example addresses, then: sudo wg-quick up wg0" \
      "[Interface]" "PrivateKey = $(wg genkey)" "Address = 198.51.100.2/24" "ListenPort = $port" "" \
      "[Peer]" "PublicKey = <public key of the peer>" "Endpoint = 192.0.2.1:51820" "AllowedIPs = 198.51.100.0/24" \
      "PersistentKeepalive = 25" | dot_sudo sh -c "umask 077; cat > '$conf'" || dot_die "could not write $conf"
    dot_info "wrote $conf with a new private key"
  fi
fi

# the port of an existing wg0.conf
p=$(dot_sudo sed -n 's/^ListenPort *= *\([0-9]*\).*/\1/p' "$conf" 2>/dev/null)
[ "${WG_LISTEN:-}" = 1 ] && dot_firewall_open "${p:-$port}/udp"
pub=$(dot_sudo sed -n 's/^PrivateKey *= *//p' "$conf" 2>/dev/null | wg pubkey 2>/dev/null)
if [ -n "$pub" ]; then
  login="public key of this host: $pub (give it to the peer); private key in $conf (0600)
           start: sudo wg-quick up wg0   at boot: sudo systemctl enable --now wg-quick@wg0   status: sudo wg show"
else
  login="no key and no $conf yet: run wireguard.sh without WG_CONFIG=0 for an example config with a new key"
fi
# a parent installer (dot_deploy) may have exported its mode and address: WireGuard has neither
DOT_MODE=native DOT_BIND='' dot_summary wireguard "" "$login" wg-quick@wg0
