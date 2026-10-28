#!/bin/bash
# installer: Nginx Proxy Manager, reverse proxy with Let's Encrypt and a web UI, in Docker
# systems: amd64 arm64 armv7
# modes: compose portainer
# Runs Nginx Proxy Manager (nginxproxymanager.com, image jc21/nginx-proxy-manager:latest) as compose project or
# Portainer stack "nginx-proxy-manager" from /opt/nginx-proxy-manager (default: compose, --portainer for a stack);
# installs Docker through docker.sh when it is missing. Data and certificates stay in /opt/nginx-proxy-manager/data and
# /opt/nginx-proxy-manager/letsencrypt. The compose file is written on the first run only; running again pulls the
# newest image. Services of this host are reachable from the proxy as host.docker.internal.
#   NPM_HTTP_PORT=80 NPM_HTTPS_PORT=443 NPM_ADMIN_PORT=81   the published ports (defaults); 81 is the admin UI
#   NPM_ADMIN_EMAIL=admin@example.org                       e-mail of the admin login (default admin@example.org)
#   --public / --local                                      all interfaces (default) or this host only
# Login: the e-mail and a random password, kept root-only in /opt/nginx-proxy-manager/.env. Nginx Proxy Manager
# creates that admin on its first start (INITIAL_ADMIN_EMAIL, INITIAL_ADMIN_PASSWORD) and writes the password into its
# container log once. An older data folder with the former default login admin@example.com / changeme gets the
# login of .env through the API; one changed by hand stays.
# category: server
# ports: NPM_HTTP_PORT=80 NPM_HTTPS_PORT=443 NPM_ADMIN_PORT=81
# check: stack:nginx-proxy-manager
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
# there is no native variant
[ "$DOT_MODE" = native ] && DOT_MODE=compose

name=nginx-proxy-manager dest=/opt/nginx-proxy-manager
http=${NPM_HTTP_PORT:-80} https=${NPM_HTTPS_PORT:-443} admin=${NPM_ADMIN_PORT:-81}
case $http$https$admin in ''|*[!0-9]*) dot_die "NPM_HTTP_PORT, NPM_HTTPS_PORT and NPM_ADMIN_PORT must be numbers" ;; esac
dot_mode_guard "$name" "$name" "$http" "$https" "$admin"
dot_bind 0.0.0.0
dot_need curl jq

# the login of the first run stays
dot_sudo install -d -m 0755 "$dest" || exit 1
email=$(dot_sudo sed -n 's/^NPM_ADMIN_EMAIL=//p' "$dest/.env" 2>/dev/null)
pw=$(dot_sudo sed -n 's/^NPM_ADMIN_PASSWORD=//p' "$dest/.env" 2>/dev/null)
[ -n "$email" ] || email=${NPM_ADMIN_EMAIL:-admin@example.org}
[[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$ ]] || dot_die "NPM_ADMIN_EMAIL is not an e-mail address: $email"
[ -n "$pw" ] || pw=$(dot_password 24)
dot_env_set "$dest/.env" NPM_ADMIN_EMAIL "$email" && dot_env_set "$dest/.env" NPM_ADMIN_PASSWORD "$pw" ||
  dot_die "could not write $dest/.env"

dot_deploy "$name" "services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$http:80\"
      - \"$DOT_BIND:$https:443\"
      - \"$DOT_BIND:$admin:81\"
    environment:
      INITIAL_ADMIN_EMAIL: \${NPM_ADMIN_EMAIL}
      INITIAL_ADMIN_PASSWORD: \${NPM_ADMIN_PASSWORD}
    extra_hosts:
      - host.docker.internal:host-gateway
    volumes:
      - $dest/data:/data
      - $dest/letsencrypt:/etc/letsencrypt"

# prints "[address:]port" that compose.yaml publishes for port $1 of the container
published() { dot_sudo sed -n "s/^ *- \"\(.*\):$1\"\$/\1/p" "$dest/compose.yaml"; }
# the ports as written on the first run; a different address now is only reported
pub=$(published 81) http=$(published 80) https=$(published 443)
admin=${pub##*:} http=${http##*:} https=${https##*:}
case $pub in *:*) [ "${pub%:*}" = "$DOT_BIND" ] || { echo "warning: Nginx Proxy Manager keeps listening on ${pub%:*} (set on the first run), edit $dest/compose.yaml to change it" >&2; DOT_BIND=${pub%:*}; } ;; esac
[ -n "${DOT_NO_START:-}" ] && { dot_summary "$name" "http://localhost:$admin" "user $email, password: NPM_ADMIN_PASSWORD in $dest/.env"; exit 0; }

# Checks the login of .env through the API and prints the login text for the summary; replaces the former default
# login admin@example.com / changeme (images before INITIAL_ADMIN_*, or an older data folder) with it.
# POST /api/tokens {identity, secret} gives a token; PUT /api/users/<id> sets the e-mail, PUT /api/users/<id>/auth the
# password (with the current one).
npm_login() {
  local api=http://localhost:$admin/api tok id
  token() { curl -fsS -m 20 -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg i "$1" --arg s "$2" '{identity: $i, secret: $s}')" "$api/tokens" 2>/dev/null | jq -r '.token // empty'; }
  # the first start creates the database, give it 2 minutes
  dot_wait_http "$api/" 120 || { echo "the API did not answer, try the login of $dest/.env"; return; }
  tok=$(token "$email" "$pw")
  if [ -z "$tok" ] && tok=$(token admin@example.com changeme) && [ -n "$tok" ]; then
    id=$(curl -fsS -m 20 -H "Authorization: Bearer $tok" "$api/users/me" | jq -r '.id // empty')
    curl -fsS -m 20 -X PUT -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
      -d "$(jq -nc --arg e "$email" '{email: $e, nickname: "Admin", name: "Administrator"}')" "$api/users/$id" >/dev/null &&
      curl -fsS -m 20 -X PUT -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg s "$pw" '{type: "password", current: "changeme", secret: $s}')" "$api/users/$id/auth" >/dev/null ||
      { echo "admin@example.com / changeme (setting the login of $dest/.env failed): change it right away"; return; }
    tok=$(token "$email" "$pw")
  fi
  if [ -n "$tok" ]; then
    echo "user $email, password: NPM_ADMIN_PASSWORD in $dest/.env"
  else
    echo "your own login (the one in $dest/.env does not work: the data folder has another admin)"
  fi
}

login=$(npm_login)
dot_summary "$name" "http://localhost:$admin http://localhost:$http https://localhost:$https" "$login"
