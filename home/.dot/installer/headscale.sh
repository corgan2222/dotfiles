#!/bin/bash
# installer: Headscale, self-hosted coordination server for Tailscale clients
# systems: debian amd64 arm64
# modes: native compose portainer
# category: network
# ports: HEADSCALE_PORT=8085 HEADSCALE_METRICS_PORT=9098
# check: headscale
# ask: HEADSCALE_SERVER_URL "URL the Tailscale clients reach Headscale at, e.g. https://hs.example.org or http://192.0.2.10:8085"
# Headscale (github.com/juanfont/headscale, BSD-3) replaces the Tailscale control server for your own tailnet.
#   native:    latest .deb from the GitHub release (sha256 checked), config /etc/headscale/config.yaml, service headscale
#   --docker / --portainer:   image headscale/headscale:stable as compose project or Portainer stack "headscale",
#              config in /opt/headscale/config, database in /opt/headscale/lib
#   HEADSCALE_SERVER_URL=https://hs.example.org   the URL clients use (default http://<this host's IP>:<port>);
#              https needs a reverse proxy in front or TLS in the config
#   HEADSCALE_PORT=8085        HTTP port (first run; 8080 is taken by many services)
#   HEADSCALE_METRICS_PORT=9098   metrics on 127.0.0.1 only (native; Headscale's 9090 is Prometheus' port)
#   HEADSCALE_USER=default     the Headscale user created on the first run
#   --public / --local         listen on all interfaces or this host only (first run; else asked, default all)
# The first run creates the user, a reusable pre-auth key (7 days) and an API key (90 days), stored root-only (0600) in
# /etc/headscale/keys.env (native) or /opt/headscale/keys.env (Docker). Running again updates Headscale and keeps
# config, database and keys. Clients: tailscale.sh, then tailscale up --login-server <url> --authkey <key>.
# No STUN port (3478/udp) in "# ports:": only Headscale's own DERP server uses it, and the example config leaves that
# off (derp.server.enabled: false); the clients use Tailscale's public DERP servers.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

port=${HEADSCALE_PORT:-8085}
mport=${HEADSCALE_METRICS_PORT:-9098}
user=${HEADSCALE_USER:-default}
url=${HEADSCALE_SERVER_URL:-}
dot_secret_ok "$url" || dot_die "HEADSCALE_SERVER_URL must not contain spaces, quotes, \$ or backslashes"
case $user in ''|*[!A-Za-z0-9._-]*) dot_die "HEADSCALE_USER may only contain letters, digits, dot, _ and -" ;; esac
mark='# headscale.sh: server_url, listen_addr and metrics_listen_addr set on the first run'

dot_mode_guard headscale headscale "$port"
dot_bind 0.0.0.0
dot_need curl jq
[ -n "$url" ] || url=http://$(hostname -I 2>/dev/null | awk '{print $1}'):$port

# sets the addresses in a config on the first run only (marker line), later runs keep the user's edits:
# set_config <file> <listen address> <metrics address>
set_config() {
  dot_sudo grep -qxF "$mark" "$1" && { dot_info "keeping $1"; return 0; }
  dot_sudo sed -i -e "s|^server_url:.*|server_url: $url|" -e "s|^listen_addr:.*|listen_addr: $2|" \
    -e "s|^metrics_listen_addr:.*|metrics_listen_addr: $3|" -e "1i $mark" "$1" || dot_die "could not edit $1"
  dot_info "wrote server_url $url into $1"
}

if [ "$DOT_MODE" = native ]; then
  [ "$DOT_PKG" = apt ] || dot_die "Headscale publishes .deb packages only (Debian, Ubuntu); use --docker elsewhere"
  case $DOT_ARCH in amd64|arm64) ;; *) dot_die "Headscale has no package for $DOT_ARCH" ;; esac
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  chmod 755 "$tmp"   # apt reads local .deb files as the user _apt
  dot_github_fetch juanfont/headscale "/headscale_[0-9.]+_linux_${DOT_ARCH}\.deb\$" "$tmp/headscale.deb" ||
    dot_die "download of the Headscale package failed"
  dot_info "installing Headscale $DOT_GITHUB_TAG"
  dot_pkg_install "$tmp/headscale.deb" || dot_die "installing headscale failed"
  conf=/etc/headscale/config.yaml keys=/etc/headscale/keys.env
  set_config "$conf" "$DOT_BIND:$port" "127.0.0.1:$mport"
  [ -d /run/systemd/system ] || dot_die "Headscale needs systemd here (service headscale)"
  dot_sudo systemctl enable headscale >/dev/null 2>&1
  dot_sudo systemctl restart headscale || dot_die "could not start headscale, see: journalctl -u headscale"
  cli=(headscale)
