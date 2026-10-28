#!/bin/bash
# installer: Runtipi, home server app store with a web dashboard on Docker
# systems: amd64 arm64
# Installs the runtipi-cli release binary from GitHub (sha256 digest checked) into /opt/runtipi and runs
# "runtipi-cli start" there; installs Docker through docker.sh when it is missing. Not "curl setup.runtipi.io | bash":
# that script downloads the CLI unchecked into ./runtipi of the current directory and may reinstall Docker.
# The CLI writes docker-compose.yml and .env itself and starts Traefik, Postgres, RabbitMQ and the dashboard as
# compose project "runtipi"; apps from the app store run as further containers next to them.
#   runtipi.sh
#   RUNTIPI_PORT=7080 RUNTIPI_SSL_PORT=7043   dashboard ports (first run; the vendor's 80 and 443 belong to the
#                                             reverse proxies here)
#   RUNTIPI_USER=admin@example.com RUNTIPI_PASSWORD=…   the admin login (first run; Runtipi wants an e-mail address
#                                             as user name), password default random
#   RUNTIPI_VERSION=v4.11.0                   another release than the newest (never back to an older one)
#   --public / --local                        dashboard on all interfaces or this host only (first run; else asked,
#                                             default all)
# Runtipi lets the first visitor of a new dashboard create the admin: this installer creates it right after the start,
# login root-only in /etc/runtipi/credentials. Settings /opt/runtipi/state/settings.json (port, sslPort, domain …),
# listen address /opt/runtipi/user-config/tipi-compose.yml; both are written on the first run and yours from then on,
# apply with: cd /opt/runtipi && sudo ./runtipi-cli restart. Running again moves to the newest release and restarts.
# Apps that publish a port of their own listen on all interfaces, whatever the dashboard does.
# category: server
# ports: RUNTIPI_PORT=7080 RUNTIPI_SSL_PORT=7043
# check: /opt/runtipi/runtipi-cli
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ $# -eq 0 ] || dot_die "unknown argument '$1', usage: runtipi.sh [--public|--local]"
DOT_MODE=native

dest=/opt/runtipi
cli=$dest/runtipi-cli
settings=$dest/state/settings.json
override=$dest/user-config/tipi-compose.yml
creds=/etc/runtipi/credentials
case $DOT_ARCH in amd64) asset=x86_64 ;; arm64) asset=aarch64 ;; *) dot_die "Runtipi has no build for $DOT_ARCH" ;; esac
user=${RUNTIPI_USER:-admin@example.com} pw=${RUNTIPI_PASSWORD:-}
[[ ${user,,} =~ ^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$ ]] ||
  dot_die "RUNTIPI_USER must be an e-mail address, got '$user'"
