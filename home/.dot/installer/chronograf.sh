#!/bin/bash
# installer: Chronograf web UI for InfluxDB (InfluxData apt or rpm repository)
# systems: debian fedora rhel
# modes: native compose portainer
# Installs Chronograf from repos.influxdata.com and points it at the InfluxDB on this machine, when there is one
# (native or a stack from "influxdb.sh <line> --docker/--portainer", newest line first):
#   InfluxDB 3 Core -> with the token from /etc/influxdb3/ or /opt/influxdb3/admin-token.json
#   InfluxDB 2      -> with a read-only token (buckets, org, DBRP mappings) made with the operator token from
#                      /etc/influxdb/setup.env or /opt/influxdb2/.env: Chronograf can show and query, not write
#   InfluxDB 1.x    -> on port 8086
# InfluxDB 3 Core knows admin tokens only (3.12, 10.2026), so Chronograf gets that one.
# The connection goes to /etc/default/chronograf (root only, it holds a token); a file of that name not
# written by this installer is kept. Web UI on port 8888.
# Chronograf has no login of its own (only OAuth), whoever reaches it uses its token: it listens on 127.0.0.1 unless
# told otherwise. For the network put a reverse proxy with a login in front (caddy.sh, traefik.sh,
# nginx_proxy_manager.sh) or use --public in a trusted network.
#   chronograf.sh
#   CHRONOGRAF_PORT=8889 chronograf.sh     another port; later runs without it keep the port of the earlier run
#   chronograf.sh --docker | --portainer   image chronograf:1.11 as compose project or Portainer stack "chronograf"
#                                          from /opt/chronograf, connection in /opt/chronograf/.env (written once;
#                                          an operator token of an older run there becomes a read-only one)
#   --public / --local                     all interfaces or this host only (else asked; default this host, or what
#                                          an earlier run set)
# Also run by "influxdb.sh <line> --chronograf".
# category: db
# ports: CHRONOGRAF_PORT=8888
# check: chronograf.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

env=/etc/default/chronograf

# prints the value of key $1 from the root-only file $2 (KEY=value, "key": "value" or YAML "    KEY: value")
secret() {
  dot_sudo sed -n "s/^$1=//p; s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p; s/^ *$1: *//p" "$2" 2>/dev/null | head -n 1
}

# the config of an earlier run: its port, address and token stay unless given again (28.10.26: a second run without
# CHRONOGRAF_PORT moved Chronograf from 8889 back to 8888); the compose file is kept by dot_deploy anyway
if [ "$DOT_MODE" = native ]; then cfg=$env old_tok=$(secret INFLUXDB_TOKEN "$env")
else cfg=/opt/chronograf/compose.yaml old_tok=; fi
port=${CHRONOGRAF_PORT:-$(secret PORT "$cfg")}
port=${port:-8888}
case $port in ''|*[!0-9]*) dot_die "CHRONOGRAF_PORT must be a number, got '$port'" ;; esac
old_bind=$(secret HOST "$cfg")

