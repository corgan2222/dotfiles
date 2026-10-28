#!/bin/bash
# installer: Zipline file, image and link sharing server for ShareX and Flameshot, with PostgreSQL (Docker)
# systems: amd64 arm64
# modes: compose portainer
# Runs ghcr.io/diced/zipline:latest and postgres:16 (the pair of Zipline's own docker-compose.yml) as compose project
# or Portainer stack "zipline" from /opt/zipline; installs Docker through docker.sh when it is missing. Uploads in
# /opt/zipline/uploads, the database in the volume pgdata.
# Docker only: Zipline publishes no release binaries, natively it is a source build with Node.js, pnpm and ffmpeg
# plus a PostgreSQL server of its own, and its docs name Docker the recommended way.
#   zipline.sh
#   ZIPLINE_PORT=7201              HTTP port of the first run (default 7201: upstream's 3000 is Grafana's)
#   ZIPLINE_ADMIN_USER=admin       super admin of the first run (default admin), password generated
#   --public / --local             all interfaces or this host only (first run, else asked; default this host)
# The first run creates the super admin through /api/setup, as the setup page in the browser would; without it the
# first visitor of the web UI becomes super admin. Passwords and CORE_SECRET (signs the sessions, at least 32
# characters) in /opt/zipline/.env (0600). Running again keeps .env and compose.yaml and pulls newer images.
# ShareX: Settings → "Generate Uploaders" in the web UI writes the .sxcu file. Behind a reverse proxy with HTTPS
# turn on "Return HTTPS URLs" and set the default domain under Server Settings → Core.
# category: server
# ports: ZIPLINE_PORT=7201
# check: stack:zipline
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/zipline
port=${ZIPLINE_PORT:-7201}
case $port in ''|*[!0-9]*) dot_die "ZIPLINE_PORT must be a number, got '$port'" ;; esac
admin=${ZIPLINE_ADMIN_USER:-admin}
case $admin in ''|*[!A-Za-z0-9_.@-]*) dot_die "ZIPLINE_ADMIN_USER may hold letters, digits and _ . @ - only" ;; esac
dot_need curl
dot_mode_guard zipline zipline "$port"
# the address of an earlier run, so that running again keeps it
old=$(dot_sudo sed -n 's/^ *- "\(.*\):[0-9]*:3000"$/\1/p' /opt/zipline/compose.yaml 2>/dev/null)
dot_bind 127.0.0.1 "$old"

# no env_file as upstream has it: that would hand the admin password in .env to the container as well
dot_deploy zipline "services:
  postgresql:
    image: postgres:16
    container_name: zipline-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: zipline
      POSTGRES_PASSWORD: \${POSTGRESQL_PASSWORD}
      POSTGRES_DB: zipline
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD', 'pg_isready', '-U', 'zipline']
      interval: 10s
      timeout: 5s
      retries: 5
  zipline:
    image: ghcr.io/diced/zipline:latest
    container_name: zipline
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:3000\"
    environment:
      CORE_SECRET: \${CORE_SECRET}
      DATABASE_URL: postgres://zipline:\${POSTGRESQL_PASSWORD}@postgresql:5432/zipline
    depends_on:
      postgresql:
        condition: service_healthy
    volumes:
      - $dest/uploads:/zipline/uploads
      - $dest/public:/zipline/public
      - $dest/themes:/zipline/themes
volumes:
  pgdata:" "POSTGRESQL_PASSWORD=$(dot_password 24)
CORE_SECRET=$(dot_password 48)
ZIPLINE_ADMIN_USER=$admin
ZIPLINE_ADMIN_PASSWORD=$(dot_password 24)"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):3000"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Zipline keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
user=$(dot_sudo sed -n 's/^ZIPLINE_ADMIN_USER=//p' "$dest/.env")
login="user $user, password: ZIPLINE_ADMIN_PASSWORD in $dest/.env"
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary zipline "http://localhost:$port" "$login (created by a run without DOT_NO_START)"
  exit 0
fi
# the database migrations run on the first start
dot_wait_http "$url/api/healthcheck" 180 || dot_die "Zipline does not answer on $url, see: sudo docker logs zipline"

# the password goes to curl on stdin, not on its command line; dot_password makes letters and digits only, the
# JSON needs no escaping
creds() {
  printf '{"username":"%s","password":"%s"}' "$user" "$(dot_sudo sed -n 's/^ZIPLINE_ADMIN_PASSWORD=//p' "$dest/.env")"
}
# prints the HTTP status of a POST of the login to path $1
post() {
  creds | curl -sS -m 20 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' --data-binary @- "$url$1"
}
# GET /api/setup answers 200 only while nobody has set Zipline up
if [ "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$url/api/setup")" = 200 ]; then
  [ "$(post /api/setup)" = 200 ] || dot_die "Zipline's first setup failed, see: sudo docker logs zipline"
  dot_info "created the super admin $user"
fi
if [ "$(post /api/auth/login)" = 200 ]; then
  dot_info "admin login checked"
else
  echo "warning: the login from $dest/.env does not work (password changed in Zipline?)" >&2
fi
dot_summary zipline "http://localhost:$port" "$login"
