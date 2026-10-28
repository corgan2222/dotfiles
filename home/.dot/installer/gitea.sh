#!/bin/bash
# installer: Gitea, self-hosted Git service with SQLite (release binary from GitHub, or Docker)
# systems: debian arch fedora rhel amd64 arm64
# modes: native compose portainer
# Installs the latest Gitea release binary from GitHub (sha256 checked) as /usr/local/bin/gitea, running as the system
# user git: data in /var/lib/gitea, config /etc/gitea/app.ini (SQLite, install wizard locked, sign-up off), gitea.service.
# Running it again replaces the binary with the latest release and keeps app.ini, the data and the admin password.
#   gitea.sh --docker | --portainer   image gitea/gitea:latest as compose project or Portainer stack "gitea" from
#                      /opt/gitea (data in /opt/gitea/data); running again pulls the newest image
#   GITEA_HTTP_PORT=3030   web UI (default 3030, Grafana has 3000)
#   GITEA_SSH_PORT=2222    Gitea's own SSH server for git over SSH (the host's sshd keeps 22)
#                      Both ports count on the first run only, later runs keep app.ini or compose.yaml.
#   GITEA_ADMIN_USER=gitadmin   admin made on the first run with a random password ("admin" is reserved in Gitea),
#                      kept root-only in /etc/gitea/admin-password (native) or /opt/gitea/.env (Docker)
#   --public / --local listen on all interfaces or on this host only (else asked, default all)
# Image tag latest, not 1: Gitea numbers its releases 28.x since 09.2026, gitea/gitea:1 stays on 1.27.
# category: dev
# ports: GITEA_HTTP_PORT=3030 GITEA_SSH_PORT=2222
# check: gitea.service stack:gitea
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

port=${GITEA_HTTP_PORT:-3030} ssh=${GITEA_SSH_PORT:-2222} user=${GITEA_ADMIN_USER:-gitadmin}
case $port:$ssh in *[!0-9:]*) dot_die "GITEA_HTTP_PORT and GITEA_SSH_PORT must be numbers" ;; esac
dot_mode_guard gitea gitea "$port" "$ssh"
dot_bind 0.0.0.0
dot_need curl
# the name in clone links; where this script reaches the web UI
host=$(hostname -f 2>/dev/null || hostname)
[ "$DOT_BIND" = 127.0.0.1 ] && host=localhost
here=$([ "$DOT_BIND" = 0.0.0.0 ] && echo localhost || echo "$DOT_BIND")

# creates the admin $user with password $1 unless Gitea has it already (false then); gt runs the gitea command line
gitea_admin() {
  gt admin user list --admin | awk 'NR > 1 { print $2 }' | grep -qx "$user" && return 1
  gt admin user create --admin --username "$user" --password "$1" --email "$user@localhost" \
    --must-change-password=false >/dev/null || dot_die "could not create the Gitea admin $user"
}

if [ "$DOT_MODE" != native ]; then
  dest=/opt/gitea envf=/opt/gitea/.env
  dot_sudo install -d -m 0755 "$dest/data" || exit 1
  # GITEA__section__KEY lines go into app.ini at every start (the image's environment-to-ini)
  dot_deploy gitea "services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    environment:
      GITEA__database__DB_TYPE: sqlite3
      GITEA__security__INSTALL_LOCK: \"true\"
      GITEA__service__DISABLE_REGISTRATION: \"true\"
      GITEA__server__ROOT_URL: http://$host:$port/
      GITEA__server__SSH_PORT: \"$ssh\"
    ports:
      - \"$DOT_BIND:$port:3000\"
      - \"$DOT_BIND:$ssh:22\"
    volumes:
      - $dest/data:/data"
  # the ports of the first run
  port=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):3000"$/\1/p' "$dest/compose.yaml")
  ssh=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):22"$/\1/p' "$dest/compose.yaml")
  dot_wait_http "http://$here:$port/api/healthz" 180 || dot_die "Gitea does not answer on port $port: sudo docker logs gitea"
  gt() { dot_sudo docker exec -u git gitea gitea "$@"; }
  if ! dot_sudo grep -q '^GITEA_ADMIN_PASSWORD=' "$envf" 2>/dev/null; then
    pw=$(dot_password 24)
    if gitea_admin "$pw"; then
      dot_env_set "$envf" GITEA_ADMIN_USER "$user" && dot_env_set "$envf" GITEA_ADMIN_PASSWORD "$pw" ||
        dot_die "could not write $envf"
    fi
  fi
  if dot_sudo grep -q '^GITEA_ADMIN_PASSWORD=' "$envf" 2>/dev/null; then
    login="user $(dot_sudo sed -n 's/^GITEA_ADMIN_USER=//p' "$envf"), password: GITEA_ADMIN_PASSWORD in $envf"
  else
    login="user $user existed before this installer, its password is unchanged"
  fi
  dot_summary gitea "http://localhost:$port localhost:$ssh" "$login"
  exit 0
