#!/bin/bash
# installer: PatchMon patch monitoring for Linux hosts, server with web UI (Docker); agents from its UI
# systems: amd64 arm64
# modes: compose portainer
# Runs the PatchMon server (ghcr.io/patchmon/patchmon-server:latest, API and web UI in one) with postgres:17-alpine
# and redis:7-alpine as compose project or Portainer stack "patchmon" from /opt/patchmon; installs Docker through
# docker.sh when it is missing. Upstream supports Docker only since 2.0 (its setup.sh refuses a native install).
# Database and Redis live in the volumes postgres_data and redis_data. Running again keeps .env and compose.yaml and
# pulls newer images; the server migrates its database on start.
#   PATCHMON_PORT=7130          HTTP port of the first run (upstream 3000, taken here)
#   PATCHMON_URL=https://patchmon.example.org   the address behind a reverse proxy (first run): allowed as browser
#                               origin (CORS_ORIGIN) besides localhost and this host's IP, and TRUST_PROXY=true
#   PATCHMON_ADMIN_USER=admin PATCHMON_ADMIN_EMAIL=admin@example.org   the superadmin the first run creates
#   --public / --local          all interfaces or this host only (first run, default this host)
# The first run creates the superadmin through the API of the first-time wizard (POST /api/v1/auth/setup-admin), so
# nobody else can claim the open wizard; user:password in /opt/patchmon/admin-credentials (0600), database, Redis
# and session secrets in /opt/patchmon/.env (0600).
# Agents: in the web UI set Settings > Server URL to the address the hosts reach, then Hosts > Add Host shows a
# "curl … /api/v1/hosts/install -H X-API-ID … | sudo sh" line per host to run there; Settings > Integrations has
# auto-enrolment tokens for many hosts and Proxmox LXC. No guacd: in-browser RDP to Windows hosts needs it added.
# category: monitoring
# ports: PATCHMON_PORT=7130
# check: stack:patchmon
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose
case ${1:-} in
  -h|--help) sed -n '5,20s/^# \{0,1\}//p' "$0"; exit 0 ;;
  "") ;;
  *) dot_die "unknown option $1" ;;
esac

dest=/opt/patchmon
credf=$dest/admin-credentials
port=${PATCHMON_PORT:-7130}
case $port in ''|*[!0-9]*) dot_die "PATCHMON_PORT must be a number, got '$port'" ;; esac
purl=${PATCHMON_URL:-}
case $purl in ''|http://*|https://*) ;; *) dot_die "PATCHMON_URL must start with http:// or https://" ;; esac
purl=${purl%/}
# the superadmin of the first run; later runs keep the stored one
admin=$(dot_sudo cut -d: -f1 "$credf" 2>/dev/null)
admin=${admin:-${PATCHMON_ADMIN_USER:-admin}}
email=${PATCHMON_ADMIN_EMAIL:-$admin@example.org}
case $admin$purl$email in
  *[!A-Za-z0-9_.@:/-]*) dot_die "PATCHMON_URL, _ADMIN_USER and _ADMIN_EMAIL: letters, digits and _ . @ : / - only" ;;
esac
dot_need curl jq
dot_mode_guard patchmon patchmon "$port"
# a web UI with the whole fleet's inventory: this host only unless asked; a later run keeps the address it has
old=$(dot_sudo sed -n 's/^ *- "\(.*\):3000"$/\1/p' "$dest/compose.yaml" 2>/dev/null)
case $old in *:*) dot_bind 127.0.0.1 "${old%:*}" ;; ?*) dot_bind 127.0.0.1 0.0.0.0 ;; *) dot_bind 127.0.0.1 ;; esac

# the browser origins the API accepts: localhost and this host's IP on the port, the proxy address
read -r ip _ < <(hostname -I 2>/dev/null)
cors=http://localhost:$port${ip:+,http://$ip:$port}${purl:+,$purl}

