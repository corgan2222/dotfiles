#!/bin/bash
# installer: Node-RED (latest, npm global) as a systemd service of the calling user, or in Docker
# systems: debian arch fedora rhel amd64 arm64 armv7
# modes: native compose portainer
# Installs the latest Node-RED globally with npm on Node.js LTS (nodejs.sh when node is missing or older than
# Node-RED's engines field), and the service nodered.service from Node-RED's "running as a service" docs,
# running as the calling user with the user directory ~/.node-red. Running it again updates Node-RED.
#   nodered.sh                    editor on port 1880
#   NODERED_PORT=1881 nodered.sh  another port
#   nodered.sh --docker           in Docker instead (image nodered/node-red, user directory /opt/nodered/data,
#                                 compose file /opt/nodered/compose.yaml); --portainer as a stack in the local Portainer
#   --public / --local            editor on all interfaces (default) or on this host only (uiHost)
#   NODERED_PASSWORD=…            password of the editor login admin, else the stored one or generated; stored in
#                                 /etc/nodered/credentials (Docker: /opt/nodered/credentials), root only.
#                                 A settings.js with an adminAuth of its own is left alone.
# Needs about 256 MB RAM (the unit caps the heap at 512 MB).
# category: server
# ports: NODERED_PORT=1880
# check: nodered.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
dot_bind 0.0.0.0

port=${NODERED_PORT:-1880}
case $port in ''|*[!0-9]*) dot_die "NODERED_PORT must be a number, got '$port'" ;; esac

# prints the bcrypt hash of the password on stdin, made with the bcryptjs that Node-RED itself ships ($nr: its package)
hash_pw() {
  local js='let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(require(require.resolve("bcryptjs",{paths:[process.argv[1]]})).hashSync(s,8)))'
  if [ "$DOT_MODE" = native ]; then
    node -e "$js" "$nr/node_modules/@node-red/editor-api"
  else
    dot_sudo docker run --rm -i --entrypoint node "$image" -e "$js" "$nr/node_modules/@node-red/editor-api"
  fi
}

# Prepares the Node-RED settings file $1, owned by $2 (user:group): created from the default settings $3 when
# missing, uiHost set to $4 and, unless the file has an adminAuth of its own, the login admin with the password kept
# in $creds. Sets login (for dot_summary) and settings_changed when the file was changed.
prepare_settings() {
  local f=$1 owner=$2 default=$3 host=$4 old pw hash line
  login="user admin, password: sudo cat $creds"
  if ! dot_sudo test -f "$f"; then
    dot_sudo install -d -o "${owner%:*}" -g "${owner#*:}" "$(dirname "$f")" &&
      printf '%s\n' "$default" | dot_sudo tee "$f" >/dev/null || dot_die "could not write $f"
  fi
  old=$(dot_sudo md5sum "$f")
  dot_sudo sed -i -E "s#^([[:space:]]*)(//[[:space:]]*)?uiHost:.*#\1uiHost: \"$host\",#" "$f"
  dot_sudo grep -qE '^[[:space:]]*uiHost:' "$f" || echo "warning: no uiHost line in $f, set it by hand" >&2
  if dot_sudo grep -qE '^[[:space:]]*adminAuth:' "$f" && ! dot_sudo grep -q '// dotfiles: login$' "$f"; then
    login="as configured in adminAuth of $f"
  elif ! dot_sudo grep -q '// dotfiles: login$' "$f" || [ -n "${NODERED_PASSWORD:-}" ]; then
    pw=${NODERED_PASSWORD:-$(dot_sudo sed -n 's/^admin://p' "$creds" 2>/dev/null)}
    [ -n "$pw" ] || pw=$(dot_password 20)
    hash=$(printf '%s' "$pw" | hash_pw) && [ -n "$hash" ] || dot_die "could not hash the Node-RED password"
    dot_sudo install -d -m 0700 "$(dirname "$creds")" &&
      printf 'admin:%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$creds'" || dot_die "could not write $creds"
    line="    adminAuth: { type: \"credentials\", users: [{ username: \"admin\", password: \"$hash\", permissions: \"*\" }] }, // dotfiles: login"
    dot_sudo awk -v l="$line" '/\/\/ dotfiles: login$/ { next } { print } /^module\.exports *= *\{/ { print l }' "$f" |
      dot_sudo tee "$f.new" >/dev/null && dot_sudo mv "$f.new" "$f" || dot_die "could not write $f"
  fi
  dot_sudo chown "$owner" "$f"
  [ "$old" = "$(dot_sudo md5sum "$f")" ] || settings_changed=1
}

