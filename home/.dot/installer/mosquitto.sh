#!/bin/bash
# installer: Mosquitto MQTT broker with password login, or in Docker
# systems: debian fedora rhel
# modes: native compose portainer
# Installs the Mosquitto broker and clients from the distribution (RHEL family: EPEL) plus python3-paho-mqtt and writes
# /etc/mosquitto/conf.d/listener.conf (listener on port 1883):
#   mosquitto.sh [user] [password]    login with a password file; user $MQTT_USER or mqtt, password $MQTT_PASSWORD,
#                                     the stored one or generated; stored in <dir>/credentials (root only)
#   mosquitto.sh --anonymous          no login at all (only on a trusted network)
#   --public / --local                listen on all interfaces (default) or on this host only
#   MOSQUITTO_PORT=1884               other port; a first run beside another broker on 1883 takes the next free one
#   mosquitto.sh --docker [user]      in Docker instead (image eclipse-mosquitto, config and password file in
#                                     /opt/mosquitto/config, data in the volume mosquitto_data); --portainer as a stack
# Without arguments an existing listener.conf (Docker: mosquitto.conf) is kept, so the menu can run it again.
# category: server
# ports: MOSQUITTO_PORT=1883
# check: mosquitto.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

image=eclipse-mosquitto:2
if [ "$DOT_MODE" = native ]; then
  conf=/etc/mosquitto/conf.d/listener.conf passwd=/etc/mosquitto/passwd creds=/etc/mosquitto/credentials
else
  conf=/opt/mosquitto/config/mosquitto.conf passwd=/opt/mosquitto/config/passwd creds=/opt/mosquitto/credentials
fi
anonymous= mqtt_user=${MQTT_USER:-} mqtt_pass=${MQTT_PASSWORD:-}
case ${1:-} in
  --anonymous) anonymous=1 ;;
  -h|--help) sed -n '5,13s/^# \{0,1\}//p' "$0"; exit 0 ;;
  -*) dot_die "unknown option $1" ;;
  ?*) mqtt_user=$1 mqtt_pass=${2:-$mqtt_pass} ;;
esac
dot_bind 0.0.0.0

# prints the stored password of the user $1 from the credentials file
stored_pass() { dot_sudo awk -F: -v u="$1" '$1 == u { sub(/^[^:]*:/, ""); print; exit }' "$creds" 2>/dev/null; }

# stores the user $1 with the password $2 in the credentials file, root only
store_pass() {
  { dot_sudo awk -F: -v u="$1" '$1 != u' "$creds" 2>/dev/null; printf '%s:%s\n' "$1" "$2"; } |
    dot_sudo sh -c "umask 077; cat > '$creds.new' && mv '$creds.new' '$creds'" || dot_die "could not write $creds"
}

# a first run without user gets the user mqtt; a password not given is the stored one or a generated one
[ -z "$anonymous$mqtt_user" ] && ! [ -f "$conf" ] && mqtt_user=mqtt
if [ -n "$mqtt_user" ] && [ -z "$mqtt_pass" ]; then
  mqtt_pass=$(stored_pass "$mqtt_user")
  [ -n "$mqtt_pass" ] || mqtt_pass=$(dot_password 24)
fi
if [ -n "$anonymous" ]; then login="none (anonymous access)"
elif [ -n "$mqtt_user" ]; then login="user $mqtt_user, password: sudo cat $creds"
else login="as configured in $conf (stored passwords: sudo cat $creds)"; fi