dot_deploy patchmon "services:
  server:
    image: ghcr.io/patchmon/patchmon-server:latest
    container_name: patchmon
    # a stable name for the agent presence registry, the container id changes with every update (upstream compose)
    hostname: patchmon-server
    restart: unless-stopped
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - \"$DOT_BIND:$port:3000\"
    environment:
      DATABASE_URL: postgresql://patchmon:\${POSTGRES_PASSWORD}@database:5432/patchmon
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: \${REDIS_PASSWORD}
      JWT_SECRET: \${JWT_SECRET}
      SESSION_SECRET: \${SESSION_SECRET}
      AI_ENCRYPTION_KEY: \${AI_ENCRYPTION_KEY}
      CORS_ORIGIN: \${CORS_ORIGIN}
      TRUST_PROXY: \${TRUST_PROXY}
  database:
    image: postgres:17-alpine
    container_name: patchmon-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: patchmon
      POSTGRES_USER: patchmon
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U patchmon -d patchmon\"]
      interval: 3s
      timeout: 5s
      retries: 20
  redis:
    image: redis:7-alpine
    container_name: patchmon-redis
    restart: unless-stopped
    # the password from the container's environment: interpolated into the command, docker inspect would show it;
    # redis-cli in the health check reads REDISCLI_AUTH
    command: [\"sh\", \"-c\", \"exec redis-server --requirepass \\\"\$\$REDISCLI_AUTH\\\"\"]
    environment:
      REDISCLI_AUTH: \${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: [\"CMD-SHELL\", \"redis-cli ping | grep -q PONG\"]
      interval: 3s
      timeout: 5s
      retries: 20
volumes:
  postgres_data:
  redis_data:" "POSTGRES_PASSWORD=$(dot_password 32)
REDIS_PASSWORD=$(dot_password 32)
JWT_SECRET=$(dot_password 64)
SESSION_SECRET=$(dot_password 64)
AI_ENCRYPTION_KEY=$(dot_password 64)
CORS_ORIGIN=$cors
TRUST_PROXY=$([ -n "$purl" ] && echo true || echo false)"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):3000"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: PatchMon keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
login="user $admin, password: sudo cat $credf (user:password); agents: Settings > Server URL, then Hosts > Add Host"
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary patchmon "http://localhost:$port${purl:+ $purl}" "$login (made by a run without DOT_NO_START)"
  exit 0
fi
# the server waits for the database and Redis and migrates on start; /health answers "healthy" then
dot_wait_http "$url/health" 300 || dot_die "PatchMon does not answer on $url, see: sudo docker logs patchmon"

# prints the JSON of username and password for the API, the password from stdin
creds_json() { jq -Rc --arg u "$1" '{username: $u, password: .}'; }
if ! dot_sudo test -s "$credf"; then
  # the default password policy wants upper and lower case, a digit and a special character
  pw=
  until [[ $pw =~ [A-Z] && $pw =~ [a-z] && $pw =~ [0-9] ]]; do pw=$(dot_password 24); done
  pw+=-
  r=$(printf '%s' "$pw" | creds_json "$admin" | jq -c --arg e "$email" '. + {firstName: "Patch", lastName: "Admin",
    email: $e}' | curl -sS -m 30 -H 'Content-Type: application/json' --data @- -w '\n%{http_code}' \
    "$url/api/v1/auth/setup-admin") || dot_die "PatchMon's API does not answer on $url"
  case ${r##*$'\n'} in
    201) printf '%s:%s\n' "$admin" "$pw" | dot_sudo sh -c "umask 077; cat > '$credf'" || exit 1
         dot_info "superadmin $admin created" ;;
    *) case $r in
         *"already exist"*) echo "warning: PatchMon has a superadmin already (made in the browser?), log in with it" >&2
                            login="the superadmin made in the browser" ;;
         *) dot_die "PatchMon did not create the superadmin: ${r%$'\n'*}" ;;
       esac ;;
  esac
fi

# the stored login against the API
if dot_sudo test -s "$credf"; then
  if dot_sudo sed 's/^[^:]*://' "$credf" | tr -d '\n' | creds_json "$admin" |
    curl -fsS -m 20 -H 'Content-Type: application/json' --data @- "$url/api/v1/auth/login" | grep -q '"token"'; then
    dot_info "admin login checked through the API"
  else
    echo "warning: the login in $credf does not work (password changed in PatchMon?)" >&2
  fi
fi
dot_summary patchmon "http://localhost:$port${purl:+ $purl}" "$login"