# InfluxDB 2: prints a token that may read buckets, the org and DBRP mappings, made with the operator token; Chronograf
# 1.11 lists and queries with it (InfluxQL and Flux) and its writes are refused (InfluxDB 2.9.1, checked 28.10.26).
# The token of an earlier run is taken again unless InfluxDB refuses it (401, 403): an InfluxDB that does not answer
# cannot check it, and dropping it then left Chronograf without a connection (28.10.26, InfluxDB 2 stopped).
# v2_token <url> <org> <operator token>
v2_token() {
  local url=$1 org=$2 op=$3 oid perms code
  if [ -n "$old_tok" ] && [ "$old_tok" != "$op" ]; then
    code=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H "Authorization: Token $old_tok" \
      "$url/api/v2/buckets?limit=1")
    case $code in 401|403) ;; *) echo "$old_tok"; return ;; esac
  fi
  oid=$(curl -fsS -H "Authorization: Token $op" "$url/api/v2/orgs?org=$org" | grep -o '"id": *"[0-9a-f]*"' |
    head -n 1 | grep -o '[0-9a-f]\{16\}') || return 1
  perms="{\"action\": \"read\", \"resource\": {\"type\": \"buckets\", \"orgID\": \"$oid\"}},
    {\"action\": \"read\", \"resource\": {\"type\": \"dbrp\", \"orgID\": \"$oid\"}},
    {\"action\": \"read\", \"resource\": {\"type\": \"orgs\", \"id\": \"$oid\"}}"
  curl -fsS -H "Authorization: Token $op" -H 'Content-Type: application/json' "$url/api/v2/authorizations" -d \
    "{\"orgID\": \"$oid\", \"description\": \"chronograf.sh: read only\", \"permissions\": [$perms]}" |
    grep -o '"token": *"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/'
}

# prints the INFLUXDB_* lines of InfluxDB 2 at $1 with org $2 and operator token $3; the token line stays empty when
# no token can be made
v2_conn() {
  local tok=
  [ -z "$3" ] || tok=$(v2_token "$1" "$2" "$3") || tok=
  [ -n "$3" ] && [ -z "$tok" ] && echo "warning: could not make a read-only token in InfluxDB 2 at $1" >&2
  printf 'INFLUXDB_TYPE=influx-v2\nINFLUXDB_URL=%s\nINFLUXDB_ORG=%s\nINFLUXDB_TOKEN=%s\n' "$1" "$2" "$tok"
}

# prints the Chronograf connection (INFLUXDB_* lines) to the newest InfluxDB line on this machine, reached as
# host $1; the token comes last
influx_conn() {
  local h=$1 p
  if dot_sudo test -f /opt/influxdb3/compose.yaml; then
    p=$(dot_sudo sed -n 's/^ *- "\(.*:\)\{0,1\}\([0-9]*\):8181"$/\2/p' /opt/influxdb3/compose.yaml)
    printf 'INFLUXDB_TYPE=influx-v3-core\nINFLUXDB_V3_SUPPORT_ENABLED=true\nINFLUXDB_URL=http://%s:%s\nINFLUXDB_TOKEN=%s\n' \
      "$h" "${p:-8183}" "$(secret token /opt/influxdb3/admin-token.json)"
  elif dot_pkg_installed influxdb3-core; then
    p=$(dot_sudo sed -n 's/^http-bind[[:space:]]*=[[:space:]]*".*:\([0-9]*\)"/\1/p' /etc/influxdb3/influxdb3-core.conf)
    printf 'INFLUXDB_TYPE=influx-v3-core\nINFLUXDB_V3_SUPPORT_ENABLED=true\nINFLUXDB_URL=http://%s:%s\nINFLUXDB_TOKEN=%s\n' \
      "$h" "${p:-8181}" "$(secret token /etc/influxdb3/admin-token.json)"
  elif dot_sudo test -f /opt/influxdb2/compose.yaml; then
    v2_conn "http://$h:8086" "$(secret DOCKER_INFLUXDB_INIT_ORG /opt/influxdb2/.env)" \
      "$(secret DOCKER_INFLUXDB_INIT_ADMIN_TOKEN /opt/influxdb2/.env)"
  elif dot_pkg_installed influxdb2; then
    v2_conn "http://$h:8086" "$(secret INFLUX_ORG /etc/influxdb/setup.env)" \
      "$(secret INFLUX_TOKEN /etc/influxdb/setup.env)"
  elif dot_sudo test -f /opt/influxdb1/compose.yaml || dot_pkg_installed influxdb; then
    printf 'INFLUXDB_TYPE=influx\nINFLUXDB_URL=http://%s:8086\n' "$h"
  fi
}

dot_mode_guard chronograf chronograf "$port"
dot_bind 127.0.0.1 "$old_bind"
login="none: whoever reaches Chronograf reads InfluxDB with its token; for the network a reverse proxy with a login"
login+=" in front (caddy.sh, traefik.sh, nginx_proxy_manager.sh)"

# Docker: host network, so InfluxDB is reached on localhost whether it runs natively or in its own stack, also when
# it listens on 127.0.0.1 only (a bridge network could not reach that); no network is shared between stacks
if [ "$DOT_MODE" != native ]; then
  # the .env is written once: no new token on later runs
  conn=
  if ! dot_sudo test -f /opt/chronograf/.env; then
    conn=$(influx_conn localhost)
    case $conn in
      *INFLUXDB_TOKEN=) conn=; dot_info "no InfluxDB token found: add the connection in the Chronograf UI" ;;
      '') dot_info "no InfluxDB on this machine: add the connection in the Chronograf UI" ;;
    esac
  else
    # a .env written before the read-only token (28.10.26) holds InfluxDB 2's operator token: swap it for one
    old_tok=$(secret INFLUXDB_TOKEN /opt/chronograf/.env)
    for op in "$(secret DOCKER_INFLUXDB_INIT_ADMIN_TOKEN /opt/influxdb2/.env)" \
              "$(secret INFLUX_TOKEN /etc/influxdb/setup.env)"; do
      [ -n "$op" ] && [ "$op" = "$old_tok" ] || continue
      tok=$(v2_token "$(secret INFLUXDB_URL /opt/chronograf/.env)" "$(secret INFLUXDB_ORG /opt/chronograf/.env)" "$op")
      if [ -n "$tok" ] && dot_env_set /opt/chronograf/.env INFLUXDB_TOKEN "$tok"; then
        dot_info "replaced InfluxDB's operator token in /opt/chronograf/.env with a read-only one"
      else
        echo "warning: /opt/chronograf/.env still holds InfluxDB's operator token, no read-only one could be made" >&2
      fi
      break
    done
  fi
  dot_deploy chronograf "services:
  chronograf:
    image: chronograf:1.11
    container_name: chronograf
    restart: unless-stopped
    network_mode: host
    environment:
      HOST: $DOT_BIND
      PORT: $port
      INFLUXDB_TYPE: \${INFLUXDB_TYPE:-}
      INFLUXDB_V3_SUPPORT_ENABLED: \${INFLUXDB_V3_SUPPORT_ENABLED:-false}
      INFLUXDB_URL: \${INFLUXDB_URL:-}
      INFLUXDB_ORG: \${INFLUXDB_ORG:-}
      INFLUXDB_TOKEN: \${INFLUXDB_TOKEN:-}
    volumes:
      - data:/var/lib/chronograf
