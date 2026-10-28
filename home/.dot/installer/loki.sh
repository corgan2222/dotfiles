#!/bin/bash
# installer: Loki 3 log server (single node) from apt.grafana.com or rpm.grafana.com
# systems: debian fedora rhel
# modes: native compose portainer
# Installs Loki from Grafana's apt or rpm repository and enables the service where systemd runs.
# Keeps the config the package ships (/etc/loki/config.yml: single node, TSDB, schema v13, filesystem),
# but moves its data from /tmp/loki to /var/lib/loki, /tmp is cleared on reboot. Listens on port 3100.
#   loki.sh                         native (safe to run again)
#   loki.sh --docker | --portainer  image grafana/loki:3 as compose project or Portainer stack "loki" from /opt/loki,
#                                   the same single-node config in /opt/loki/config.yaml (written once), data in loki_data
#   --public / --local              listen on all interfaces or on this host only (else asked; default as on the
#                                   earlier run, else this host). Alloy on other hosts needs --public.
# No authentication (auth_enabled: false): anyone who reaches it reads and writes all logs. On all interfaces only
# in a trusted network or behind a reverse proxy with a login.
# category: logs
# ports: 3100
# check: loki.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

conf=/etc/loki/config.yml
data=/var/lib/loki
dest=/opt/loki

dot_mode_guard loki loki 3100
# the address of an earlier run stays, also against the menu's BIND_ADDR, unless --public/--local/--bind is given (an
# update must not cut off the hosts that push to it)
if [ "$DOT_MODE" = native ]; then
  old=$(dot_sudo sed -n 's/^  http_listen_address: *//p' "$conf" 2>/dev/null)
else
  old=$(dot_sudo sed -n 's/^ *- "\(.*\):3100:3100"$/\1/p' "$dest/compose.yaml" 2>/dev/null)
fi
dot_bind 127.0.0.1 "$old"

if [ "$DOT_MODE" != native ]; then
  # the image's own single-node config (cmd/loki/loki-docker-config.yaml), kept editable on the host
  dot_sudo install -d -m 0755 "$dest"
  dot_sudo test -f "$dest/config.yaml" || dot_sudo tee "$dest/config.yaml" >/dev/null <<'EOF' || dot_die "could not write $dest/config.yaml"
# written by loki.sh: single node, TSDB, schema v13, filesystem; delete it to get the default again
auth_enabled: false

server:
  http_listen_port: 3100

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
EOF
  dot_sudo chmod 0644 "$dest/config.yaml"
  dot_deploy loki "services:
  loki:
    image: grafana/loki:3
    container_name: loki
    restart: unless-stopped
    command: -config.file=/etc/loki/config.yaml
    ports:
      - \"$DOT_BIND:3100:3100\"
    volumes:
      - $dest/config.yaml:/etc/loki/config.yaml:ro
      - data:/loki
volumes:
  data:"
  dot_summary loki "http://localhost:3100/loki/api/v1/push http://localhost:3100/ready" "none (no authentication)"
  exit 0
fi

# grafana.sh may have added the repository with the beta channel already, keep it
case $DOT_PKG in
  apt)
    [ -f /etc/apt/sources.list.d/grafana.sources ] ||
      dot_apt_repo grafana https://apt.grafana.com/gpg.key https://apt.grafana.com stable main
    # the package's postinst creates the user loki with adduser but does not depend on it (missing on minimal images)
    dot_need adduser ;;
  dnf|yum)
    [ -f /etc/yum.repos.d/grafana.repo ] ||
      dot_rpm_repo grafana https://rpm.grafana.com https://rpm.grafana.com/gpg.key repo_gpgcheck=1 ;;
  *) dot_die "loki.sh supports Debian-based systems, Fedora and the RHEL family, not $DOT_OS" ;;
esac
dot_pkg_install loki || dot_die "installing the loki package failed"
id loki >/dev/null 2>&1 || dot_die "the loki package did not create the user loki"
[ -f "$conf" ] || dot_die "the loki package shipped no $conf"

if grep -q '/tmp/loki' "$conf"; then
  dot_sudo install -d -o loki -g "$(id -gn loki)" "$data" && dot_sudo sed -i "s|/tmp/loki|$data|g" "$conf" ||
    dot_die "could not move the Loki data to $data"
  dot_info "Loki data moved to $data in $conf"
fi
# listen address of HTTP and gRPC, placed below their ports in the server: block. gRPC stays on 127.0.0.1: only Loki
# talks to itself there, at common.instance_addr (127.0.0.1); on --bind=<IP> queries ran into a timeout (28.10.26)
for k in http:$DOT_BIND grpc:127.0.0.1; do
  a=${k#*:} k=${k%%:*}
  if dot_sudo grep -q "^  ${k}_listen_address:" "$conf"; then
    dot_sudo sed -i "s|^  ${k}_listen_address:.*|  ${k}_listen_address: $a|" "$conf"
  else
    dot_sudo sed -i "/^  ${k}_listen_port:/a\\  ${k}_listen_address: $a" "$conf"
  fi
done
out=$(dot_sudo loki -verify-config -config.file="$conf" 2>&1) || { echo "$out" >&2; dot_die "$conf is not valid"; }

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable loki && dot_sudo systemctl restart loki || dot_die "could not start loki"
else
  dot_info "no systemd running: start Loki with: sudo -u loki loki -config.file=$conf"
fi
dot_info "$(loki --version | head -n 1) installed, config $conf"
dot_summary loki "http://localhost:3100/loki/api/v1/push http://localhost:3100/ready" "none (no authentication)"
