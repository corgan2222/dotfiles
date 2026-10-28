#!/bin/bash
# installer: Nextcloud file sync and share with PostgreSQL, Redis and cron (Docker)
# systems: amd64
# modes: compose portainer
# Runs nextcloud:stable-apache, postgres:17-alpine, redis:alpine and a cron container (the same Nextcloud image with
# /cron.sh, background jobs every 5 minutes) as compose project or Portainer stack "nextcloud" from /opt/nextcloud;
# installs Docker through docker.sh when it is missing. Files and database live in the volumes html and db.
# Waits until Nextcloud has installed itself (a few minutes on the first run), switches background jobs to cron and
# checks the admin login through the OCS API. Running again keeps .env and compose.yaml and pulls newer images;
# Nextcloud upgrades itself on the start of a newer image.
#   NEXTCLOUD_TRUSTED_DOMAINS="cloud.example.org 192.0.2.10"   names and addresses the web UI answers to, besides
#                                localhost and this host's first IP (first run; later: occ config:system:set)
#   NEXTCLOUD_PORT=8090          HTTP port of the first run (default 8090)
#   NEXTCLOUD_ADMIN_USER=admin   admin account of the first run (default admin), password generated
#   --public / --local           all interfaces or this host only (first run, else asked)
# PostgreSQL, not MariaDB: it needs no server options (MariaDB wants READ-COMMITTED and binlog_format ROW), and the
# image tag 17 stays inside the versions Nextcloud supports while mariadb:lts may move past them.
# Passwords (database, admin) in /opt/nextcloud/.env (0600). Behind a reverse proxy with HTTPS set
# overwriteprotocol and trusted_proxies with occ, see the Nextcloud admin manual "Reverse proxy".
# category: server
# ports: NEXTCLOUD_PORT=8090
# check: stack:nextcloud
# ask: NEXTCLOUD_TRUSTED_DOMAINS=localhost "Host names or IPs for the web UI, space-separated, e.g. cloud.example.org 192.0.2.10 (localhost and this host's IP are added)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/nextcloud
port=${NEXTCLOUD_PORT:-8090}
case $port in ''|*[!0-9]*) dot_die "NEXTCLOUD_PORT must be a number, got '$port'" ;; esac
admin=${NEXTCLOUD_ADMIN_USER:-admin}
case $admin in ''|*[!A-Za-z0-9_.@-]*) dot_die "NEXTCLOUD_ADMIN_USER may hold letters, digits and _ . @ - only" ;; esac
# this host's address for the LAN, then the given names, each once; the image's install sets localhost itself
# (trusted_domains 0, also used by the checks below) and appends these
domains=
for d in $(hostname -I 2>/dev/null | awk '{print $1}') ${NEXTCLOUD_TRUSTED_DOMAINS:-}; do
  case " localhost $domains " in *" $d "*) ;; *) domains="${domains:+$domains }$d" ;; esac
done
case $domains in *[\$\'\"\\]*) dot_die "NEXTCLOUD_TRUSTED_DOMAINS must not contain quotes, \$ or backslashes" ;; esac
dot_need curl
dot_mode_guard nextcloud nextcloud "$port"
dot_bind 0.0.0.0

dot_deploy nextcloud "services:
  db:
    image: postgres:17-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - db:/var/lib/postgresql/data
  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: unless-stopped
  app:
    image: nextcloud:stable-apache
    container_name: nextcloud
    restart: unless-stopped
    depends_on: [db, redis]
    ports:
      - \"$DOT_BIND:$port:80\"
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      NEXTCLOUD_ADMIN_USER: \${NEXTCLOUD_ADMIN_USER}
      NEXTCLOUD_ADMIN_PASSWORD: \${NEXTCLOUD_ADMIN_PASSWORD}
      NEXTCLOUD_TRUSTED_DOMAINS: \"$domains\"
      REDIS_HOST: redis
    volumes:
      - html:/var/www/html
  cron:
    image: nextcloud:stable-apache
    container_name: nextcloud-cron
    restart: unless-stopped
    entrypoint: /cron.sh
    depends_on: [db, redis]
    volumes:
      - html:/var/www/html
volumes:
  db:
  html:" "POSTGRES_PASSWORD=$(dot_password 24)
NEXTCLOUD_ADMIN_USER=$admin
NEXTCLOUD_ADMIN_PASSWORD=$(dot_password 24)"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):80"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Nextcloud keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
# DOT_NO_START: nothing runs that could answer (28.10.26: it waited 15 minutes and died)
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary nextcloud "http://localhost:$port" "user $admin, password: NEXTCLOUD_ADMIN_PASSWORD in $dest/.env"
  exit 0
fi

# the image copies Nextcloud into the volume and installs it on the first start, upgrades on the start of a newer one;
# status.php says when it is done
end=$((SECONDS + 900))
until s=$(curl -fsS -m 10 "$url/status.php" 2>/dev/null) && [[ $s == *'"installed":true'* ]] &&
  [[ $s == *'"maintenance":false'* ]] && [[ $s == *'"needsDbUpgrade":false'* ]]; do
  [ "$SECONDS" -lt "$end" ] || { dot_progress_end; dot_die "Nextcloud is not ready after 15 minutes, see: sudo docker logs nextcloud"; }
  dot_progress 0 0 "Nextcloud installs itself"
  sleep 3
done
dot_progress_end
dot_info "Nextcloud $(sed -n 's/.*"versionstring":"\([^"]*\)".*/\1/p' <<<"$s") is ready"

# background jobs from the cron container instead of on page loads (AJAX)
dot_sudo docker exec -u www-data nextcloud php occ background:cron >/dev/null ||
  echo "warning: could not switch background jobs to cron: sudo docker exec -u www-data nextcloud php occ background:cron" >&2

# the admin login from .env, through the OCS API; the password goes to curl on stdin, not on its command line
user=$(dot_sudo sed -n 's/^NEXTCLOUD_ADMIN_USER=//p' "$dest/.env")
if printf 'user = "%s:%s"\n' "$user" "$(dot_sudo sed -n 's/^NEXTCLOUD_ADMIN_PASSWORD=//p' "$dest/.env")" |
  curl -fsS -m 20 -K - -H 'OCS-APIRequest: true' "$url/ocs/v2.php/cloud/user?format=json" | grep -q "\"id\":\"$user\""; then
  dot_info "admin login checked through the OCS API"
else
  echo "warning: the admin login from $dest/.env does not work (password changed in Nextcloud?)" >&2
fi

trusted=$(dot_sudo docker exec -u www-data nextcloud php occ config:system:get trusted_domains 2>/dev/null | paste -sd ' ')
dot_summary nextcloud "http://localhost:$port" \
  "user $user, password: NEXTCLOUD_ADMIN_PASSWORD in $dest/.env; trusted domains: ${trusted:-$domains}"