else
  dest=/opt/headscale conf=/opt/headscale/config/config.yaml keys=/opt/headscale/keys.env
  dot_sudo install -d -m 0755 "$dest" "$dest/config" "$dest/lib"
  if ! dot_sudo test -f "$conf"; then
    # the example config of the latest release, the version the image tag "stable" points to
    tag=$(dot_github_latest juanfont/headscale) || dot_die "cannot read the latest Headscale release from GitHub"
    curl -fsSL "https://raw.githubusercontent.com/juanfont/headscale/$tag/config-example.yaml" |
      dot_sudo tee "$conf" >/dev/null && dot_sudo grep -q '^server_url:' "$conf" ||
      dot_die "could not download the example config of Headscale $tag"
  fi
  # inside the container on 8080, published on HEADSCALE_PORT; the metrics stay inside the container
  set_config "$conf" 0.0.0.0:8080 127.0.0.1:9090
  dot_deploy headscale "services:
  headscale:
    image: headscale/headscale:stable
    container_name: headscale
    restart: unless-stopped
    read_only: true
    command: serve
    tmpfs:
      - /var/run/headscale
    ports:
      - \"$DOT_BIND:$port:8080\"
    volumes:
      - $dest/config:/etc/headscale:ro
      - $dest/lib:/var/lib/headscale
    healthcheck:
      test: [\"CMD\", \"headscale\", \"health\"]"
  cli=(docker exec headscale headscale)
fi

# "[address:]port" as written on the first run; a different answer now is only reported
if [ "$DOT_MODE" = native ]; then
  pub=$(dot_sudo sed -n 's/^listen_addr: *//p' "$conf")
else
  pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dest/compose.yaml")
fi
port=${pub##*:} bound=${pub%:*}
[ "$bound" != "$pub" ] || bound=0.0.0.0
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Headscale keeps listening on $bound (set on the first run), edit $conf or compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=127.0.0.1
dot_wait_http "http://$here:$port/health" 60 || dot_die "Headscale does not answer on port $port"
url=$(dot_sudo sed -n 's/^server_url: *//p' "$conf")

# user, pre-auth key and API key on the first run; the keys file is the marker
if ! dot_sudo test -f "$keys"; then
  hs() { dot_sudo "${cli[@]}" "$@"; }
  id=$(hs users list -o json | jq -r --arg u "$user" '.[]? | select(.name == $u) | .id')
  [ -n "$id" ] || id=$(hs users create "$user" -o json | jq -r .id)
  [ -n "$id" ] || dot_die "could not create the Headscale user $user"
  pre=$(hs preauthkeys create --user "$id" --reusable --expiration 7d -o json | jq -r .key)
  api=$(hs apikeys create --expiration 90d -o json | jq -r .)
  [ -n "$pre" ] && [ "$pre" != null ] && [ -n "$api" ] && [ "$api" != null ] ||
    dot_die "could not create the pre-auth key or the API key"
  printf 'HEADSCALE_USER=%s\nHEADSCALE_PREAUTH_KEY=%s\nHEADSCALE_API_KEY=%s\n' "$user" "$pre" "$api" |
    dot_sudo sh -c "umask 077; cat > '$keys'" || dot_die "could not write $keys"
  dot_info "created user $user, a pre-auth key and an API key in $keys"
fi

addrs=$url; [ "$url" = "http://localhost:$port" ] || addrs+=" http://localhost:$port"
dot_summary headscale "$addrs" \
  "user $(dot_sudo sed -n 's/^HEADSCALE_USER=//p' "$keys"), HEADSCALE_PREAUTH_KEY (reusable, 7 days) and HEADSCALE_API_KEY (90 days) in $keys
           connect a client (tailscale.sh): sudo tailscale up --login-server $url --authkey <HEADSCALE_PREAUTH_KEY>
           new key: sudo ${cli[*]} preauthkeys create --user <id from: users list> --reusable --expiration 7d"