dot_secret_ok "$pw" || dot_die "RUNTIPI_PASSWORD must not contain spaces, quotes, \$ or backslashes"
[ -z "${RUNTIPI_VERSION:-}" ] || [[ $RUNTIPI_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  dot_die "RUNTIPI_VERSION must look like v4.11.0, got '$RUNTIPI_VERSION'"
dot_need curl tar jq

# the address of an earlier run, from the ports line of the override this installer wrote
old=$(dot_sudo sed -n 's/^ *- \(.*\):\${NGINX_PORT:-80}:80$/\1/p' "$override" 2>/dev/null)
dot_bind 0.0.0.0 "$old"
[ -z "$old" ] || [ "$old" = "$DOT_BIND" ] ||
  echo "warning: $override keeps the dashboard on $old; edit it and run runtipi.sh again to move it" >&2

if dot_sudo test -f "$settings"; then
  port=$(dot_sudo jq -r '.port // 80' "$settings") ssl=$(dot_sudo jq -r '.sslPort // 443' "$settings") ||
    dot_die "$settings is no valid JSON"
  [ "${RUNTIPI_PORT:-$port}/${RUNTIPI_SSL_PORT:-$ssl}" = "$port/$ssl" ] ||
    echo "warning: ports only count on the first run: set port and sslPort in $settings, run runtipi.sh again" >&2
else
  port=${RUNTIPI_PORT:-7080} ssl=${RUNTIPI_SSL_PORT:-7043}
  for p in "$port" "$ssl"; do
    [[ $p =~ ^[1-9][0-9]{0,4}$ ]] && [ "$p" -le 65535 ] ||
      dot_die "RUNTIPI_PORT and RUNTIPI_SSL_PORT must be ports, got '$p'"
  done
  [ "$port" != "$ssl" ] || dot_die "RUNTIPI_PORT and RUNTIPI_SSL_PORT must differ"
fi
# runtipi itself holds them on a second run
dot_stack_running runtipi || for p in "$port" "$ssl"; do
  dot_port_busy "$p" && dot_die "port $p is taken: set RUNTIPI_PORT or RUNTIPI_SSL_PORT (first run) or $settings"
done

# the CLI: download only when the wanted release is newer than the one in place (VERSION is written by the CLI)
have=$(cat "$dest/VERSION" 2>/dev/null)
want=${RUNTIPI_VERSION:-$(dot_github_latest runtipi/runtipi)} ||
  dot_die "cannot read the latest Runtipi release from GitHub"
if [ -x "$cli" ] && [ -n "$have" ] && [ "$(printf '%s\n%s\n' "$have" "$want" | sort -V | tail -n 1)" = "$have" ]; then
  dot_info "Runtipi $have is installed${RUNTIPI_VERSION:+, not going back to $want}"
else
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_info "Downloading runtipi-cli $want ($asset)"
  dot_github_fetch runtipi/runtipi "/runtipi-cli-linux-$asset\.tar\.gz\$" "$tmp/cli.tar.gz" "$want" ||
    dot_die "could not download runtipi-cli $want"
  tar -xzf "$tmp/cli.tar.gz" -C "$tmp" && [ -f "$tmp/runtipi-cli-linux-$asset" ] ||
    dot_die "runtipi-cli-linux-$asset.tar.gz holds no runtipi-cli-linux-$asset"
  dot_sudo install -D -m 0755 "$tmp/runtipi-cli-linux-$asset" "$cli" || dot_die "could not install $cli"
fi

# first run: ports and listen address; the CLI turns settings.json into NGINX_PORT and NGINX_PORT_SSL in .env and
# merges tipi-compose.yml into its compose file (Traefik publishes on all interfaces otherwise)
dot_sudo install -d -m 0755 "$dest/state" "$dest/user-config" || exit 1
printf '{\n  "port": %s,\n  "sslPort": %s\n}\n' "$port" "$ssl" | dot_put_new "$settings"
dot_put_new "$override" <<EOF
# written by runtipi.sh on the first run, yours from now on; runtipi-cli merges it into docker-compose.yml.
# Apply: cd $dest && sudo ./runtipi-cli restart
services:
  runtipi-reverse-proxy:
    ports: !override
      - $DOT_BIND:\${NGINX_PORT:-80}:80
      - $DOT_BIND:\${NGINX_PORT_SSL:-443}:443
EOF
[ -n "${DOT_NO_START:-}" ] && { dot_info "files in $dest written, not started (DOT_NO_START)"; exit 0; }

dot_docker_ready runtipi
dot_info "Starting Runtipi (runtipi-cli start pulls its images, takes a few minutes the first time)"
dot_sudo sh -c "cd '$dest' && ./runtipi-cli start" </dev/null ||
  dot_die "runtipi-cli start failed, see its output above"
host=$DOT_BIND; [ "$host" = 0.0.0.0 ] && host=127.0.0.1
url=http://$host:$port
dot_wait_http "$url/api/health" 120 || dot_die "Runtipi does not answer on $url, see: sudo docker logs runtipi"

# prints a key of the credentials file
cred() { dot_sudo sed -n "s/^$1=//p" "$creds" 2>/dev/null; }
# posts user and password as JSON to /api/auth/<$1> and prints the HTTP status; printf is a builtin, so the
# password stays off the process list
auth() {
  printf '{"username":"%s","password":"%s"}' "$(cred RUNTIPI_USER)" "$(cred RUNTIPI_PASSWORD)" |
    curl -s -m 20 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' --data @- "$url/api/auth/$1"
}

configured=$(curl -fsS -m 20 "$url/api/user-context" | jq -r .isConfigured) || dot_die "Runtipi's API does not answer"
if [ "$configured" = false ]; then
  dot_sudo test -f "$creds" || {
    dot_sudo install -d -m 0755 /etc/runtipi &&
      printf 'RUNTIPI_USER=%s\nRUNTIPI_PASSWORD=%s\n' "${user,,}" "${pw:-$(dot_password 24)}" |
      dot_sudo sh -c "umask 077; cat > '$creds'" || dot_die "could not write $creds"
  }
  [ "$(auth register)" = 201 ] || dot_die "could not create the Runtipi admin (someone else was first? see $url)"
  dot_info "admin $(cred RUNTIPI_USER) created"
  login="user $(cred RUNTIPI_USER), password: RUNTIPI_PASSWORD in $creds"
elif dot_sudo test -f "$creds"; then
  [ "$(auth login)" = 201 ] ||
    echo "warning: the login in $creds does not work (changed in the dashboard?)," \
      "see: cd $dest && sudo ./runtipi-cli reset-password" >&2
  login="user $(cred RUNTIPI_USER), password: RUNTIPI_PASSWORD in $creds"
else
  login="the admin created in the dashboard before (forgotten: cd $dest && sudo ./runtipi-cli reset-password)"
fi

dot_summary runtipi "http://localhost:$port" "$login" docker
# Traefik routes https only for the names in settings.json, a bare address gets a 404 there
printf '  https:   port %s, only for domain and localDomain of settings.json (default tipi.local)\n' "$ssl"
printf '  manage:  cd %s && sudo ./runtipi-cli start|stop|restart; logs: sudo docker logs -f runtipi\n' "$dest"
printf '  config:  %s, %s\n' "$settings" "$override"
