#!/bin/bash
# installer: code-server, VS Code in the browser (coder's .deb or .rpm from GitHub, or Docker)
# systems: debian fedora rhel amd64 arm64
# modes: native compose portainer
# Installs the latest code-server release package from GitHub (sha256 checked) and runs it as the calling user with
# code-server@<user>.service; config ~/.config/code-server/config.yaml (written on the first run, then kept).
# Running it again updates the package and keeps config and password.
#   code_server.sh --docker | --portainer   image codercom/code-server:latest as compose project or Portainer stack
#                      "code-server" from /opt/code-server: config in /opt/code-server/config, extensions in
#                      /opt/code-server/local, the workspace /opt/code-server/project (all owned by uid 1000)
#   CODE_SERVER_PORT=8380   port of the web UI (default 8380, 8080 is often taken); counts on the first run only
#   CODE_SERVER_PASSWORD=…  password of the first run, else generated. There is no user, only the password. Kept in
#                      config.yaml (native) and, root-only, in /etc/code-server/password; Docker: /opt/code-server/.env
#   --public / --local listen on all interfaces or on this host only (else asked, default all)
# codercom/code-server, not lscr.io/linuxserver/code-server: it is the project's own image and reads the same
# config.yaml as the package, the linuxserver image has a layout and variables of its own.
# Whoever logs in gets a shell as that user: on all interfaces only behind TLS (a reverse proxy) or in a trusted network.
# category: dev
# ports: CODE_SERVER_PORT=8380
# check: code-server stack:code-server
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

port=${CODE_SERVER_PORT:-8380} pw=${CODE_SERVER_PASSWORD:-}
case $port in ''|*[!0-9]*) dot_die "CODE_SERVER_PORT must be a number, got '$port'" ;; esac
dot_secret_ok "$pw" || dot_die "CODE_SERVER_PASSWORD must not contain spaces, quotes, \$ or backslashes"
user=$(dot_user)
dot_mode_guard code-server "code-server@$user" "$port"
dot_bind 0.0.0.0
here=$([ "$DOT_BIND" = 0.0.0.0 ] && echo localhost || echo "$DOT_BIND")

if [ "$DOT_MODE" != native ]; then
  dest=/opt/code-server
  dot_sudo install -d -m 0755 -o 1000 -g 1000 "$dest/config" "$dest/config/code-server" "$dest/local" "$dest/project" ||
    exit 1
  # the password comes from PASSWORD in .env, which beats config.yaml; the container listens on 8080 inside
  printf 'bind-addr: 0.0.0.0:8080\nauth: password\ncert: false\n# password: PASSWORD in %s/.env\n' "$dest" |
    dot_put_new "$dest/config/code-server/config.yaml"
  dot_sudo chown 1000:1000 "$dest/config/code-server/config.yaml"
  dot_deploy code-server "services:
  code-server:
    image: codercom/code-server:latest
    container_name: code-server
    restart: unless-stopped
    environment:
      PASSWORD: \${PASSWORD}
    ports:
      - \"$DOT_BIND:$port:8080\"
    volumes:
      - $dest/config:/home/coder/.config
      - $dest/local:/home/coder/.local
      - $dest/project:/home/coder/project" "PASSWORD=${pw:-$(dot_password 24)}"
  port=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):8080"$/\1/p' "$dest/compose.yaml")
  dot_wait_http "http://$here:$port/healthz" 60 || dot_die "code-server does not answer on port $port: sudo docker logs code-server"
  dot_summary code-server "http://localhost:$port" "password only (no user), password: PASSWORD in $dest/.env"
  exit 0
fi

case $DOT_PKG in
  apt) asset="_${DOT_ARCH}\\.deb\$" ext=deb ;;
  dnf|yum) asset="-${DOT_ARCH}\\.rpm\$" ext=rpm ;;
  *) dot_die "code-server has .deb and .rpm packages only, run it in Docker here: code_server.sh --docker" ;;
esac
case $DOT_ARCH in amd64|arm64) ;; *) dot_die "code-server has no package for $DOT_ARCH" ;; esac
[ -d /run/systemd/system ] || dot_die "code-server runs as a systemd service, systemd is not running here"
home=$(dot_user_home "$user")
[ -d "$home" ] || dot_die "no home directory for $user"
dot_need curl
old=$(dot_pkg_version code-server) tag=$(dot_github_latest coder/code-server) || dot_die "cannot read the latest code-server release"
if [ "${old%%-*}" = "${tag#v}" ]; then
  dot_info "code-server $old is up to date"
else
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_github_fetch coder/code-server "$asset" "$tmp/code-server.$ext" "$tag" || dot_die "could not download code-server"
  # apt reads the .deb as its sandbox user _apt
  chmod 755 "$tmp" && chmod 644 "$tmp/code-server.$ext"
  dot_pkg_install "$tmp/code-server.$ext" || dot_die "installing the code-server package failed"
  dot_info "code-server ${old:-–} -> ${tag#v}"
fi

# config.yaml of the user, owned by the user (code-server reads it as that user); the password also root-only in $pwf
conf=$home/.config/code-server/config.yaml pwf=/etc/code-server/password
group=$(id -gn "$user")
if ! dot_sudo test -f "$conf"; then
  [ -n "$pw" ] || pw=$(dot_password 24)
  dot_sudo install -d -o "$user" -g "$group" "$home/.config" "$home/.config/code-server" &&
    printf 'bind-addr: %s:%s\nauth: password\npassword: %s\ncert: false\n' "$DOT_BIND" "$port" "$pw" |
    dot_sudo install -m 0600 -o "$user" -g "$group" /dev/stdin "$conf" || dot_die "could not write $conf"
  dot_info "wrote $conf"
fi
pw=$(dot_sudo sed -n 's/^password: *//p' "$conf") p=$(dot_sudo sed -n 's/^bind-addr: *//p' "$conf")
port=${p##*:}
if [ -n "$pw" ]; then
  dot_sudo install -d -m 0700 /etc/code-server &&
    printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$pwf'" || dot_die "could not write $pwf"
  login="password only (no user), password: sudo cat $pwf"
else
  login="as configured in $conf (auth: none or hashed-password)"
fi

dot_sudo systemctl enable "code-server@$user" >/dev/null 2>&1 && dot_sudo systemctl restart "code-server@$user" ||
  dot_die "could not start code-server@$user, see: journalctl -u code-server@$user"
dot_wait_http "http://$here:$port/healthz" 60 || dot_die "code-server does not answer on port $port, see: journalctl -u code-server@$user"
dot_summary code-server "http://localhost:$port" "$login" "code-server@$user"
