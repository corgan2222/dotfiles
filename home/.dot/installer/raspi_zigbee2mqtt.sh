#!/bin/bash
# installer: Zigbee2MQTT (latest release) as a systemd service, or in Docker
# systems: raspi debian
# modes: native compose portainer
# Installs the latest Zigbee2MQTT release into /opt/zigbee2mqtt, owned by the calling user, the way
# zigbee2mqtt.io/guide/installation/01_linux.html describes it (Node.js LTS via nodejs.sh, pnpm via corepack),
# and the service zigbee2mqtt.service. Running it again updates to a newer release; the config stays.
# The config data/configuration.yaml is created only when there is none:
#   raspi_zigbee2mqtt.sh [adapter]      adapter path, default $Z2M_ADAPTER or /dev/ttyACM0
#                                       (better a stable name from /dev/serial/by-id/)
#   Z2M_MQTT=mqtt://localhost:1883      MQTT broker (default mqtt://localhost)
#   Z2M_PORT=8080                       port of the web frontend
#   Z2M_MQTT_USER=… Z2M_MQTT_PASSWORD=… MQTT login, default the first user mosquitto.sh stored, else none
#   Z2M_FRONTEND_TOKEN=…                login token of the frontend, else generated
#                                       (both in data/secret.yaml, readable by the service user only)
#   --public / --local                  frontend on all interfaces (default) or on this host only
#   raspi_zigbee2mqtt.sh --docker [adapter]   in Docker instead (image koenkk/zigbee2mqtt, host network so that
#                                       mqtt://localhost is the host's broker, same /opt/zigbee2mqtt/data);
#                                       --portainer as a stack; a network adapter (tcp://…) maps no device
# category: raspberry
# ports: Z2M_PORT=8080
# check: zigbee2mqtt.service stack:zigbee2mqtt
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
dot_bind 0.0.0.0

dest=/opt/zigbee2mqtt
adapter=${1:-${Z2M_ADAPTER:-/dev/ttyACM0}}
node_min=22   # Zigbee2MQTT 2.x: engines "node": "^22.2.0 || ^24 ..."
user=$(dot_user)
frontend_port=${Z2M_PORT:-8080}
login="frontend token: sudo cat $dest/data/secret.yaml (an older config: see frontend in data/configuration.yaml)"


# Writes $dest/data/configuration.yaml when there is none (native and Docker read the same file); the frontend token
# and the MQTT login go to data/secret.yaml (0600), the config refers to them with !secret.yaml.
write_config() {
  local mu=${Z2M_MQTT_USER:-} mp=${Z2M_MQTT_PASSWORD:-} f mqtt_login="  # user: my_user
  # password: my_password"
  if [ ! -f "$dest/data/configuration.yaml" ]; then
    [ -e "$adapter" ] || [ "${adapter#tcp://}" != "$adapter" ] || echo "warning: the adapter $adapter does not exist (yet), see ls -l /dev/serial/by-id/" >&2
    if [ -z "$mu" ]; then
      # the login mosquitto.sh stored, native or Docker
      for f in /etc/mosquitto/credentials /opt/mosquitto/credentials; do
        mu=$(dot_sudo sed -n '1s/:.*//p' "$f" 2>/dev/null) mp=$(dot_sudo sed -n '1s/^[^:]*://p' "$f" 2>/dev/null)
        [ -n "$mu" ] && break
      done
    fi
    [ -n "$mu" ] && mqtt_login="  user: '!secret.yaml mqtt_user'
  password: '!secret.yaml mqtt_password'"
    dot_sudo install -d "$dest/data" || exit 1
    { printf 'auth_token: "%s"\n' "${Z2M_FRONTEND_TOKEN:-$(dot_password 32)}"
      [ -n "$mu" ] && printf 'mqtt_user: "%s"\nmqtt_password: "%s"\n' "$mu" "$mp"
    } | dot_sudo sh -c "umask 077; cat > '$dest/data/secret.yaml'" || exit 1
    dot_sudo tee "$dest/data/configuration.yaml" >/dev/null <<EOF || exit 1
# Zigbee2MQTT config, docs: https://www.zigbee2mqtt.io/guide/configuration/
version: 5
homeassistant:
  enabled: false
frontend:
  enabled: true
  host: $DOT_BIND
  port: ${Z2M_PORT:-8080}
  auth_token: '!secret.yaml auth_token'
mqtt:
  base_topic: zigbee2mqtt
  server: ${Z2M_MQTT:-mqtt://localhost}
$mqtt_login
serial:
  port: $adapter
  # adapter type when auto detection fails: zstack, ember, deconz, zigate or zboss
  # adapter: ember
advanced:
  network_key: GENERATE
  pan_id: GENERATE
  ext_pan_id: GENERATE
EOF
    dot_info "wrote $dest/data/configuration.yaml"
  else
    dot_info "keeping $dest/data/configuration.yaml"
  fi
}

dot_mode_guard zigbee2mqtt zigbee2mqtt
if [ "$DOT_MODE" != native ]; then
  # a serial adapter is handed into the container under the same path, so the config works in both modes
  case $adapter in
    tcp://*) devices= ;;
    *) [ -e "$adapter" ] || dot_die "the adapter $adapter does not exist: plug it in or give its path (ls -l /dev/serial/by-id/)"
       devices="
    devices:
      - $adapter:$adapter" ;;
  esac
  write_config
  # host network: the frontend listens on Z2M_PORT and mqtt://localhost reaches the broker on this host,
  # a native one as well as a published Docker one; /run/udev lets Zigbee2MQTT detect the adapter type
  dot_deploy zigbee2mqtt "services:
  zigbee2mqtt:
    image: koenkk/zigbee2mqtt:2
    container_name: zigbee2mqtt
    restart: unless-stopped
    network_mode: host
    volumes:
      - $dest/data:/app/data
      - /run/udev:/run/udev:ro$devices"
  dot_summary zigbee2mqtt "http://localhost:$frontend_port" "$login"
  exit 0
