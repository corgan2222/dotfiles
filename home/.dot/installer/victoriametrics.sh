#!/bin/bash
# installer: VictoriaMetrics single-node, long-term storage that speaks the Prometheus API
# systems: debian amd64
# modes: native compose portainer
# VictoriaMetrics (victoriametrics.com) single-node on port 8428: PromQL/MetricsQL API for Grafana, remote write
# target for Prometheus, also takes InfluxDB line protocol, OTLP and more on the same port.
#   native:   latest GitHub release (sha256 from GitHub's digest) as /usr/local/bin/victoria-metrics, systemd unit
#             victoriametrics (dynamic user), data /var/lib/victoria-metrics
#   --docker / --portainer:   victoriametrics/victoria-metrics:latest as compose project or Portainer stack
#             "victoriametrics" in /opt/victoriametrics, data in volume victoriametrics_data
#   VICTORIAMETRICS_PORT=8428   other port;  --public / --local   all interfaces or this host (default; all
#             interfaces when Grafana runs in Docker here in the bridge network of an older grafana.sh). A later run
#             keeps address and port unless given again (also against the menu); remote write from other hosts needs
#             all interfaces.
#   VICTORIAMETRICS_RETENTION=1y   how long to keep data: a number of months or 1d, 8w, 1y (first run; natively also
#             when set on a later run). VictoriaMetrics' own default would be 1 month.
# A local Grafana (package, or grafana.sh --docker in the host network) gets a datasource "VictoriaMetrics" (type
# Prometheus).
# Prometheus (prometheus.sh) sends its data here with remote_write, shown at the end; prometheus.yml stays as it is.
# No login: VictoriaMetrics has none by default, use --local or a reverse proxy when the network is not trusted.
# RAM: about 100 MB for a few hosts. Running again updates the binary or image and keeps the data.
# category: monitoring
# ports: VICTORIAMETRICS_PORT=8428
# check: victoriametrics.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ $# -eq 0 ] || dot_die "unknown argument '$1', usage: victoriametrics.sh [--docker|--portainer] [--public|--local]"

