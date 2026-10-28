#!/bin/bash
# installer: wg-easy, WireGuard VPN server with a web UI for the clients
# systems: amd64
# modes: compose portainer
# category: network
# ports: WG_PORT=51820/udp WG_EASY_PORT=51821
# check: stack:wg_easy
# ask: WG_HOST "Public host name or IP the VPN clients connect to, e.g. vpn.example.org or 192.0.2.10"
# Runs wg-easy 15 (github.com/wg-easy/wg-easy, AGPL-3.0) as compose project or Portainer stack "wg_easy" from
# /opt/wg_easy (default: compose, --portainer for a stack), configuration and clients in the volume wg_easy_etc.
# The first start skips the setup wizard (wg-easy's INIT_* variables): admin user, random password, host and port.
#   WG_HOST=vpn.example.org wg_easy.sh   host name or IP in the client configs (default: this host's first IP)
#   WG_PORT=51820                        WireGuard UDP port, the same outside and inside (first run)
#   WG_EASY_PORT=51821                   HTTP port of the web UI (first run)
#   WG_EASY_PASSWORD=…                   admin password (at least 12 characters), else generated
#   WG_EASY_IPV6=0                       no IPv6 in the tunnel (first run), for kernels without ip6tables NAT
#   --public / --local                   web UI on all interfaces or this host only (first run; else asked)
# The web UI runs over plain HTTP (INSECURE=true): keep it in the local network or put a reverse proxy with TLS in
# front. Needs the WireGuard kernel module (Linux 5.6+; in an LXC container the host loads it) and the capabilities
# NET_ADMIN and SYS_MODULE. Login and host in /opt/wg_easy/.env (0600); wg-easy reads them on its first start only,
# later changes go through the web UI. Running again pulls the newest 15.x image.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose
dot_bind 0.0.0.0

dest=/opt/wg_easy
web=${WG_EASY_PORT:-51821}
wgport=${WG_PORT:-51820}
host=${WG_HOST:-$(hostname -I 2>/dev/null | awk '{print $1}')}
pw=${WG_EASY_PASSWORD:-$(dot_password 20)}
[ -n "$host" ] || dot_die "set WG_HOST to the host name or IP the clients connect to"
dot_secret_ok "$host" || dot_die "WG_HOST must not contain spaces, quotes, \$ or backslashes"
dot_secret_ok "$pw" && [ ${#pw} -ge 12 ] || dot_die "WG_EASY_PASSWORD needs at least 12 characters, no spaces, quotes, \$ or backslashes"

# the container needs the kernel's WireGuard: a test interface shows whether it is there (built in or as module)
if command -v ip >/dev/null 2>&1 && ! dot_sudo ip link add dot-wgtest type wireguard 2>/dev/null; then
  dot_sudo modprobe wireguard 2>/dev/null
  dot_sudo ip link add dot-wgtest type wireguard 2>/dev/null ||
    dot_die "the kernel has no WireGuard: Linux 5.6 or newer is needed; in an LXC container load it on the host (modprobe wireguard)"
fi
dot_sudo ip link del dot-wgtest 2>/dev/null

dot_deploy wg_easy "services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    restart: unless-stopped
    environment:
      INSECURE: \"true\"
      DISABLE_IPV6: \${DISABLE_IPV6:-false}
      INIT_ENABLED: \"true\"
      INIT_USERNAME: \${INIT_USERNAME}
      INIT_PASSWORD: \${INIT_PASSWORD}
      INIT_HOST: \${INIT_HOST}
      INIT_PORT: \${INIT_PORT}
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - etc:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - \"$wgport:$wgport/udp\"
      - \"$DOT_BIND:$web:51821/tcp\"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
networks:
  wg:
    driver: bridge
    enable_ipv6: true
    ipam:
      driver: default
      config:
        - subnet: 10.42.42.0/24
        - subnet: fdcc:ad94:bacf:61a3::/64
volumes:
  etc:" "INIT_USERNAME=admin
INIT_PASSWORD=$pw
INIT_HOST=$host
INIT_PORT=$wgport
DISABLE_IPV6=$([ "${WG_EASY_IPV6:-1}" = 0 ] && echo true || echo false)"

# ports as written on the first run
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):51821\/tcp"$/\1/p' "$dest/compose.yaml")
web=${pub##*:} bound=${pub%:*}
[ "$bound" != "$pub" ] || bound=0.0.0.0
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: the web UI keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
# the web UI answers before the tunnel is up; a failing "wg-quick up" restarts the container
# and wg0 exists for a moment while its PostUp rules fail, so it has to be there twice, 5 s apart
wg_up() { dot_sudo docker exec wg-easy wg show wg0 >/dev/null 2>&1; }
for _ in $(seq 60); do wg_up && break; sleep 1; done
sleep 5
wg_up || dot_die "WireGuard does not come up in wg-easy, see: sudo docker logs wg-easy
       (\"ip6tables … Table does not exist\": the kernel has no IPv6 NAT; remove the stack wg_easy with its volume
       and $dest, then run again with WG_EASY_IPV6=0)"
here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=127.0.0.1
dot_wait_http "http://$here:$web/" 60 '2..|3..' || dot_die "the wg-easy web UI does not answer on port $web, see: sudo docker logs wg-easy"
dot_summary wg_easy "http://localhost:$web" \
  "user $(dot_sudo sed -n 's/^INIT_USERNAME=//p' "$dest/.env"), password: INIT_PASSWORD in $dest/.env; clients: add them in the web UI (QR code or .conf)"