dot_mode_guard nodered nodered "$port"
if [ "$DOT_MODE" != native ]; then
  # Node-RED 5 images exist for amd64 and arm64 only, 32-bit ARM stays on the 4.1 line
  case $DOT_ARCH in armv*) tag=4.1 ;; *) tag=5 ;; esac
  image=nodered/node-red:$tag nr=/usr/src/node-red/node_modules/node-red creds=/opt/nodered/credentials
  dot_docker_ready
  was_up=; dot_stack_running nodered && was_up=1
  # the image runs as its user node-red (uid 1000), which owns the user directory /opt/nodered/data;
  # inside the container Node-RED listens on all interfaces of its network, DOT_BIND limits the published port
  default=
  dot_sudo test -f /opt/nodered/data/settings.js ||
    default=$(dot_sudo docker run --rm --entrypoint cat "$image" "$nr/settings.js") ||
    dot_die "could not read settings.js from $image"
  prepare_settings /opt/nodered/data/settings.js 1000:1000 "$default" 0.0.0.0
  dot_deploy nodered "services:
  nodered:
    image: $image
    container_name: nodered
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:1880\"
    volumes:
      - /opt/nodered/data:/data"
  if [ -n "$was_up" ] && [ -n "${settings_changed:-}" ]; then
    dot_sudo docker restart nodered >/dev/null || dot_die "could not restart the nodered container"
  fi
  dot_summary nodered "http://localhost:$port" "$login"
  exit 0
fi
user=$(dot_user)
home=$(dot_user_home "$user")
[ -d "$home" ] || dot_die "no home directory for $user"

dot_need curl
# the Node.js version the current Node-RED needs, from its engines field (">=22.9")
need=$(curl -fsSL https://registry.npmjs.org/node-red/latest | sed -n 's/.*"engines":{"node":">=\([0-9.]*\)".*/\1/p')
[ -n "$need" ] || dot_die "cannot read Node-RED's Node.js requirement from registry.npmjs.org"
# 32-bit ARM: NodeSource builds armhf (armv7) packages up to Node.js 22.15 (10.2026), the distro packages are older
# and the image nodered/node-red is for amd64 and arm64 only (28.10.26)
( dot_node_min "$need" ) || dot_die "Node-RED needs Node.js $need or newer and could not get it here ($DOT_ARCH)"

before=$(npm ls -g --depth=0 node-red 2>/dev/null | sed -n 's/.*node-red@//p')
dot_sudo npm install -g node-red@latest || dot_die "npm install -g node-red failed"
after=$(npm ls -g --depth=0 node-red 2>/dev/null | sed -n 's/.*node-red@//p')
[ "$before" = "$after" ] && dot_info "Node-RED $after is up to date" || dot_info "Node-RED ${before:-–} -> $after"

nr=$(npm root -g)/node-red creds=/etc/nodered/credentials
default=$(cat "$nr/settings.js") || dot_die "no settings.js in $nr"
prepare_settings "$home/.node-red/settings.js" "$user:$(id -gn "$user")" "$default" "$DOT_BIND"

# unit from github.com/node-red/linux-installers (resources/nodered.service) with the calling user and port
dot_sudo tee /etc/systemd/system/nodered.service >/dev/null <<EOF
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target
Documentation=https://nodered.org/docs/getting-started/local

[Service]
Type=simple
User=$user
Group=$(id -gn "$user")
WorkingDirectory=$home
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="NODE_OPTIONS=--max_old_space_size=512"
EnvironmentFile=-$home/.node-red/environment
Environment="NODE_RED_OPTIONS=-p $port"
ExecStart=/usr/bin/env node-red-pi \$NODE_OPTIONS -- \$NODE_RED_OPTIONS
KillSignal=SIGINT
Restart=on-failure
RestartSec=20
SyslogIdentifier=Node-RED

[Install]
WantedBy=multi-user.target
EOF

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable nodered && dot_sudo systemctl restart nodered ||
    dot_die "could not start nodered.service, see: journalctl -u nodered"
  dot_info "Node-RED $after runs as $user"
else
  dot_info "no systemd running: start Node-RED with: node-red -p $port"
fi
dot_summary nodered "http://localhost:$port" "$login"