bin=/usr/local/bin/victoria-metrics
unit=/etc/systemd/system/victoriametrics.service
# address and port of an earlier run stay unless given again: natively the unit is rewritten on every run, and an
# update must not cut off the hosts that write to it (compose: written once, read again below)
old=$(sed -n 's/.*-httpListenAddr=\([^ ]*\).*/\1/p' "$unit" 2>/dev/null)
port=${VICTORIAMETRICS_PORT:-${old##*:}}
port=${port:-8428}
case $port in ''|*[!0-9]*) dot_die "VICTORIAMETRICS_PORT must be a number, got '$port'" ;; esac
# natively the unit is rewritten on every run: without the variable it keeps the retention of the earlier run
retention=${VICTORIAMETRICS_RETENTION:-$(sed -n 's/.*-retentionPeriod=\([^ ]*\).*/\1/p' "$unit" 2>/dev/null)}
retention=${retention:-1y}
[[ $retention =~ ^[0-9]+[hdwy]?$ ]] || dot_die "VICTORIAMETRICS_RETENTION must be months (12) or a duration like 30d, 8w, 1y, got '$retention'"

# adds a VictoriaMetrics datasource to a local Grafana (package or /opt/grafana) unless it has one
grafana_datasource() {
  local d url=http://$host:$port
  if [ -d /etc/grafana/provisioning/datasources ]; then
    d=/etc/grafana/provisioning/datasources
  elif [ "$gd" = host ]; then
    # Grafana in Docker in the host network reaches VictoriaMetrics on 127.0.0.1 like a native one
    d=/opt/grafana/provisioning/datasources
    dot_sudo install -d -m 0755 "$d" || return 0
  elif [ "$gd" = bridge ]; then
    # the bridge network of an older compose.yaml mounts no provisioning and does not reach the host's 127.0.0.1
    [ "$DOT_BIND" = 127.0.0.1 ] && url= || url=http://$(hostname -I 2>/dev/null | awk '{print $1}'):$port
    dot_info "Grafana in Docker here runs in the bridge network (/opt/grafana/compose.yaml of an earlier run):"
    dot_info "  ${url:+add the datasource $url in Grafana, or }move that file away and run grafana.sh again"
    return 0
  else
    return 0
  fi
  if dot_sudo grep -rqs 'uid: *victoriametrics' "$d"; then
    dot_info "Grafana has a VictoriaMetrics datasource already ($d)"
    return 0
  fi
  dot_sudo tee "$d/victoriametrics.yaml" >/dev/null <<EOF
# written by victoriametrics.sh; VictoriaMetrics answers the Prometheus API
apiVersion: 1
datasources:
  - name: VictoriaMetrics
    uid: victoriametrics
    type: prometheus
    access: proxy
    url: $url
    jsonData:
      httpMethod: POST
EOF
  dot_sudo chmod 0644 "$d/victoriametrics.yaml"
  if [ "$d" = /etc/grafana/provisioning/datasources ] && [ -d /run/systemd/system ]; then
    dot_sudo systemctl try-restart grafana-server
    dot_info "Grafana: added datasource VictoriaMetrics ($url) in $d/victoriametrics.yaml"
  elif [ "$gd" = host ] && dot_stack_running grafana; then
    dot_sudo docker restart grafana >/dev/null
    dot_info "Grafana (Docker): added datasource VictoriaMetrics ($url) in $d/victoriametrics.yaml"
  else
    dot_info "Grafana: added datasource VictoriaMetrics ($url) in $d/victoriametrics.yaml, restart Grafana to load it"
  fi
}

dot_mode_guard victoriametrics victoriametrics "$port"
# no login, so this host only by default. Grafana in Docker from an older grafana.sh runs in the bridge network and
# reaches the host's address only, not its 127.0.0.1: then all interfaces as before. grafana.sh puts it in the host
# network since 28.10.26 (the old test looked for /opt/grafana/provisioning, which grafana.sh never made).
def=127.0.0.1 gd=$(dot_grafana_docker)
if [ ! -d /etc/grafana/provisioning/datasources ] && [ "$gd" = bridge ]; then
  def=0.0.0.0
  [ -n "$old" ] || [ -n "${BIND_ADDR:-}" ] || dot_info "Grafana runs in Docker here: listening on all interfaces"
fi
dot_bind "$def" "${old%:*}"
host=$DOT_BIND
[ "$host" = 0.0.0.0 ] && host=127.0.0.1
flags="-storageDataPath=/var/lib/victoria-metrics -retentionPeriod=$retention -httpListenAddr=$DOT_BIND:$port"

if [ "$DOT_MODE" = native ]; then
  [ -f "$unit" ] || ! dot_port_busy "$port" || dot_die "port $port is in use by another program: set VICTORIAMETRICS_PORT"
  case $DOT_ARCH in amd64|arm64) a=$DOT_ARCH ;; armv7|armv6) a=arm ;; *) dot_die "VictoriaMetrics has no release for $DOT_ARCH" ;; esac
  dot_need curl tar
  tag=$(dot_github_latest VictoriaMetrics/VictoriaMetrics) || dot_die "could not find the latest VictoriaMetrics release"
  # the version reads like victoria-metrics-20251010-123456-tags-v1.155.0-0-gabcdef
  if [ -x "$bin" ] && "$bin" --version 2>&1 | grep -qF -- "-tags-$tag-"; then
    dot_info "VictoriaMetrics $tag is already installed"
  else
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    dot_github_fetch VictoriaMetrics/VictoriaMetrics "/victoria-metrics-linux-$a-$tag\.tar\.gz\$" "$tmp/vm.tar.gz" "$tag" &&
      tar -xzf "$tmp/vm.tar.gz" -C "$tmp" && dot_sudo install -m 0755 "$tmp/victoria-metrics-prod" "$bin" ||
      dot_die "could not install VictoriaMetrics $tag"
  fi
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start VictoriaMetrics with: sudo $bin $flags"
    exit 0
  fi
  # the unit is ours: rewritten on every run, like the binary
  dot_sudo tee "$unit" >/dev/null <<EOF
[Unit]
Description=VictoriaMetrics single-node
Documentation=https://docs.victoriametrics.com/
After=network-online.target
Wants=network-online.target

[Service]
DynamicUser=yes
StateDirectory=victoria-metrics
ExecStart=$bin $flags
Restart=on-failure
LimitNOFILE=65536
ProtectSystem=full
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable victoriametrics >/dev/null 2>&1
  dot_sudo systemctl restart victoriametrics || dot_die "VictoriaMetrics does not start, see: journalctl -u victoriametrics"
else
  dot_deploy victoriametrics "services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:8428\"
    command: \"-storageDataPath=/storage -retentionPeriod=$retention -httpListenAddr=:8428\"
    volumes:
      - victoriametrics_data:/storage
volumes:
  victoriametrics_data:"
  [ -n "${DOT_NO_START:-}" ] && exit 0
  # address and port as written on the first run
  pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8428"$/\1/p' /opt/victoriametrics/compose.yaml)
  case $pub in *:*) DOT_BIND=${pub%:*} port=${pub##*:} ;; esac
  host=$DOT_BIND
  [ "$host" = 0.0.0.0 ] && host=127.0.0.1
fi

dot_wait_http "http://$host:$port/health" 60 || dot_die "VictoriaMetrics does not answer on $host:$port after 60 s, see its log"
grafana_datasource

case $DOT_BIND in 0.0.0.0|127.0.0.1) shown=localhost ;; *) shown=$DOT_BIND ;; esac
dot_summary victoriametrics "http://$shown:$port" \
  "none (VictoriaMetrics has no auth by default; use 127.0.0.1 (--local) or a reverse proxy)"
printf '  ui:      http://%s:%s/vmui   retention: %s\n' "$shown" "$port" "$retention"
printf '  from Prometheus, in prometheus.yml:  remote_write: [{url: "http://%s:%s/api/v1/write"}]\n' "$shown" "$port"
