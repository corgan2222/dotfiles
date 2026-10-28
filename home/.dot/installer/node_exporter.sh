#!/bin/bash
# installer: Prometheus node_exporter (host metrics) with a textfile collector example
# systems: debian arch fedora rhel amd64 arm64 armv7 armv6
# modes: native compose portainer
# node_exporter (github.com/prometheus/node_exporter) for hosts that a central Prometheus scrapes on port 9100;
# prometheus.sh installs it together with Prometheus. No login: whoever reaches the port reads the metrics.
#   native:   latest GitHub release (sha256 checked against sha256sums.txt) in /usr/local/bin, systemd unit
#             node_exporter under the system user node_exporter
#   --docker / --portainer:   prom/node-exporter:v1 as compose project or Portainer stack "node-exporter" in /opt/node-exporter
#             (host network, host PID and / read-only under /host, as the node_exporter README shows)
#   NODE_EXPORTER_PORT=9100   other port;   --public / --local   all interfaces (default) or this host only
#             A later run keeps address and port of the earlier one unless given again (NODE_EXPORTER_PORT, --public,
#             --local, --bind=): an address set by the caller (BIND_ADDR of prometheus.sh) does not move it.
#   node_exporter.sh textfile only the textfile example below (prometheus.sh uses it for its Docker stack)
# Textfile collector: *.prom files in /var/lib/node_exporter/textfile are exported with the host metrics.
# Example: /usr/local/bin/prom-textfile-example.sh (pending package updates, reboot required), run every 15 minutes by
# prom-textfile-example.timer; written only when missing, copy it as a template for your own metrics.
# RAM: about 20 MB. Running again updates the binary or image and keeps the example script.
# category: monitoring
# ports: NODE_EXPORTER_PORT=9100
# check: node_exporter.service|prometheus-node-exporter.service stack:node-exporter
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
# an address on our own command line, not one inherited through BIND_ADDR (see below)
own_bind=
for a; do case $a in --public|--local|--bind=*) own_bind=1 ;; esac; done
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

bin=/usr/local/bin/node_exporter
dest=/opt/node-exporter
# address and port of an earlier run (unit or compose file). prometheus.sh exports its own address as BIND_ADDR: a
# node_exporter installed before for a central Prometheus went local on the next prometheus.sh run (28.10.26), so the
# earlier address only gives way to --public, --local or --bind=
old=$(dot_sudo sed -n 's/.*--web\.listen-address=\([^ "]*\).*/\1/p' /etc/systemd/system/node_exporter.service \
  "$dest/compose.yaml" 2>/dev/null | head -n 1)
port=${NODE_EXPORTER_PORT:-${old##*:}}
port=${port:-9100}
tfdir=/var/lib/node_exporter/textfile
script=/usr/local/bin/prom-textfile-example.sh
case $port in ''|*[!0-9]*) dot_die "NODE_EXPORTER_PORT must be a number, got '$port'" ;; esac
only=
case ${1:-} in
  textfile) only=1 ;;
  '') ;;
  *) dot_die "unknown argument '$1', usage: node_exporter.sh [textfile] [--docker|--portainer] [--public|--local]" ;;
esac

