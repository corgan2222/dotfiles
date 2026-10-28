#!/bin/bash
# installer: Apache Superset data exploration and dashboards with PostgreSQL and Redis (Docker)
# systems: amd64
# modes: compose portainer
# Runs apache/superset:latest-dev with postgres:17-alpine (metadata) and redis:alpine (cache, rate limits) as compose
# project or Portainer stack "superset" from /opt/superset; installs Docker through docker.sh when it is missing.
# The one-shot container superset-init runs "superset db upgrade", "superset fab create-admin" and "superset init" on
# every deploy, the web server starts after it. Running again keeps .env, compose.yaml and superset_config.py and
# pulls newer images; superset-init then migrates the metadata database.
# latest-dev, not latest: since 4.1 the lean image "latest" has no database driver, not even psycopg2 for its own
# metadata database; the vendor's docker-compose-image-tag.yml of release 6.1.0 runs latest-dev, which has it.
# No Celery worker: alerts, reports and async queries stay off (add a worker by the vendor's compose file to use them).
#   SUPERSET_PORT=8088       HTTP port of the first run (default 8088)
#   --public / --local       all interfaces or this host only (first run, else asked)
# SUPERSET_SECRET_KEY (signs sessions, encrypts stored database passwords: keep it), the database password and the
# password of the user admin are generated into /opt/superset/.env (0600).
# category: db
# ports: SUPERSET_PORT=8088
# check: stack:superset
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/superset
image=apache/superset:latest-dev
port=${SUPERSET_PORT:-8088}
case $port in ''|*[!0-9]*) dot_die "SUPERSET_PORT must be a number, got '$port'" ;; esac
dot_need curl
dot_mode_guard superset superset "$port"
dot_bind 0.0.0.0
dot_sudo install -d -m 0755 "$dest" || exit 1

# the config reads its secrets from the environment, the file itself holds none
dot_put_new "$dest/superset_config.py" <<'EOF'
# Superset config of the superset stack, written by superset.sh on the first run; secrets come from .env
import os

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]
SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://superset:%s@db:5432/superset" % os.environ["POSTGRES_PASSWORD"]

_REDIS = "redis://redis:6379"
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_URL": _REDIS + "/1",
}
DATA_CACHE_CONFIG = CACHE_CONFIG
RATELIMIT_STORAGE_URI = _REDIS + "/2"
EOF

# create-admin of an existing user only says so; "|| true" keeps the migrations of a later run going
dot_deploy superset "x-superset: &superset
  image: $image
  environment:
    SUPERSET_SECRET_KEY: \${SUPERSET_SECRET_KEY}
    POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
  volumes:
    - $dest/superset_config.py:/app/pythonpath/superset_config.py:ro
    - home:/app/superset_home
services:
  db:
    image: postgres:17-alpine
    container_name: superset-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: superset
      POSTGRES_USER: superset
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - db:/var/lib/postgresql/data
    healthcheck:
      test: [\"CMD\", \"pg_isready\", \"-U\", \"superset\", \"-d\", \"superset\"]
      interval: 5s
      retries: 30
  redis:
    image: redis:alpine
    container_name: superset-redis
    restart: unless-stopped
  init:
    <<: *superset
    container_name: superset-init
    restart: \"no\"
    depends_on:
      db: {condition: service_healthy}
      redis: {condition: service_started}
    environment:
      SUPERSET_SECRET_KEY: \${SUPERSET_SECRET_KEY}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      ADMIN_PASSWORD: \${SUPERSET_ADMIN_PASSWORD}
    command: [\"sh\", \"-c\", \"superset db upgrade && (superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@example.org --password \\\"\$\$ADMIN_PASSWORD\\\" || true) && superset init\"]
  app:
    <<: *superset
    container_name: superset
    restart: unless-stopped
    depends_on:
      init: {condition: service_completed_successfully}
    ports:
      - \"$DOT_BIND:$port:8088\"
volumes:
  db:
  home:" "SUPERSET_SECRET_KEY=$(dot_password 48)
POSTGRES_PASSWORD=$(dot_password 24)
SUPERSET_ADMIN_PASSWORD=$(dot_password 24)"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8088"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Superset keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
# DOT_NO_START: nothing runs that could answer (28.10.26: it died on the missing superset-init)
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary superset "http://localhost:$port" "user admin, password: SUPERSET_ADMIN_PASSWORD in $dest/.env"
  exit 0
fi
[ "$(dot_sudo docker inspect -f '{{.State.ExitCode}}' superset-init 2>/dev/null)" = 0 ] ||
  dot_die "superset-init failed, see: sudo docker logs superset-init"
dot_wait_http "$url/health" 180 || dot_die "Superset does not answer on $url, see: sudo docker logs superset"

# the admin login through the API; the password goes to curl on stdin, not on its command line
pw=$(dot_sudo sed -n 's/^SUPERSET_ADMIN_PASSWORD=//p' "$dest/.env")
if printf '{"username":"admin","password":"%s","provider":"db","refresh":false}' "$pw" |
  curl -fsS -m 20 -H 'Content-Type: application/json' -d @- "$url/api/v1/security/login" | grep -q '"access_token"'; then
  dot_info "admin login checked through the API"
else
  echo "warning: the admin login from $dest/.env does not work (password changed in Superset?)" >&2
fi

dot_summary superset "http://localhost:$port" "user admin, password: SUPERSET_ADMIN_PASSWORD in $dest/.env"