# Runs the broker from /opt/mosquitto with the same login as natively; the password hash comes from mosquitto_passwd
# of the image itself. The container user mosquitto (uid 1883) owns the read-only mounted config; inside the
# container the listener takes all interfaces, DOT_BIND limits the published port.
deploy_docker() {
  local cfg=/opt/mosquitto/config changed= c= was_up=
  dot_docker_ready
  dot_stack_running mosquitto && was_up=1
  # the host port: MOSQUITTO_PORT, else what the first run published, else 1883 or, while another broker has it
  # (EMQX, chosen together on 28.10.26), the next free one; inside the container it stays 1883
  if [ -z "$mport" ] && dot_sudo test -f /opt/mosquitto/compose.yaml; then
    mport=$(dot_sudo sed -n 's/^ *- "\(.*\):1883"$/\1/p' /opt/mosquitto/compose.yaml) mport=${mport##*:}
  fi
  if [ -z "$mport" ]; then
    mport=1883
    if [ -z "$was_up" ] && dot_port_busy 1883; then
      mport=$(dot_free_port 1884) || dot_die "port 1883 is taken and no port up to 1933 is free"
      dot_info "port 1883 is taken by another broker (EMQX?), Mosquitto gets port $mport"
    fi
  fi
  dot_sudo install -d -m 0755 "$cfg" || exit 1
  if [ -n "$anonymous" ]; then
    printf 'listener 1883\nallow_anonymous true\npersistence true\npersistence_location /mosquitto/data/\n' |
      dot_sudo tee "$conf" >/dev/null || exit 1
    echo "warning: anonymous access: everyone who reaches the port can read and publish" >&2
    changed=1
  elif [ -n "$mqtt_user" ]; then
    # -c creates the file; without it the user is added to or changed in an existing one
    dot_sudo test -f "$passwd" || c=-c
    dot_sudo docker run --rm -v "$cfg:/mosquitto/config" "$image" \
      mosquitto_passwd $c -b /mosquitto/config/passwd "$mqtt_user" "$mqtt_pass" || dot_die "mosquitto_passwd failed"
    store_pass "$mqtt_user" "$mqtt_pass"
    printf 'listener 1883\nallow_anonymous false\npassword_file %s\npersistence true\npersistence_location %s\n' \
      /mosquitto/config/passwd /mosquitto/data/ | dot_sudo tee "$conf" >/dev/null || exit 1
    dot_sudo chmod 0600 "$passwd"
    dot_info "user $mqtt_user can log in"
    changed=1
  else
    dot_info "keeping $conf"
  fi
  dot_sudo chown -R 1883:1883 "$cfg"
  dot_deploy mosquitto "services:
  mosquitto:
    image: $image
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$mport:1883\"
    volumes:
      - $cfg:/mosquitto/config:ro
      - mosquitto_data:/mosquitto/data
volumes:
  mosquitto_data:"
  # a running broker reads a changed config only on a restart
  if [ -n "$was_up" ] && [ -n "$changed" ]; then
    dot_sudo docker restart mosquitto >/dev/null || dot_die "could not restart the mosquitto container"
  fi
  dot_info "clients: sudo docker exec mosquitto mosquitto_sub -h localhost -t '#' -u <user> -P <password>"
}

mport=${MOSQUITTO_PORT:-}
case $mport in ''|[0-9]*) ;; *) dot_die "MOSQUITTO_PORT must be a number, got '$mport'" ;; esac
dot_mode_guard mosquitto mosquitto
if [ "$DOT_MODE" != native ]; then
  deploy_docker
  dot_summary mosquitto "mqtt://localhost:$mport" "$login"
  exit 0
fi
# natively the same: MOSQUITTO_PORT, the listener of an earlier run, 1883, or the next free port beside another broker
[ -n "$mport" ] || mport=$(dot_sudo awk '$1 == "listener" { print $2; exit }' "$conf" 2>/dev/null)
if [ -z "$mport" ]; then
  mport=1883
  if ! systemctl is-active -q mosquitto 2>/dev/null && dot_port_busy 1883; then
    mport=$(dot_free_port 1884) || dot_die "port 1883 is taken and no port up to 1933 is free"
    dot_info "port 1883 is taken by another broker (EMQX?), Mosquitto gets port $mport"
  fi
fi

case $DOT_PKG in
  apt) dot_pkg_install mosquitto mosquitto-clients python3-paho-mqtt ;;
  # one package with the clients, in EPEL on the RHEL family; its mosquitto.conf has no conf.d (Fedora ships none);
  # the user comes from sysusers.d, which a system without a running systemd does not apply by itself
  dnf|yum)
    dot_epel && dot_pkg_install mosquitto python3-paho-mqtt &&
      { id mosquitto >/dev/null 2>&1 || dot_sudo systemd-sysusers mosquitto.conf; } &&
      dot_sudo install -d -m 0755 /etc/mosquitto/conf.d &&
      { dot_sudo grep -qs '^include_dir /etc/mosquitto/conf.d' /etc/mosquitto/mosquitto.conf ||
        echo 'include_dir /etc/mosquitto/conf.d' | dot_sudo tee -a /etc/mosquitto/mosquitto.conf >/dev/null; } ;;
  *) dot_die "no Mosquitto package path for $DOT_OS, use --docker" ;;
esac || dot_die "could not install Mosquitto"

# without an address the listener takes all interfaces, IPv4 and IPv6
if [ "$DOT_BIND" = 0.0.0.0 ]; then listener=$mport; else listener="$mport $DOT_BIND"; fi
if [ -n "$anonymous" ]; then
  printf 'listener %s\nallow_anonymous true\n' "$listener" | dot_sudo tee "$conf" >/dev/null || exit 1
  echo "warning: anonymous access: everyone who reaches the port can read and publish" >&2
elif [ -n "$mqtt_user" ]; then
  # -c creates the file; without it the user is added to or changed in an existing one
  if dot_sudo test -f "$passwd"; then c=; else c=-c; fi
  dot_sudo mosquitto_passwd $c -b "$passwd" "$mqtt_user" "$mqtt_pass" || dot_die "mosquitto_passwd failed"
  store_pass "$mqtt_user" "$mqtt_pass"
  # Mosquitto 2 wants the password file to belong to its user and to be private
  dot_sudo chown mosquitto: "$passwd" && dot_sudo chmod 0600 "$passwd"
  printf 'listener %s\nallow_anonymous false\npassword_file %s\n' "$listener" "$passwd" | dot_sudo tee "$conf" >/dev/null || exit 1
  dot_info "user $mqtt_user can log in"
else
  dot_info "keeping $conf"
fi

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable mosquitto && dot_sudo systemctl restart mosquitto ||
    dot_die "Mosquitto does not start, see: journalctl -u mosquitto"
else
  dot_info "no systemd running: start Mosquitto with: sudo mosquitto -c /etc/mosquitto/mosquitto.conf -d"
fi
dot_summary mosquitto "mqtt://localhost:$mport" "$login"