fi

case $DOT_ARCH in amd64|arm64) ;; *) dot_die "this installer takes Gitea's amd64 and arm64 builds, not $DOT_ARCH" ;; esac
dot_need git
[ -d /run/systemd/system ] || dot_die "gitea.sh runs Gitea as a systemd service, systemd is not running here"
bin=/usr/local/bin/gitea ini=/etc/gitea/app.ini work=/var/lib/gitea pwf=/etc/gitea/admin-password
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
dot_github_fetch go-gitea/gitea "/gitea-[0-9.]+-linux-$DOT_ARCH\$" "$tmp/gitea" || dot_die "could not download Gitea"
old=$($bin --version 2>/dev/null | awk '{ print $3 }')
dot_sudo install -m 0755 "$tmp/gitea" "$bin" || dot_die "could not install $bin"
new=$($bin --version | awk '{ print $3 }')
[ "$old" = "$new" ] && dot_info "Gitea $new is up to date" || dot_info "Gitea ${old:-–} -> $new"

# user, folders and service as in Gitea's docs (installation from binary)
id git >/dev/null 2>&1 || dot_sudo useradd --system --shell /bin/bash --comment 'Git Version Control' \
  --create-home --home-dir /home/git --user-group git || dot_die "could not create the user git"
dot_sudo install -d -m 0750 -o git -g git "$work" "$work/custom" "$work/data" "$work/log" &&
  dot_sudo install -d -m 0750 -o root -g git /etc/gitea || dot_die "could not create the Gitea folders"
# the secrets are written here: Gitea would otherwise write them into app.ini itself, which stays read-only for git
if ! dot_sudo test -f "$ini"; then
  dot_sudo install -m 0640 -o root -g git /dev/stdin "$ini" <<EOF || dot_die "could not write $ini"
APP_NAME = Gitea
RUN_USER = git
RUN_MODE = prod
WORK_PATH = $work

[server]
PROTOCOL = http
HTTP_ADDR = $DOT_BIND
HTTP_PORT = $port
DOMAIN = $host
ROOT_URL = http://$host:$port/
START_SSH_SERVER = true
SSH_LISTEN_HOST = $DOT_BIND
SSH_PORT = $ssh
SSH_LISTEN_PORT = $ssh
LFS_START_SERVER = false

[database]
DB_TYPE = sqlite3
PATH = $work/data/gitea.db

[security]
INSTALL_LOCK = true
SECRET_KEY = $($bin generate secret SECRET_KEY)
INTERNAL_TOKEN = $($bin generate secret INTERNAL_TOKEN)

[oauth2]
JWT_SECRET = $($bin generate secret JWT_SECRET)

[service]
DISABLE_REGISTRATION = true

[log]
MODE = console
LEVEL = info
EOF
  dot_info "wrote $ini"
fi
# the ports of the first run
port=$(dot_sudo sed -n 's/^HTTP_PORT *= *//p' "$ini") ssh=$(dot_sudo sed -n 's/^SSH_LISTEN_PORT *= *//p' "$ini")

dot_sudo tee /etc/systemd/system/gitea.service >/dev/null <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=$work
ExecStart=$bin web --config $ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=$work

[Install]
WantedBy=multi-user.target
EOF
gt() { (cd / && dot_sudo runuser -u git -- "$bin" --config "$ini" --work-path "$work" "$@"); }
gt migrate >/dev/null || dot_die "gitea migrate failed"
dot_sudo systemctl daemon-reload && dot_sudo systemctl enable gitea && dot_sudo systemctl restart gitea ||
  dot_die "could not start gitea.service, see: journalctl -u gitea"
dot_wait_http "http://$here:${port:-3030}/api/healthz" 60 || dot_die "Gitea does not answer, see: journalctl -u gitea"

if ! dot_sudo test -s "$pwf"; then
  pw=$(dot_password 24)
  gitea_admin "$pw" && { printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$pwf'" || dot_die "could not write $pwf"; }
fi
if dot_sudo test -s "$pwf"; then login="user $user, password: sudo cat $pwf"
else login="user $user existed before this installer, its password is unchanged"; fi
dot_summary gitea "http://localhost:$port localhost:$ssh" "$login"