fi

[ "$DOT_PKG" = apt ] || dot_die "this installer needs apt (Debian, Raspberry Pi OS, Ubuntu)"
dot_pkg_install git make g++ gcc libsystemd-dev curl ca-certificates || dot_die "could not install the build tools"

# 32-bit ARM: NodeSource builds armhf (armv7) packages up to Node.js 22.15 (10.2026), none for armv6, and the distro
# packages are older; the image koenkk/zigbee2mqtt also runs on arm/v6 and arm/v7 (28.10.26)
( dot_node_min "$node_min" ) ||
  dot_die "Zigbee2MQTT needs Node.js $node_min and could not get it here ($DOT_ARCH);" \
    "in Docker: raspi_zigbee2mqtt.sh --docker"
# corepack runs the pnpm version pinned in package.json; Node.js 25+ no longer ships corepack
command -v corepack >/dev/null 2>&1 || dot_sudo npm install -g corepack || dot_die "could not install corepack"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

tag=$(dot_github_latest Koenkk/zigbee2mqtt)
[ -n "$tag" ] || dot_die "could not read the latest Zigbee2MQTT release from GitHub"

if [ -d "$dest/.git" ]; then
  current=$(git -C "$dest" describe --tags --exact-match 2>/dev/null)
  if [ "$current" = "$tag" ]; then
    dot_info "Zigbee2MQTT $tag is installed"
    build=
  else
    dot_info "updating Zigbee2MQTT ${current:-?} to $tag"
    [ -d /run/systemd/system ] && dot_sudo systemctl stop zigbee2mqtt 2>/dev/null
    git -C "$dest" fetch -q --depth 1 origin tag "$tag" && git -C "$dest" checkout -q --force "$tag" ||
      dot_die "could not check out $tag in $dest"
    build=1
  fi
else
  [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ] && dot_die "$dest exists but is no git checkout, move it away first"
  dot_sudo install -d -o "$user" -g "$(id -gn "$user")" "$dest" || exit 1
  git clone -q --depth 1 --branch "$tag" https://github.com/Koenkk/zigbee2mqtt.git "$dest" || dot_die "git clone failed"
  build=1
fi

if [ -n "$build" ]; then
  # pnpm install builds native modules, pnpm run build compiles the TypeScript (else the first start does it)
  (cd "$dest" && corepack pnpm install --frozen-lockfile && corepack pnpm run build) || dot_die "building Zigbee2MQTT failed"
fi

write_config
# started as root (sudo) the files above belong to root, the service runs as the calling user
dot_sudo chown -R "$user": "$dest"

# the adapter belongs to the group dialout
[ "$user" = root ] || id -nG "$user" | grep -qw dialout || dot_sudo usermod -aG dialout "$user"

# unit from the official docs, with the calling user and the node found here
dot_sudo tee /etc/systemd/system/zigbee2mqtt.service >/dev/null <<EOF
[Unit]
Description=zigbee2mqtt
After=network.target

[Service]
Environment=NODE_ENV=production
Type=notify
ExecStart=$(command -v node) index.js
WorkingDirectory=$dest
StandardOutput=inherit
StandardError=inherit
WatchdogSec=10s
Restart=always
RestartSec=10s
User=$user

[Install]
WantedBy=multi-user.target
EOF

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable zigbee2mqtt ||
    dot_die "could not enable zigbee2mqtt.service"
  # without its adapter Zigbee2MQTT exits at once: enable only, the stick may come later
  if [ -e "$adapter" ] || [ "${adapter#tcp://}" != "$adapter" ]; then
    dot_sudo systemctl restart zigbee2mqtt || dot_die "could not start zigbee2mqtt.service, see: journalctl -u zigbee2mqtt"
  else
    dot_info "zigbee2mqtt.service is enabled but not started: $adapter is missing; plug it in, then: sudo systemctl start zigbee2mqtt"
  fi
else
  dot_info "no systemd running: enable it later with: sudo systemctl enable --now zigbee2mqtt"
fi
dot_summary zigbee2mqtt "http://localhost:$frontend_port" "$login"
