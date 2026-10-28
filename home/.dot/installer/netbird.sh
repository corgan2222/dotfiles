#!/bin/bash
# installer: NetBird VPN client (WireGuard mesh, netbird.io or your own management server)
# systems: ubuntu debian amd64
# modes: native compose portainer
# category: network
# check: netbird
# NetBird client (github.com/netbirdio/netbird). Joins the network only with a setup key, else the summary shows how
# to log in with the browser:
#   native:    package netbird from NetBird's apt or rpm repository (pkgs.netbird.io, signed), service netbird
#   --docker / --portainer:   image netbirdio/netbird:latest as compose project or Portainer stack "netbird" from
#              /opt/netbird, host network, state in the volume netbird_state; needs NB_SETUP_KEY on the first run
#   NB_SETUP_KEY=…             setup key (dashboard: Setup Keys), stored root-only (native: only used, not kept;
#                              Docker: /opt/netbird/.env)
#   NB_MANAGEMENT_URL=https://netbird.example.org   own management server (default https://api.netbird.io)
# The peer's identity lives in /var/lib/netbird (native) or the volume. Running again updates the client.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

key=${NB_SETUP_KEY:-}
mgmt=${NB_MANAGEMENT_URL:-https://api.netbird.io}
dot_secret_ok "$key" || dot_die "NB_SETUP_KEY must not contain spaces, quotes, \$ or backslashes"
dot_secret_ok "$mgmt" || dot_die "NB_MANAGEMENT_URL must not contain spaces, quotes, \$ or backslashes"
dot_mode_guard netbird netbird

if [ "$DOT_MODE" != native ]; then
  dest=/opt/netbird
  dot_sudo install -d -m 0755 "$dest"
  if [ -n "$key" ]; then
    dot_env_set "$dest/.env" NB_SETUP_KEY "$key"
  elif ! dot_sudo grep -qs '^NB_SETUP_KEY=.' "$dest/.env"; then
    dot_die "NetBird in Docker needs a setup key: NB_SETUP_KEY=… netbird.sh --docker (dashboard: Setup Keys)"
  fi
  dot_sudo grep -qs '^NB_MANAGEMENT_URL=' "$dest/.env" && [ -z "${NB_MANAGEMENT_URL:-}" ] ||
    dot_env_set "$dest/.env" NB_MANAGEMENT_URL "$mgmt"
  dot_deploy netbird "services:
  netbird:
    image: netbirdio/netbird:latest
    container_name: netbird
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
    devices:
      - /dev/net/tun
    environment:
      NB_SETUP_KEY: \${NB_SETUP_KEY}
      NB_MANAGEMENT_URL: \${NB_MANAGEMENT_URL}
    volumes:
      - state:/var/lib/netbird
volumes:
  state:"
  DOT_BIND='' dot_summary netbird "" "setup key and management URL in $dest/.env; status: sudo docker exec netbird netbird status"
  exit 0
fi

case $DOT_PKG in
  apt)
    dot_apt_repo netbird https://pkgs.netbird.io/debian/public.key https://pkgs.netbird.io/debian stable main
    dot_pkg_install netbird || dot_die "installing netbird failed" ;;
  dnf|yum)
    dot_rpm_repo netbird https://pkgs.netbird.io/yum/ https://pkgs.netbird.io/yum/repodata/repomd.xml.key repo_gpgcheck=1
    dot_pkg_install netbird || dot_die "installing netbird failed" ;;
  *) dot_die "no NetBird package for $DOT_OS here, see https://docs.netbird.io/get-started/install/linux" ;;
esac
netbird version
# peers connect to each other on this UDP port, without it NetBird falls back to its relays. Not in "# ports:":
# when 51820 is taken, the client asks the system for another port (freePort in client/internal/connect.go, checked
# 28.10.26); the Docker variant runs in the host network and has no ports of its own
dot_firewall_open 51820/udp

login="none yet: run sudo netbird up --management-url $mgmt, it prints a login link to open in a browser (or NB_SETUP_KEY=… netbird.sh)"
if [ ! -d /run/systemd/system ]; then
  dot_info "no systemd running: start the daemon by hand (sudo netbird service run &), then: sudo netbird up"
else
  # the package installs the binary only; "service install" writes the unit (an existing one stays)
  dot_sudo netbird service install >/dev/null 2>&1 || true
  dot_sudo systemctl enable --now netbird >/dev/null 2>&1 || dot_sudo netbird service start ||
    dot_die "starting the netbird service failed"
  for _ in $(seq 15); do dot_sudo netbird status >/dev/null 2>&1 && break; sleep 1; done
  if [ -n "$key" ]; then
    # the key goes in through a 0600 file, not on the command line where ps shows it
    tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT
    printf '%s' "$key" > "$tmp"
    dot_sudo netbird up --management-url "$mgmt" --setup-key-file "$tmp" || dot_die "netbird up with NB_SETUP_KEY failed"
    login="joined with NB_SETUP_KEY ($mgmt), status: netbird status"
  elif dot_sudo netbird status 2>/dev/null | grep -q '^Management: Connected'; then
    login="already logged in, status: netbird status"
  fi
fi
addr=$(dot_sudo netbird status 2>/dev/null | sed -n 's/^NetBird IP: *//p')
DOT_MODE=native DOT_BIND='' dot_summary netbird "${addr%/*}" "$login; peer identity in /var/lib/netbird"
