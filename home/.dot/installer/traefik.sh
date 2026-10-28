#!/bin/bash
# installer: Traefik v3 reverse proxy for Docker containers, dashboard with a login
# systems: amd64 arm64 armv7
# modes: compose portainer
# Runs Traefik (image traefik:v3) as compose project or Portainer stack "traefik" from /opt/traefik (default: compose,
# --portainer for a stack); installs Docker through docker.sh when it is missing. Docker only, on purpose: Traefik
# finds its routes in the labels of other containers (Docker provider), that is what it is for. A native install would
# need a binary download, its own user, unit and config files and still the Docker socket, without any gain.
# Entrypoints: web (HTTP), websecure (HTTPS, certificate resolver "letsencrypt" with the TLS challenge) and dashboard.
# Only containers with the label traefik.enable=true are routed (exposedByDefault=false). Labels of a service:
#   labels:
#     - traefik.enable=true
#     - traefik.http.routers.app.rule=Host(`app.example.org`)
#     - traefik.http.routers.app.entrypoints=websecure
#     - traefik.http.routers.app.tls.certresolver=letsencrypt
#     - traefik.http.services.app.loadbalancer.server.port=3000
#   and the service in the network "traefik" (networks: [traefik], with "networks: traefik: external: true").
#   TRAEFIK_DASHBOARD_PORT=8095 traefik.sh      port of the dashboard (default 8095; 8080 is often taken, 8085 is Headscale's)
#   TRAEFIK_HTTP_PORT=80 TRAEFIK_HTTPS_PORT=443 the published ports (defaults); Let's Encrypt needs 443 from the internet
#   TRAEFIK_ACME_EMAIL=admin@example.org        contact address for Let's Encrypt (optional)
#   --public / --local                          all interfaces (default) or this host only
# Dashboard login: user admin with a random password (first run), in plain text in /opt/traefik/.env (root only) and
# as apr1 hash in /opt/traefik/dashboard-users. Compose file and both files are written on the first run only; running
# again pulls the newest v3 image. Certificates in /opt/traefik/letsencrypt/acme.json.
# The Docker socket is mounted read-only, but that does not limit the Docker API: Traefik sees all containers.
# category: server
# ports: TRAEFIK_HTTP_PORT=80 TRAEFIK_HTTPS_PORT=443 TRAEFIK_DASHBOARD_PORT=8095
# check: stack:traefik
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
# there is no native variant
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/traefik
http=${TRAEFIK_HTTP_PORT:-80} https=${TRAEFIK_HTTPS_PORT:-443} dash=${TRAEFIK_DASHBOARD_PORT:-8095}
case $http$https$dash in ''|*[!0-9]*) dot_die "TRAEFIK_HTTP_PORT, TRAEFIK_HTTPS_PORT and TRAEFIK_DASHBOARD_PORT must be numbers" ;; esac
email=${TRAEFIK_ACME_EMAIL:-}
dot_secret_ok "$email" || dot_die "TRAEFIK_ACME_EMAIL must not contain spaces, quotes, \$ or backslashes"
dot_mode_guard traefik traefik "$http" "$https" "$dash"
dot_bind 0.0.0.0
dot_need openssl

dot_sudo install -d -m 0755 "$dest" || exit 1
dot_sudo install -d -m 0700 "$dest/letsencrypt" || exit 1
# the password of the first run stays in .env; the hash file is written with a new password or when it is missing
users=$dest/dashboard-users
pw=$(dot_sudo sed -n 's/^TRAEFIK_DASHBOARD_PASSWORD=//p' "$dest/.env" 2>/dev/null)
if [ -z "$pw" ] || ! dot_sudo test -s "$users"; then
  [ -n "$pw" ] || pw=$(dot_password 24)
  # the password goes in on stdin, not on the command line; Traefik runs as root in the container, 0600 is enough
  hash=$(printf '%s\n' "$pw" | openssl passwd -apr1 -stdin) && [ -n "$hash" ] || dot_die "openssl could not hash the password"
  printf 'admin:%s\n' "$hash" | dot_sudo sh -c "umask 077; cat > '$users'" || dot_die "could not write $users"
  dot_info "wrote $users for user admin"
fi
dot_env_set "$dest/.env" TRAEFIK_DASHBOARD_USER admin && dot_env_set "$dest/.env" TRAEFIK_DASHBOARD_PASSWORD "$pw" ||
  dot_die "could not write $dest/.env"

# the network "traefik" is for the services Traefik routes to; created by the stack, other stacks join it as external
dot_deploy traefik "services:
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: unless-stopped
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=traefik
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --entrypoints.dashboard.address=:8080
      - --api.dashboard=true
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json$([ -n "$email" ] && printf '\n      - --certificatesresolvers.letsencrypt.acme.email=%s' "$email")
      # every HTTP request to HTTPS:
      # - --entrypoints.web.http.redirections.entrypoint.to=websecure
    ports:
      - \"$DOT_BIND:$http:80\"
      - \"$DOT_BIND:$https:443\"
      - \"$DOT_BIND:$dash:8080\"
    networks:
      - traefik
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $users:/etc/traefik/dashboard-users:ro
      - $dest/letsencrypt:/letsencrypt
    labels:
      - traefik.enable=true
      - traefik.http.routers.dashboard.entrypoints=dashboard
      - traefik.http.routers.dashboard.rule=PathPrefix(\`/api\`) || PathPrefix(\`/dashboard\`)
      - traefik.http.routers.dashboard.service=api@internal
      - traefik.http.routers.dashboard.middlewares=dashboard-auth
      - traefik.http.middlewares.dashboard-auth.basicauth.usersfile=/etc/traefik/dashboard-users
networks:
  traefik:
    name: traefik"

# prints "[address:]port" that compose.yaml publishes for port $1 of the container
published() { dot_sudo sed -n "s/^ *- \"\(.*\):$1\"\$/\1/p" "$dest/compose.yaml"; }
# the ports as written on the first run; a different address now is only reported
pub=$(published 8080) http=$(published 80) https=$(published 443)
dash=${pub##*:} http=${http##*:} https=${https##*:}
case $pub in *:*) [ "${pub%:*}" = "$DOT_BIND" ] || { echo "warning: Traefik keeps listening on ${pub%:*} (set on the first run), edit $dest/compose.yaml to change it" >&2; DOT_BIND=${pub%:*}; } ;; esac
if [ -z "${DOT_NO_START:-}" ]; then
  # 401 without the login: the dashboard router and its middleware are up
  dot_wait_http "http://localhost:$dash/dashboard/" 60 401 || dot_die "the Traefik dashboard does not answer on port $dash, see: sudo docker logs traefik"
fi
dot_summary traefik "http://localhost:$dash/dashboard/ http://localhost:$http https://localhost:$https" \
  "user admin, password: TRAEFIK_DASHBOARD_PASSWORD in $dest/.env"