volumes:
  data:" "$conn"
  dot_sudo test -f /opt/chronograf/.env &&
    dot_info "Chronograf connects to $(dot_sudo sed -n 's/^INFLUXDB_URL=//p' /opt/chronograf/.env) (/opt/chronograf/.env)"
  # the kept compose file says where it listens
  port=$(secret PORT "$cfg") DOT_BIND=$(secret HOST "$cfg")
  dot_summary chronograf "http://localhost:$port" "$login"
  exit 0
fi

case $DOT_PKG in apt|dnf|yum) ;; *) dot_die "chronograf.sh supports Debian-based systems, Fedora and the RHEL family, not $DOT_OS" ;; esac

# repos.influxdata.com, as in influxdb.sh: fingerprint from the InfluxData docs
fpr=24C975CBA61A024EE1B631787C3D57159FC2F927
if [ "$DOT_PKG" != apt ]; then
  if [ ! -f /etc/yum.repos.d/influxdata.repo ]; then
    dot_need gpg
    tmp=$(mktemp) && curl -fsSL -o "$tmp" https://repos.influxdata.com/influxdata-archive.key ||
      { rm -f "$tmp"; dot_die "could not download the InfluxData key"; }
    gpg --show-keys --with-colons "$tmp" 2>/dev/null | grep -q "^fpr:*$fpr:" ||
      { rm -f "$tmp"; dot_die "the InfluxData key has an unexpected fingerprint"; }
    dot_sudo install -m 0644 "$tmp" /etc/pki/rpm-gpg/RPM-GPG-KEY-influxdata && rm -f "$tmp" || exit 1
    dot_rpm_repo influxdata 'https://repos.influxdata.com/stable/$basearch/main' file:///etc/pki/rpm-gpg/RPM-GPG-KEY-influxdata
  fi
elif [ ! -f /etc/apt/sources.list.d/influxdata.sources ]; then
  dot_need gpg
  dot_apt_repo influxdata https://repos.influxdata.com/influxdata-archive.key https://repos.influxdata.com/debian stable main
  gpg --show-keys --with-colons /etc/apt/keyrings/influxdata.asc 2>/dev/null |
    grep -q "^fpr:*$fpr:" || {
    dot_sudo rm -f /etc/apt/sources.list.d/influxdata.sources /etc/apt/keyrings/influxdata.asc
    dot_die "the InfluxData key has an unexpected fingerprint, removed the repository again"
  }
fi
dot_pkg_install chronograf || dot_die "installing chronograf failed"

# the packages ship an empty file of that name
if dot_sudo test -s "$env" && ! dot_sudo grep -q 'written by chronograf.sh' "$env"; then
  dot_info "keeping $env (not written by chronograf.sh)"
else
  conn=$(influx_conn localhost)
  # the token is the last line: without one (2.x not set up by influxdb.sh, or not answering) no new connection
  case $conn in *INFLUXDB_TOKEN=) conn=; tokmsg=1 ;; esac
  # then the connection of an earlier run stays as it was
  old_conn=$(dot_sudo grep '^INFLUXDB_' "$env" 2>/dev/null)
  if [ -z "$conn" ] && [ -n "$old_conn" ]; then
    conn=$old_conn
    dot_info "no new connection to InfluxDB: keeping the one of the earlier run in $env"
  elif [ -n "${tokmsg:-}" ]; then
    dot_info "no InfluxDB token found: add the connection in the Chronograf UI"
  elif [ -z "$conn" ]; then
    dot_info "no InfluxDB on this machine: add the connection in the Chronograf UI"
  fi
  printf '# written by chronograf.sh\nHOST=%s\nPORT=%s\n%s\n' "$DOT_BIND" "$port" "$conn" | dot_sudo install -m 0600 /dev/stdin "$env" ||
    dot_die "could not write $env"
  [ -z "$conn" ] || dot_info "Chronograf connects to $(sed -n 's/^INFLUXDB_URL=//p' <<<"$conn")"
fi

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable chronograf && dot_sudo systemctl restart chronograf ||
    dot_die "chronograf does not start, see: journalctl -u chronograf"
else
  dot_info "no systemd running: start it with: sudo -u chronograf chronograf --host $DOT_BIND --port $port"
fi
dot_info "Chronograf $(dot_pkg_version chronograf) installed"
dot_summary chronograf "http://localhost:$port" "$login"
