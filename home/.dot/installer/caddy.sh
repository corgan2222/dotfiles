#!/bin/bash
# installer: Caddy web server and reverse proxy with automatic HTTPS
# systems: debian arch fedora rhel
# modes: native compose portainer
# Natively: Caddy from its official repository (Cloudsmith apt repository on the Debian family, the COPR @caddy/caddy
# on Fedora and the RHEL family, Caddy's documented way there), Arch's own package; enables caddy.service.
#   caddy.sh --docker | --portainer   image caddy:2 as compose project or Portainer stack "caddy" from /opt/caddy,
#                                     certificates in /opt/caddy/data, config state in /opt/caddy/config
#   CADDY_HTTP_PORT=8081 CADDY_HTTPS_PORT=8443 caddy.sh   other ports (default 80 and 443) for the first run;
#                                     automatic HTTPS from Let's Encrypt needs 80 and 443 reachable from the internet
#   --public / --local                all interfaces (default) or this host only
# The Caddyfile (/etc/caddy/Caddyfile, Docker: /opt/caddy/Caddyfile) is written on the first install with a test site
# and commented examples for reverse_proxy and automatic HTTPS, later runs keep it and update Caddy or its image.
# After editing it: sudo systemctl reload caddy (Docker: sudo docker restart caddy).
# The admin API stays on localhost:2019 (inside the container in Docker), there is no login.
# category: server
# ports: CADDY_HTTP_PORT=80 CADDY_HTTPS_PORT=443
# check: caddy.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

http=${CADDY_HTTP_PORT:-80} https=${CADDY_HTTPS_PORT:-443}
case $http$https in ''|*[!0-9]*) dot_die "CADDY_HTTP_PORT and CADDY_HTTPS_PORT must be numbers" ;; esac
dot_mode_guard caddy caddy "$http" "$https"
# natively the ports must be free unless our own Caddy holds them already
if [ "$DOT_MODE" = native ] && ! systemctl is-active -q caddy 2>/dev/null; then
  for p in "$http" "$https"; do dot_port_busy "$p" && dot_die "port $p is already in use, Caddy cannot start"; done
fi
dot_bind 0.0.0.0

# prints the Caddyfile: $1 the HTTP port inside Caddy, $2 the HTTPS port, $3 where the upstreams on this host are,
# $4 the reload command
caddyfile() {
  cat <<EOF
# Caddyfile written by caddy.sh, kept on later runs. Docs: https://caddyserver.com/docs/caddyfile
# After a change: $4
{
	# the admin API (reload, config) only for this host
	admin localhost:2019
	http_port $1
	https_port $2$([ "$DOT_MODE" = native ] && [ "$DOT_BIND" != 0.0.0.0 ] && printf '\n\tdefault_bind %s' "$DOT_BIND")
	# contact address for Let's Encrypt (optional)
	# email admin@example.org
}

# test site on plain HTTP, any host name
:$1 {
	respond "Caddy works. Edit the Caddyfile to proxy your services." 200
}

# Reverse proxy with automatic HTTPS: the DNS name must point to this host and ports 80 and 443 must be reachable
# from the internet; Caddy then gets and renews the certificate itself.
# app.example.org {
# 	reverse_proxy $3:3000
# }

# Only in the local network: a certificate from Caddy's own CA (browsers warn until its root is trusted)
# grafana.home.example.org {
# 	tls internal
# 	reverse_proxy 192.0.2.10:3000
# }

# Several paths of one host to different services
# tools.example.org {
# 	handle_path /logs/* {
# 		reverse_proxy $3:9999
# 	}
# 	handle {
# 		reverse_proxy $3:8080
# 	}
# }
EOF
}

if [ "$DOT_MODE" != native ]; then
  dest=/opt/caddy
  dot_sudo install -d -m 0755 "$dest" "$dest/data" "$dest/config" || exit 1
  # inside the container Caddy listens on 80 and 443, Docker publishes them on the chosen ports;
  # host.docker.internal reaches the services of this host
  caddyfile 80 443 host.docker.internal "sudo docker restart caddy" | dot_put_new "$dest/Caddyfile"
  dot_deploy caddy "services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$http:80\"
      - \"$DOT_BIND:$https:443\"
      - \"$DOT_BIND:$https:443/udp\"
    extra_hosts:
      - host.docker.internal:host-gateway
    volumes:
      - $dest/Caddyfile:/etc/caddy/Caddyfile:ro
      - $dest/data:/data
      - $dest/config:/config"
  # the ports as written on the first run
  http=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):80"$/\1/p' "$dest/compose.yaml")
  https=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):443"$/\1/p' "$dest/compose.yaml")
  [ -n "${DOT_NO_START:-}" ] || dot_wait_http "http://localhost:$http/" 60 ||
    dot_die "Caddy does not answer on port $http, see: sudo docker logs caddy"
  dot_summary caddy "http://localhost:$http https://localhost:$https" \
    "none (admin API on localhost:2019 inside the container; config $dest/Caddyfile)"
  exit 0
fi

had=$(command -v caddy)
case $DOT_PKG in
  apt)
    dot_apt_repo caddy-stable https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
      https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main ;;
  dnf|yum)
    # dnf-command(copr) is dnf-plugins-core on dnf 4 and dnf5-plugins on dnf 5
    dot_pkg_install 'dnf-command(copr)' && dot_sudo dnf -y copr enable @caddy/caddy ||
      dot_die "could not enable the COPR @caddy/caddy" ;;
  pacman) ;;
  *) dot_die "caddy.sh supports the Debian family, Fedora, the RHEL family and Arch, not $DOT_OS; or run it with --docker" ;;
esac
dot_pkg_install caddy || dot_die "installing caddy failed"

# the package brings a Caddyfile serving a welcome page: a fresh install gets ours, an existing Caddy keeps its own
conf=/etc/caddy/Caddyfile
if [ -z "$had" ]; then
  caddyfile "$http" "$https" localhost "sudo systemctl reload caddy" | dot_sudo tee "$conf" >/dev/null &&
    dot_info "wrote $conf" || dot_die "could not write $conf"
else
  dot_info "keeping $conf"
fi

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable caddy && dot_sudo systemctl restart caddy || dot_die "caddy does not start, see: journalctl -u caddy"
  here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=localhost
  dot_wait_http "http://$here:$http/" 30 || dot_die "Caddy does not answer on port $http, see: journalctl -u caddy"
else
  dot_info "no systemd running: start Caddy with: sudo caddy run --config $conf"
fi
dot_info "$(caddy version | cut -d' ' -f1) installed, config $conf"
dot_summary caddy "http://localhost:$http https://localhost:$https" "none (admin API on localhost:2019 only; config $conf)"
