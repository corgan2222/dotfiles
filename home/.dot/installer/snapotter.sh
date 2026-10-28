#!/bin/bash
# installer: SnapOtter file processing (convert, compress, OCR, transcribe, local AI) with PostgreSQL and Redis (Docker)
# systems: amd64 arm64
# modes: compose portainer
# Runs snapotter/snapotter:2, postgres:17-alpine and redis:8-alpine (the stack of SnapOtter's deployment guide) as
# compose project or Portainer stack "snapotter" from /opt/snapotter; installs Docker through docker.sh when it is
# missing. Files, AI models, database and queue live in the volumes data, workspace, pgdata and redisdata.
# Docker only: SnapOtter ships as an image only (ffmpeg, LibreOffice, Tesseract and Python models inside).
# The image is big: about 3.8 GB to download on amd64 (CUDA inside), 1.9 GB on arm64; the app may use up to 6 GB RAM
# (its own limit, the HQ mode of erase-object needs 8 GB).
#   snapotter.sh
#   SNAPOTTER_PORT=1349            HTTP port of the first run (default 1349)
#   SNAPOTTER_ADMIN_USER=admin     admin account of the first run (default admin), password generated
#   --public / --local             all interfaces or this host only (first run, else asked; default this host)
# Upstream's default login is admin/admin with a forced change; here the password is random and stays valid
# (SKIP_MUST_CHANGE_PASSWORD), so the one in /opt/snapotter/.env (0600) works until it is changed in the web UI.
# Product analytics (PostHog, Sentry) are on upstream by default, here off (SNAPOTTER_TELEMETRY=0 in compose.yaml).
# Running again keeps .env and compose.yaml and pulls newer images of major version 2.
# category: server
# ports: SNAPOTTER_PORT=1349
# check: stack:snapotter
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/snapotter
port=${SNAPOTTER_PORT:-1349}
case $port in ''|*[!0-9]*) dot_die "SNAPOTTER_PORT must be a number, got '$port'" ;; esac
admin=${SNAPOTTER_ADMIN_USER:-admin}
case $admin in ''|*[!A-Za-z0-9_.@-]*) dot_die "SNAPOTTER_ADMIN_USER may hold letters, digits and _ . @ - only" ;; esac
dot_need curl
dot_mode_guard snapotter snapotter "$port"
# the address of an earlier run, so that running again keeps it
old=$(dot_sudo sed -n 's/^ *- "\(.*\):[0-9]*:1349"$/\1/p' /opt/snapotter/compose.yaml 2>/dev/null)
dot_bind 127.0.0.1 "$old"

# Redis without a password, as in the deployment guide: it is published nowhere, only the stack's network reaches it,
# and --requirepass would put the password into the process list of the host
dot_deploy snapotter "services:
  app:
    image: snapotter/snapotter:2
    container_name: snapotter
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:1349\"
    environment:
      AUTH_ENABLED: \"true\"
      DEFAULT_USERNAME: \${SNAPOTTER_ADMIN_USER}
      DEFAULT_PASSWORD: \${SNAPOTTER_ADMIN_PASSWORD}
      SKIP_MUST_CHANGE_PASSWORD: \"true\"
      SNAPOTTER_TELEMETRY: \"0\"
      DATABASE_URL: postgres://snapotter:\${POSTGRES_PASSWORD}@postgres:5432/snapotter
      REDIS_URL: redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - data:/data
      - workspace:/tmp/workspace
    shm_size: 2gb
    mem_limit: 6g
  postgres:
    image: postgres:17-alpine
    container_name: snapotter-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: snapotter
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: snapotter
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U snapotter -d snapotter']
      interval: 10s
      timeout: 5s
      retries: 12
  redis:
    image: redis:8-alpine
    container_name: snapotter-redis
    restart: unless-stopped
    command: [redis-server, --maxmemory-policy, noeviction, --appendonly, 'yes']
    volumes:
      - redisdata:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 12
volumes:
  data:
  workspace:
  pgdata:
  redisdata:" "POSTGRES_PASSWORD=$(dot_password 24)
SNAPOTTER_ADMIN_USER=$admin
SNAPOTTER_ADMIN_PASSWORD=$(dot_password 24)"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):1349"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: SnapOtter keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
user=$(dot_sudo sed -n 's/^SNAPOTTER_ADMIN_USER=//p' "$dest/.env")
login="user $user, password: SNAPOTTER_ADMIN_PASSWORD in $dest/.env"
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary snapotter "http://localhost:$port" "$login"
  exit 0
fi
# migrations and the first start of the workers take a while (upstream's healthcheck allows 60 s)
dot_wait_http "$url/api/v1/health" 300 || dot_die "SnapOtter does not answer on $url, see: sudo docker logs snapotter"

# the admin login from .env; the password goes to curl on stdin, not on its command line (letters and digits only,
# the JSON needs no escaping)
pw=$(dot_sudo sed -n 's/^SNAPOTTER_ADMIN_PASSWORD=//p' "$dest/.env")
if printf '{"username":"%s","password":"%s"}' "$user" "$pw" |
  curl -sS -m 20 -H 'Content-Type: application/json' --data-binary @- "$url/api/auth/login" | grep -q '"token"'; then
  dot_info "admin login checked"
else
  echo "warning: the login from $dest/.env does not work (password changed in SnapOtter?)" >&2
fi
dot_summary snapotter "http://localhost:$port" "$login"