# the textfile directory, the example script (when missing) and the timer that runs it every 15 minutes
textfile_example() {
  dot_sudo install -d -m 0755 "$tfdir" || exit 1
  dot_put_new "$script" <<'EOF'
#!/bin/sh
# Example for the node_exporter textfile collector (written by node_exporter.sh, yours to change).
# Run by prom-textfile-example.timer every 15 minutes. Writes custom metrics to a temp file in the same directory and
# renames it, so node_exporter never reads a half-written file; it only reads files ending in .prom.
# Template for your own metrics (backup age, certificate expiry, ...): copy this script and its timer, use another
# .prom name, keep "# HELP" / "# TYPE" lines and plain "name value" lines (Prometheus text format).
set -eu
dir=${TEXTFILE_DIR:-/var/lib/node_exporter/textfile}
tmp=$(mktemp "$dir/.example.prom.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# package updates waiting, from the package lists the system refreshed last (no download here); -1 = unknown
if command -v apt-get >/dev/null 2>&1; then
  updates=$(apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst ' || true)
elif command -v checkupdates >/dev/null 2>&1; then   # Arch, from pacman-contrib
  updates=$(checkupdates 2>/dev/null | wc -l)
elif command -v dnf >/dev/null 2>&1; then
  updates=$(dnf -q check-update 2>/dev/null | grep -c '^[[:alnum:]]' || true)
else
  updates=-1
fi
reboot=0
[ -f /var/run/reboot-required ] && reboot=1

cat > "$tmp" <<METRICS
# HELP custom_pending_updates Package updates waiting to be installed (-1: unknown package manager).
# TYPE custom_pending_updates gauge
custom_pending_updates $updates
# HELP custom_reboot_required 1 when the system asks for a reboot (/var/run/reboot-required).
# TYPE custom_reboot_required gauge
custom_reboot_required $reboot
METRICS
chmod 0644 "$tmp"
mv "$tmp" "$dir/example.prom"
EOF
  dot_sudo chmod 0755 "$script" || exit 1
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: run $script from cron, e.g. */15 * * * * root $script"
    return 0
  fi
  dot_sudo tee /etc/systemd/system/prom-textfile-example.service >/dev/null <<EOF
[Unit]
Description=Example metrics for the node_exporter textfile collector

[Service]
Type=oneshot
ExecStart=$script
EOF
  dot_sudo tee /etc/systemd/system/prom-textfile-example.timer >/dev/null <<EOF
[Unit]
Description=Example metrics for the node_exporter textfile collector every 15 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable --now prom-textfile-example.timer >/dev/null 2>&1 &&
    dot_sudo systemctl start prom-textfile-example.service || dot_die "the textfile example failed, see: journalctl -u prom-textfile-example"
  dot_info "textfile example: $script -> $tfdir/example.prom (timer prom-textfile-example.timer)"
}

# the prometheus stack of prometheus.sh brings its own node-exporter
if [ -z "$only" ] && dot_sudo grep -qs 'image: *prom/node-exporter' /opt/prometheus/compose.yaml; then
  dot_info "node_exporter runs in the prometheus stack (/opt/prometheus/compose.yaml), setting up the textfile example only"
  only=1
fi
[ -n "$only" ] && { textfile_example; exit 0; }

[ -z "$old" ] || [ -n "$own_bind" ] || BIND_ADDR=own
dot_bind "${old%:*}"
dot_need curl tar
# one installation per host: native and container would fight over the port
if [ "$DOT_MODE" = native ] && dot_sudo test -f "$dest/compose.yaml"; then
  dot_info "node_exporter runs in Docker here ($dest/compose.yaml), staying with compose (--portainer for a Portainer stack)"
  DOT_MODE=compose
fi
[ "$DOT_MODE" != native ] && [ -f /etc/systemd/system/node_exporter.service ] &&
  dot_die "node_exporter runs natively here (node_exporter.service): use --native"
if [ ! -f /etc/systemd/system/node_exporter.service ] && ! dot_sudo test -f "$dest/compose.yaml" && dot_port_busy "$port"; then
  dot_die "port $port is in use by another program (a node_exporter from a package?): set NODE_EXPORTER_PORT or remove it"
fi
textfile_example

if [ "$DOT_MODE" = native ]; then
  case $DOT_ARCH in amd64|arm64|armv7|armv6) ;; *) dot_die "node_exporter has no release for architecture $DOT_ARCH" ;; esac
  tag=$(dot_github_latest prometheus/node_exporter) || dot_die "could not find the latest node_exporter release"
  getent passwd node_exporter >/dev/null ||
    dot_sudo useradd --system --home-dir /var/lib/node_exporter --no-create-home --shell /usr/sbin/nologin node_exporter ||
    dot_die "could not create the user node_exporter"
  if [ -x "$bin" ] && "$bin" --version 2>&1 | grep -qF "version ${tag#v} "; then
    dot_info "node_exporter $tag is already installed"
  else
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    dot_prometheus_release node_exporter "$tag" "$tmp"
    dot_sudo install -m 0755 "$tmp/node_exporter-${tag#v}.linux-$DOT_ARCH/node_exporter" "$bin" || exit 1
  fi
  flags="--web.listen-address=$DOT_BIND:$port --collector.textfile.directory=$tfdir"
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start node_exporter with: sudo -u node_exporter $bin $flags"
    exit 0
  fi
  # the unit is ours: rewritten on every run, like the binary
  dot_sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<EOF
[Unit]
Description=Prometheus node_exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=$bin $flags
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable node_exporter >/dev/null 2>&1
  dot_sudo systemctl restart node_exporter || dot_die "node_exporter does not start, see: journalctl -u node_exporter"
else
  # rslave (README) needs / to be a shared or slave mount, Docker refuses it on a private one (some containers)
  prop=
  case $(findmnt -no PROPAGATION / 2>/dev/null) in shared*|slave*) prop=,rslave ;; esac
  dot_deploy node-exporter "services:
  node-exporter:
    image: prom/node-exporter:v1
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    command: \"--path.rootfs=/host --web.listen-address=$DOT_BIND:$port --collector.textfile.directory=/host$tfdir\"
    volumes:
      - /:/host:ro$prop"
  [ -n "${DOT_NO_START:-}" ] && exit 0
fi

host=$DOT_BIND
[ "$host" = 0.0.0.0 ] && host=127.0.0.1
for _ in $(seq 20); do curl -fsS -o /dev/null "http://$host:$port/metrics" 2>/dev/null && break; sleep 1; done
curl -fsS -o /dev/null "http://$host:$port/metrics" || dot_die "node_exporter does not answer on $host:$port"
case $DOT_BIND in 0.0.0.0|127.0.0.1) shown=localhost ;; *) shown=$DOT_BIND ;; esac
dot_summary node-exporter "http://$shown:$port/metrics" \
  "none (no auth: whoever reaches the port reads the metrics; --local or a firewall on untrusted networks)" node_exporter
