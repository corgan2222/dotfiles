#!/bin/bash
# installer: Prometheus 3 stack: node_exporter, Alertmanager, blackbox exporter, example rules, Grafana datasource
# systems: debian arch fedora rhel amd64 arm64 armv7 armv6
# modes: native compose portainer
# Prometheus (prometheus.io) with its usual companions for this host, ready to use:
#   Prometheus 9090 (UI and API), node_exporter 9100, Alertmanager 9093, blackbox exporter 9115 (HTTP, TCP, ICMP
#   probes) and, when a local nginx shows stub_status, the nginx exporter 9113.
#   native:   latest GitHub releases (sha256 checked against sha256sums.txt or GitHub's digest) in /usr/local/bin,
#             systemd units prometheus, alertmanager, blackbox-exporter, nginx-exporter under the system user
#             prometheus, config /etc/prometheus, data /var/lib/prometheus and /var/lib/alertmanager; node_exporter.sh
#   --docker / --portainer:   compose project or Portainer stack "prometheus" in /opt/prometheus with prom/prometheus:v3,
#             prom/node-exporter:v1, prom/alertmanager:v0, prom/blackbox-exporter:v0, nginx/nginx-prometheus-exporter:1,
#             all on the host network (node_exporter needs it; Prometheus then reaches the exporters on localhost as
#             natively), config /opt/prometheus/config (mounted as /etc/prometheus), data in volume prometheus_data and
#             /opt/prometheus/alertmanager
#   PROMETHEUS_PORT=9090 NODE_EXPORTER_PORT=9100 ALERTMANAGER_PORT=9093 BLACKBOX_PORT=9115 NGINX_EXPORTER_PORT=9113
#             other ports;  --public / --local   all interfaces or this host (default; all interfaces when Grafana
#             runs in Docker here in the bridge network of an older grafana.sh, which reaches the host's address
#             only). A later run keeps address and port of Prometheus unless given again (also against the menu).
#   PROMETHEUS_RETENTION=15d   how long to keep data (first run; later storage.tsdb.retention.time in prometheus.yml)
#   PROMETHEUS_NGINX_URL=http://127.0.0.1/nginx_status   stub_status page for the nginx exporter; without it the
#             installer looks at /nginx_status and /stub_status on 127.0.0.1 and leaves the exporter out when none answers
# Written on the first run only, then yours: prometheus.yml (scrapes itself and node_exporter, sends alerts to the
# Alertmanager, reads more jobs from scrape.d/*.yml), scrape.d/ (alertmanager, blackbox with an example HTTP probe of
# https://example.org, nginx), rules/ (node: instance down, disk, load, memory, textfile; alertmanager and exporters
# down, probe failed, TLS certificate expires in less than 14 days), alertmanager.yml (default receiver that sends
# nothing, commented examples for e-mail, webhook, Telegram, Slack, ntfy), blackbox.yml (http_2xx, tcp_connect, icmp),
# /usr/local/bin/prom-test-alert.sh (sends a test alert) and the textfile example of node_exporter.sh.
# Running again adds what is missing (a part installed since, files, the alerting and scrape_config_files blocks of an
# older prometheus.yml, services of an older compose.yaml; backups *.bak) and never overwrites a config.
# A port already in use (an Alertmanager or exporter of your own) skips that part; Prometheus then talks to that one.
# OTLP (/api/v1/otlp/v1/metrics) and remote write (/api/v1/write) receivers are on (otel.sh).
# A local Grafana (package, or grafana.sh --docker in the host network) gets a Prometheus datasource when it has none.
# No login: Prometheus, Alertmanager and the exporters have no users, use --local or a reverse proxy when the network
# is not trusted.
# RAM: about 150 MB for a few hosts (grows with the number of series) plus 20-30 MB per exporter and Alertmanager.
# Running again updates binaries or images and keeps configs and data.
# category: monitoring
# ports: PROMETHEUS_PORT=9090 ALERTMANAGER_PORT=9093 BLACKBOX_PORT=9115 NODE_EXPORTER_PORT=9100@node_exporter
# check: prometheus.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ $# -eq 0 ] || dot_die "unknown argument '$1', usage: prometheus.sh [--docker|--portainer] [--public|--local]"

dir=$(dirname "$(readlink -f "$0")")
# address and port of an earlier run (unit or compose file, Prometheus comes first there) stay unless given again: an
# update must not move Prometheus or cut off the hosts that send to it
old=$(dot_sudo sed -n 's/.*--web.listen-address=\([^ "]*\).*/\1/p' /etc/systemd/system/prometheus.service \
  /opt/prometheus/compose.yaml 2>/dev/null | head -n 1)
port=${PROMETHEUS_PORT:-${old##*:}}
port=${port:-9090}
# the same for the other parts: their unit, else their line in the compose file, found by its config file or flag
# (28.10.26, review: a second run put Alertmanager and blackbox back on 9093 and 9115)
old_port() {
  dot_sudo sed -n "/$2/s/.*--web.listen-address=[^ \"]*:\([0-9]*\).*/\1/p" "/etc/systemd/system/$1.service" \
    /opt/prometheus/compose.yaml 2>/dev/null | head -n 1
}
neport=${NODE_EXPORTER_PORT:-$(old_port node_exporter 'path\.rootfs\|node_exporter --')}
neport=${neport:-9100}
amport=${ALERTMANAGER_PORT:-$(old_port alertmanager 'alertmanager\.yml')}
amport=${amport:-9093}
bbport=${BLACKBOX_PORT:-$(old_port blackbox-exporter 'blackbox\.yml')}
bbport=${bbport:-9115}
nxport=${NGINX_EXPORTER_PORT:-$(old_port nginx-exporter 'nginx\.scrape-uri')}
nxport=${nxport:-9113}
retention=${PROMETHEUS_RETENTION:-15d}
dest=/opt/prometheus
bin=/usr/local/bin/prometheus
for p in "$port" "$neport" "$amport" "$bbport" "$nxport"; do
  case $p in ''|*[!0-9]*) dot_die "ports must be numbers, got '$p'" ;; esac
done
[[ $retention =~ ^[0-9]+(ms|s|m|h|d|w|y)$ ]] || dot_die "PROMETHEUS_RETENTION must be a duration like 15d or 8w, got '$retention'"
[ -z "${PROMETHEUS_NGINX_URL:-}" ] || [[ $PROMETHEUS_NGINX_URL =~ ^https?://[^[:space:]\"\'\$\\]+$ ]] ||
  dot_die "PROMETHEUS_NGINX_URL must be an http(s) URL, got '$PROMETHEUS_NGINX_URL'"

# prints the starter prometheus.yml; OTLP settings follow the Prometheus OpenTelemetry guide
prom_config() {
  cat <<EOF
# Prometheus config, written by prometheus.sh on the first run and yours from now on (the installer keeps it).
# Check: promtool check config prometheus.yml   Apply: $reload
global:
  scrape_interval: 30s
  evaluation_interval: 30s

storage:
  tsdb:
    retention:
      time: $retention
    # OTLP and remote write senders (otel.sh) may deliver samples a little late
    out_of_order_time_window: 30m

# metrics pushed by the OpenTelemetry Collector to /api/v1/otlp: these resource attributes become labels
otlp:
  promote_resource_attributes: [service.instance.id, service.name, service.namespace, service.version,
                                deployment.environment.name, host.name, container.name]

rule_files:
  - rules/*.yml

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["$host:$port"]
        labels:
          instance: $(uname -n)

  - job_name: node
    static_configs:
      - targets: ["$host:$neport"]
        labels:
          instance: $(uname -n)
      # more hosts running node_exporter.sh (the instance label defaults to host:port):
      # - targets: ["192.0.2.10:9100"]

$(alerting_block)

$(scrape_files_block)
EOF
}

# the top-level blocks a prometheus.yml of an earlier run may lack (prom_patch appends them)
alerting_block() {
  cat <<EOF
# alerts of rules/ go to the Alertmanager; who gets notified is set in alertmanager.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["$host:$amport"]
EOF
}
scrape_files_block() {
  cat <<'EOF'
# more scrape jobs, one file per topic (alertmanager, blackbox probes, nginx, your own); format: scrape_configs: [...]
scrape_config_files:
  - scrape.d/*.yml
EOF
}

# appends the blocks of alerting_block and scrape_files_block to an older prometheus.yml that has none of its own
# (keeps a copy as prometheus.yml.bak); prom_check puts the copy back when the result is not valid
prom_patch() {
  local f=$conf/prometheus.yml add=
  dot_sudo grep -q '^alerting:' "$f" || add+=$'\n'$(alerting_block)$'\n'
  dot_sudo grep -q '^scrape_config_files:' "$f" || add+=$'\n'$(scrape_files_block)$'\n'
  [ -n "$add" ] || return 0
  dot_sudo cp -p "$f" "$f.bak"
  printf '\n# added by prometheus.sh on %s%s' "$(date +%F)" "$add" | dot_sudo tee -a "$f" >/dev/null
  dot_info "added the missing alerting or scrape_config_files block to $f (before: $f.bak)"
  patched=1
}

# checks prometheus.yml with the rules and scrape files it names; a patched file goes back to its copy when it fails
prom_check() {
  local out
  if [ "$DOT_MODE" = native ]; then
    out=$(dot_sudo /usr/local/bin/promtool check config "$conf/prometheus.yml" 2>&1)
  else
    dot_docker_ready prometheus
    out=$(dot_sudo docker run --rm --entrypoint /bin/promtool -v "$conf:/etc/prometheus:ro" prom/prometheus:v3 \
      check config /etc/prometheus/prometheus.yml 2>&1)
  fi || {
    echo "$out" >&2
    [ -z "$patched" ] || { dot_sudo mv "$conf/prometheus.yml.bak" "$conf/prometheus.yml"; dot_info "restored the old $conf/prometheus.yml"; }
    dot_die "$conf/prometheus.yml is not valid"
  }
}

# prints rules/node.yml: recording rules and alerts on node_exporter 1.x metrics and the textfile example
prom_rules() {
  cat <<'EOF'
# Example rules, written by prometheus.sh on the first run and yours from now on. Firing alerts: Prometheus UI > Alerts.
groups:
  - name: node-recording
    rules:
      - record: instance:node_cpu_utilisation:rate5m
        expr: 1 - avg without (cpu, mode) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
      - record: instance:node_memory_utilisation:ratio
        expr: 1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
      - record: instance:node_load5_per_cpu:ratio
        expr: node_load5 / count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})

  - name: node-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} (job {{ $labels.job }}) cannot be scraped"
      - alert: DiskAlmostFull
        expr: |
          node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|fuse.lxcfs"}
            / node_filesystem_size_bytes < 0.10
          and node_filesystem_readonly == 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.mountpoint }} on {{ $labels.instance }} has only {{ $value | humanizePercentage }} free"
      - alert: HighLoad
        expr: instance:node_load5_per_cpu:ratio > 2
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "load on {{ $labels.instance }} is {{ $value | printf \"%.1f\" }} per CPU"
      - alert: MemoryPressure
        expr: instance:node_memory_utilisation:ratio > 0.90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.instance }} uses {{ $value | humanizePercentage }} of its memory"
      - alert: TextfileMetricsStale
        expr: time() - node_textfile_mtime_seconds > 3600
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.file }} on {{ $labels.instance }} was not updated for an hour (script or timer broken?)"
      - alert: RebootRequired
        expr: custom_reboot_required == 1
        for: 24h
        labels:
          severity: info
        annotations:
          summary: "{{ $labels.instance }} waits for a reboot since a day"
EOF
}

# rules/alertmanager.yml
am_rules() {
  cat <<'EOF'
# Example rules, written by prometheus.sh on the first run and yours from now on.
groups:
  - name: alertmanager
    rules:
      - alert: AlertmanagerDown
        expr: absent(up{job="alertmanager"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "the Alertmanager cannot be scraped: alerts are not sent"
      - alert: PrometheusAlertmanagerMissing
        expr: prometheus_notifications_alertmanagers_discovered < 1
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} knows no Alertmanager (alerting: in prometheus.yml)"
      - alert: AlertmanagerNotificationsFailing
        expr: rate(alertmanager_notifications_failed_total[5m]) > 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "the Alertmanager fails to send to {{ $labels.integration }} (see its log)"
EOF
}

# rules/blackbox.yml
bb_rules() {
  cat <<'EOF'
# Example rules, written by prometheus.sh on the first run and yours from now on.
groups:
  - name: blackbox
    rules:
      - alert: BlackboxExporterDown
        expr: absent(up{job="blackbox"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "the blackbox exporter cannot be scraped: no probes run"
      - alert: ProbeFailed
        expr: probe_success == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "probe of {{ $labels.instance }} (job {{ $labels.job }}) fails"
      - alert: TLSCertificateExpiresSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 14 * 86400
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "TLS certificate of {{ $labels.instance }} expires in {{ $value | humanizeDuration }}"
EOF
}

# rules/nginx.yml
nx_rules() {
  cat <<'EOF'
# Example rules, written by prometheus.sh on the first run and yours from now on.
groups:
  - name: nginx
    rules:
      - alert: NginxExporterDown
        expr: absent(up{job="nginx"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "the nginx exporter cannot be scraped"
      - alert: NginxDown
        expr: nginx_up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "the nginx exporter on {{ $labels.instance }} cannot read the stub_status page"
EOF
}

# scrape.d/alertmanager.yml, scrape.d/blackbox.yml, scrape.d/nginx.yml
am_scrape() {
  cat <<EOF
# written by prometheus.sh on the first run, yours from now on
scrape_configs:
  - job_name: alertmanager
    static_configs:
      - targets: ["$host:$amport"]
        labels:
          instance: $(uname -n)
EOF
}
bb_scrape() {
  cat <<EOF
# Probes of the blackbox exporter (modules in blackbox.yml), written by prometheus.sh on the first run, yours from now
# on. Add targets to a job; the relabeling hands each one to the exporter as ?target=. Failed probes: rules/blackbox.yml
scrape_configs:
  - job_name: blackbox
    static_configs:
      - targets: ["$host:$bbport"]
        labels:
          instance: $(uname -n)

  # HTTP(S) answers with 2xx; also reports the TLS certificate expiry
  - job_name: blackbox-http
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets: ["https://example.org"]
    relabel_configs: &probe
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: $host:$bbport

  # a TCP port accepts connections (SSH, a database, MQTT)
  # - job_name: blackbox-tcp
  #   metrics_path: /probe
  #   params:
  #     module: [tcp_connect]
  #   static_configs:
  #     - targets: ["192.0.2.10:22"]
  #   relabel_configs: *probe

  # ping
  # - job_name: blackbox-icmp
  #   metrics_path: /probe
  #   params:
  #     module: [icmp]
  #   static_configs:
  #     - targets: ["192.0.2.1"]
  #   relabel_configs: *probe
EOF
}
nx_scrape() {
  cat <<EOF
# written by prometheus.sh on the first run, yours from now on
scrape_configs:
  - job_name: nginx
    static_configs:
      - targets: ["$host:$nxport"]
        labels:
          instance: $(uname -n)
EOF
}

# alertmanager.yml: a receiver that sends nothing, commented examples
am_config() {
  cat <<EOF
# Alertmanager config, written by prometheus.sh on the first run and yours from now on (the installer keeps it).
# Check: amtool check-config alertmanager.yml   Apply: $amreload   Test: prom-test-alert.sh
# Alerts are listed at http://<host>:$amport. To get them, uncomment a receiver below and set route.receiver to it.
# Passwords and tokens can stay out of this file: the *_file settings read them from a file next to it
# ($conf/<name>, /etc/prometheus/<name> as the Alertmanager sees it), e.g. chmod 0640 and group of this file.
route:
  receiver: "null"
  group_by: [alertname, instance]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  # only critical alerts by mail, the rest stays with the default receiver:
  # routes:
  #   - matchers: ['severity="critical"']
  #     receiver: mail

receivers:
  # sends nothing: the alerts are visible in the Alertmanager UI only
  - name: "null"

  # E-mail over a smarthost with STARTTLS
  # - name: mail
  #   email_configs:
  #     - to: alerts@example.org
  #       from: prometheus@example.org
  #       smarthost: smtp.example.org:587
  #       auth_username: prometheus@example.org
  #       auth_password_file: /etc/prometheus/smtp-password
  #       send_resolved: true

  # Webhook: POSTs the alerts as JSON (format: Alertmanager docs, webhook_config)
  # - name: webhook
  #   webhook_configs:
  #     - url: https://example.org/alert-hook
  #       send_resolved: true

  # Telegram: token from @BotFather, chat id of the user or group
  # - name: telegram
  #   telegram_configs:
  #     - bot_token_file: /etc/prometheus/telegram-token
  #       chat_id: -1001234567890
  #       send_resolved: true

  # Slack: incoming webhook URL in a file
  # - name: slack
  #   slack_configs:
  #     - api_url_file: /etc/prometheus/slack-webhook-url
  #       channel: "#alerts"
  #       send_resolved: true

  # ntfy: its alertmanager template turns the webhook JSON into a readable message
  # - name: ntfy
  #   webhook_configs:
  #     - url: https://ntfy.sh/my-alerts?template=alertmanager
  #       send_resolved: true
EOF
}

# blackbox.yml: the modules the probes in scrape.d/blackbox.yml name
bb_config() {
  cat <<'EOF'
# blackbox exporter modules, written by prometheus.sh on the first run and yours from now on.
# Try one: curl 'http://localhost:9115/probe?module=http_2xx&target=https://example.org&debug=true'
modules:
  http_2xx:
    prober: http
    timeout: 10s
    http:
      preferred_ip_protocol: ip4
      follow_redirects: true
  tcp_connect:
    prober: tcp
    timeout: 5s
    tcp:
      preferred_ip_protocol: ip4
  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: ip4
EOF
}

# /usr/local/bin/prom-test-alert.sh
test_alert_script() {
  cat <<EOF
#!/bin/sh
# Sends a test alert to the Alertmanager (written by prometheus.sh, yours to change). It shows up in the Alertmanager
# UI, goes to the receiver of alertmanager.yml and resolves itself after 5 minutes.
#   prom-test-alert.sh [severity]     ALERTMANAGER_URL=http://192.0.2.10:9093 prom-test-alert.sh
set -eu
url=\${ALERTMANAGER_URL:-http://$host:$amport}
start=\$(date -u +%Y-%m-%dT%H:%M:%SZ)
end=\$(date -u -d '+5 min' +%Y-%m-%dT%H:%M:%SZ)
curl -fsS -X POST -H 'Content-Type: application/json' "\$url/api/v2/alerts" -d "[{
  \"labels\": {\"alertname\": \"TestAlert\", \"severity\": \"\${1:-info}\", \"instance\": \"\$(uname -n)\"},
  \"annotations\": {\"summary\": \"test alert from prom-test-alert.sh\"},
  \"startsAt\": \"\$start\", \"endsAt\": \"\$end\"}]"
echo "test alert sent to \$url"
EOF
}

# prints the stub_status URL for the nginx exporter: PROMETHEUS_NGINX_URL, the one of an earlier run, a local page
nginx_url() {
  local u
  [ -n "${PROMETHEUS_NGINX_URL:-}" ] && { echo "$PROMETHEUS_NGINX_URL"; return; }
  u=$(sed -n 's/.*--nginx\.scrape-uri=\([^ ]*\).*/\1/p' /etc/systemd/system/nginx-exporter.service 2>/dev/null)
  [ -n "$u" ] && { echo "$u"; return; }
  for u in http://127.0.0.1/nginx_status http://127.0.0.1/stub_status; do
    curl -fsS -m 3 "$u" 2>/dev/null | grep -q '^Active connections:' && { echo "$u"; return; }
  done
}

# true when this installer runs the part <name> (unit or compose service) here: it did before, or <port> is free
ours() {
  if [ "$DOT_MODE" = native ]; then
    [ -f "/etc/systemd/system/$1.service" ] && return 0
  else
    dot_sudo grep -qs "^  $1:" "$dest/compose.yaml" && return 0
  fi
  dot_port_busy "$2" || return 0
  dot_info "port $2 is in use, assuming a $1 of your own: not installing one, Prometheus uses that one"
  return 1
}

# installs binaries of the latest release of github.com/prometheus/<project> into /usr/local/bin unless that version
# is there: prom_binary <project> <binary…> (the first one tells the installed version)
prom_binary() {
  local p=$1 tag; shift
  tag=$(dot_github_latest "prometheus/$p") || dot_die "could not find the latest $p release"
  if [ -x "/usr/local/bin/$1" ] && "/usr/local/bin/$1" --version 2>&1 | grep -qF "version ${tag#v} "; then
    dot_info "$p $tag is already installed"
    return 0
  fi
  dot_prometheus_release "$p" "$tag" "$tmp"
  (cd "$tmp/$p-${tag#v}.linux-$DOT_ARCH" && dot_sudo install -m 0755 "$@" /usr/local/bin/) || dot_die "could not install $p"
}

# nginx-prometheus-exporter from github.com/nginx (GoReleaser names, sha256 from GitHub's digest)
nx_binary() {
  local tag f=/usr/local/bin/nginx-prometheus-exporter
  tag=$(dot_github_latest nginx/nginx-prometheus-exporter) || dot_die "could not find the latest nginx exporter release"
  if [ -x "$f" ] && "$f" --version 2>&1 | grep -qF "version ${tag#v} "; then
    dot_info "nginx-prometheus-exporter $tag is already installed"
    return 0
  fi
  dot_github_fetch nginx/nginx-prometheus-exporter "_linux_$DOT_ARCH\.tar\.gz\$" "$tmp/nx.tar.gz" "$tag" &&
    tar -xzf "$tmp/nx.tar.gz" -C "$tmp" nginx-prometheus-exporter && dot_sudo install -m 0755 "$tmp/nginx-prometheus-exporter" "$f" ||
    dot_die "could not install the nginx exporter"
}

# writes the systemd unit <name> (ours: rewritten on every run, like the binary) and restarts it:
# prom_unit <name> <description> <ExecStart> [more [Service] lines]
prom_unit() {
  dot_sudo tee "/etc/systemd/system/$1.service" >/dev/null <<EOF
[Unit]
Description=$2
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=$3
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
${4:-}

[Install]
WantedBy=multi-user.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable "$1" >/dev/null 2>&1
  dot_sudo systemctl restart "$1" || dot_die "$1 does not start, see: journalctl -u $1"
}

# adds a Prometheus datasource to a local Grafana (package or /opt/grafana) unless one is provisioned already
grafana_datasource() {
  local d url=http://$host:$port
  if [ -d /etc/grafana/provisioning/datasources ]; then
    d=/etc/grafana/provisioning/datasources
  elif [ "$gd" = host ]; then
    # Grafana in Docker in the host network reaches Prometheus on 127.0.0.1 like a native one
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
  if dot_sudo grep -rqs 'type: *prometheus' "$d"; then
    dot_info "Grafana has a Prometheus datasource already ($d)"
    return 0
  fi
  dot_sudo tee "$d/prometheus.yaml" >/dev/null <<EOF
# written by prometheus.sh
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: $url
    jsonData:
      httpMethod: POST
EOF
  dot_sudo chmod 0644 "$d/prometheus.yaml"
  if [ "$d" = /etc/grafana/provisioning/datasources ] && [ -d /run/systemd/system ]; then
    dot_sudo systemctl try-restart grafana-server
    dot_info "Grafana: added datasource Prometheus ($url) in $d/prometheus.yaml"
  elif [ "$gd" = host ] && dot_stack_running grafana; then
    dot_sudo docker restart grafana >/dev/null
    dot_info "Grafana (Docker): added datasource Prometheus ($url) in $d/prometheus.yaml"
  else
    dot_info "Grafana: added datasource Prometheus ($url) in $d/prometheus.yaml, restart Grafana to load it"
  fi
}

for u in /lib/systemd/system/prometheus.service /usr/lib/systemd/system/prometheus.service; do
  [ -f "$u" ] && dot_die "Prometheus from a distro package is installed ($u): remove it first, prometheus.sh installs the upstream release"
done
# no login, so this host only by default. Grafana in Docker from an older grafana.sh runs in the bridge network and
# reaches the host's address only, not its 127.0.0.1: then all interfaces as before. grafana.sh puts it in the host
# network since 28.10.26 (the old test looked for /opt/grafana/provisioning, which grafana.sh never made).
def=127.0.0.1 gd=$(dot_grafana_docker)
if [ ! -d /etc/grafana/provisioning/datasources ] && [ "$gd" = bridge ]; then
  def=0.0.0.0
  [ -n "$old" ] || [ -n "${BIND_ADDR:-}" ] || dot_info "Grafana runs in Docker here: listening on all interfaces"
fi
dot_bind "$def" "${old%:*}"
dot_need curl tar
# the address local clients use: the listen address, 127.0.0.1 when listening on all interfaces
host=$DOT_BIND
[ "$host" = 0.0.0.0 ] && host=127.0.0.1
flags="--web.listen-address=$DOT_BIND:$port --web.enable-otlp-receiver --web.enable-remote-write-receiver"
patched=

# one installation per host: native and container would fight over the port
if [ "$DOT_MODE" = native ] && dot_sudo test -f "$dest/compose.yaml"; then
  dot_info "Prometheus runs in Docker here ($dest/compose.yaml), staying with compose (--portainer for a Portainer stack)"
  DOT_MODE=compose
fi
[ "$DOT_MODE" != native ] && [ -f /etc/systemd/system/prometheus.service ] &&
  dot_die "Prometheus runs natively here (prometheus.service): use --native"
if [ ! -f /etc/systemd/system/prometheus.service ] && ! dot_sudo test -f "$dest/compose.yaml" && dot_port_busy "$port"; then
  dot_die "port $port is in use by another program: set PROMETHEUS_PORT"
fi

# the parts this run installs or keeps (1) besides Prometheus and node_exporter
am= bb= nx= nxurl=
ours alertmanager "$amport" && am=1
ours blackbox-exporter "$bbport" && bb=1
if [ "$DOT_MODE" != native ] && dot_sudo grep -qs '^  nginx-exporter:' "$dest/compose.yaml"; then
  nx=1
else
  nxurl=$(nginx_url)
  [ -n "$nxurl" ] && ours nginx-exporter "$nxport" && nx=1
fi

if [ "$DOT_MODE" = native ]; then
  conf=/etc/prometheus reload="sudo systemctl reload prometheus" amreload="sudo systemctl reload alertmanager" grp=prometheus
  case $DOT_ARCH in amd64|arm64|armv7|armv6) ;; *) dot_die "Prometheus has no release for architecture $DOT_ARCH" ;; esac
  getent passwd prometheus >/dev/null ||
    dot_sudo useradd --system --home-dir /var/lib/prometheus --no-create-home --shell /usr/sbin/nologin prometheus ||
    dot_die "could not create the user prometheus"
  dot_sudo install -d -m 0750 -o prometheus -g prometheus /var/lib/prometheus /var/lib/alertmanager || exit 1
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  prom_binary prometheus prometheus promtool
  [ -z "$am" ] || prom_binary alertmanager alertmanager amtool
  [ -z "$bb" ] || prom_binary blackbox_exporter blackbox_exporter
  [ -z "$nx" ] || nx_binary
else
  conf=$dest/config reload="sudo docker kill -s HUP prometheus" amreload="sudo docker kill -s HUP alertmanager" grp=65534
  dot_sudo install -d -m 0755 "$dest" || exit 1
  # the images run as nobody (65534)
  [ -z "$am" ] || dot_sudo install -d -m 0750 -o 65534 -g 65534 "$dest/alertmanager" || exit 1
fi
dot_sudo install -d -m 0755 "$conf" "$conf/rules" "$conf/scrape.d" || exit 1
prom_config | dot_put_new "$conf/prometheus.yml"
prom_rules | dot_put_new "$conf/rules/node.yml"
# the Alertmanager's scrape job and rules also serve one of your own (port in use)
am_scrape | dot_put_new "$conf/scrape.d/alertmanager.yml"
am_rules | dot_put_new "$conf/rules/alertmanager.yml"
if [ -n "$am" ]; then
  am_config | dot_put_new "$conf/alertmanager.yml"
  # may get SMTP passwords or tokens later: not for everyone
  dot_sudo chown "root:$grp" "$conf/alertmanager.yml" && dot_sudo chmod 0640 "$conf/alertmanager.yml"
fi
bb_scrape | dot_put_new "$conf/scrape.d/blackbox.yml"
bb_rules | dot_put_new "$conf/rules/blackbox.yml"
[ -z "$bb" ] || bb_config | dot_put_new "$conf/blackbox.yml"
if [ -n "$nx" ]; then
  nx_scrape | dot_put_new "$conf/scrape.d/nginx.yml"
  nx_rules | dot_put_new "$conf/rules/nginx.yml"
fi
test_alert_script | dot_put_new /usr/local/bin/prom-test-alert.sh
dot_sudo chmod 0755 /usr/local/bin/prom-test-alert.sh
for f in prometheus.yml blackbox.yml rules/{node,alertmanager,blackbox,nginx}.yml scrape.d/{alertmanager,blackbox,nginx}.yml; do
  ! dot_sudo test -f "$conf/$f" || dot_sudo chmod 0644 "$conf/$f"
done
prom_patch
prom_check

if [ "$DOT_MODE" = native ]; then
  [ -z "$am" ] || out=$(dot_sudo /usr/local/bin/amtool check-config "$conf/alertmanager.yml" 2>&1) ||
    { echo "$out" >&2; dot_die "$conf/alertmanager.yml is not valid"; }
  [ -z "$bb" ] || out=$(dot_sudo /usr/local/bin/blackbox_exporter --config.check --config.file="$conf/blackbox.yml" 2>&1) ||
    { echo "$out" >&2; dot_die "$conf/blackbox.yml is not valid"; }
  # single Alertmanager: no cluster port (9094)
  amcmd="/usr/local/bin/alertmanager --config.file=$conf/alertmanager.yml --storage.path=/var/lib/alertmanager --web.listen-address=$DOT_BIND:$amport --cluster.listen-address="
  bbcmd="/usr/local/bin/blackbox_exporter --config.file=$conf/blackbox.yml --web.listen-address=$DOT_BIND:$bbport"
  nxcmd="/usr/local/bin/nginx-prometheus-exporter --nginx.scrape-uri=$nxurl --web.listen-address=$DOT_BIND:$nxport"
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start the parts with:"
    dot_info "  sudo -u prometheus $bin --config.file=$conf/prometheus.yml --storage.tsdb.path=/var/lib/prometheus $flags"
    [ -z "$am" ] || dot_info "  sudo -u prometheus $amcmd"
    [ -z "$bb" ] || dot_info "  sudo $bbcmd"
    [ -z "$nx" ] || dot_info "  sudo -u prometheus $nxcmd"
    NODE_EXPORTER_PORT=$neport bash "$dir/node_exporter.sh" --native </dev/null
    exit 0
  fi
  prom_unit prometheus "Prometheus monitoring" \
    "$bin --config.file=$conf/prometheus.yml --storage.tsdb.path=/var/lib/prometheus $flags" \
    "ExecReload=/bin/kill -HUP \$MAINPID
TimeoutStopSec=60
LimitNOFILE=65536"
  [ -z "$am" ] || prom_unit alertmanager "Prometheus Alertmanager" "$amcmd" "ExecReload=/bin/kill -HUP \$MAINPID
StateDirectory=alertmanager"
  # ICMP probes need raw sockets
  [ -z "$bb" ] || prom_unit blackbox-exporter "Prometheus blackbox exporter" "$bbcmd" "ExecReload=/bin/kill -HUP \$MAINPID
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW"
  [ -z "$nx" ] || prom_unit nginx-exporter "Prometheus nginx exporter" "$nxcmd"
  # with its port as read above: on its own, node_exporter.sh went back to 9100 in a second run (28.10.26)
  NODE_EXPORTER_PORT=$neport bash "$dir/node_exporter.sh" --native </dev/null || dot_die "node_exporter.sh failed"
else
  bash "$dir/node_exporter.sh" textfile </dev/null || dot_die "the textfile example of node_exporter.sh failed"
  # first run: the stack gets a node-exporter unless one runs on this host already (node_exporter.sh or a package)
  ne=
  if ! dot_sudo test -f "$dest/compose.yaml" && dot_port_busy "$neport"; then
    dot_info "port $neport is in use, assuming a node_exporter: the stack gets none, Prometheus scrapes that one"
  else
    # rslave (node_exporter README) needs / to be a shared or slave mount, Docker refuses it on a private one
    prop=
    case $(findmnt -no PROPAGATION / 2>/dev/null) in shared*|slave*) prop=,rslave ;; esac
    ne="
  node-exporter:
    image: prom/node-exporter:v1
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    command: \"--path.rootfs=/host --web.listen-address=$DOT_BIND:$neport --collector.textfile.directory=/host/var/lib/node_exporter/textfile\"
    volumes:
      - /:/host:ro$prop"
  fi
  # the further services; an older compose.yaml gets those it lacks
  add=
  dot_sudo grep -qs '^  alertmanager:' "$dest/compose.yaml" || [ -z "$am" ] || add+="
  alertmanager:
    image: prom/alertmanager:v0
    container_name: alertmanager
    restart: unless-stopped
    network_mode: host
    command: \"--config.file=/etc/prometheus/alertmanager.yml --storage.path=/alertmanager --web.listen-address=$DOT_BIND:$amport --cluster.listen-address=\"
    volumes:
      - $conf:/etc/prometheus:ro
      - $dest/alertmanager:/alertmanager"
  dot_sudo grep -qs '^  blackbox-exporter:' "$dest/compose.yaml" || [ -z "$bb" ] || add+="
  blackbox-exporter:
    image: prom/blackbox-exporter:v0
    container_name: blackbox-exporter
    restart: unless-stopped
    network_mode: host
    cap_add: [NET_RAW]
    command: \"--config.file=/etc/prometheus/blackbox.yml --web.listen-address=$DOT_BIND:$bbport\"
    volumes:
      - $conf:/etc/prometheus:ro"
  dot_sudo grep -qs '^  nginx-exporter:' "$dest/compose.yaml" || [ -z "$nx" ] || add+="
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:1
    container_name: nginx-exporter
    restart: unless-stopped
    network_mode: host
    command: \"--nginx.scrape-uri=$nxurl --web.listen-address=$DOT_BIND:$nxport\""
  if [ -n "$add" ] && dot_sudo test -f "$dest/compose.yaml"; then
    # in front of the first top-level key after services: (volumes:), else at the end
    dot_sudo cp -p "$dest/compose.yaml" "$dest/compose.yaml.bak"
    dot_sudo cat "$dest/compose.yaml.bak" | ADD=$add awk '
      in_s && !done && /^[A-Za-z]/ { print substr(ENVIRON["ADD"], 2); done = 1 }
      /^services:/ { in_s = 1 }
      { print }
      END { if (!done) print substr(ENVIRON["ADD"], 2) }' | dot_sudo tee "$dest/compose.yaml" >/dev/null
    dot_docker_ready prometheus
    if dot_sudo docker compose -f "$dest/compose.yaml" --project-directory "$dest" config -q; then
      dot_info "added the missing services to $dest/compose.yaml (before: $dest/compose.yaml.bak)"
    else
      dot_sudo mv "$dest/compose.yaml.bak" "$dest/compose.yaml"
      dot_die "could not add the missing services to $dest/compose.yaml, add them by hand:$add"
    fi
  fi
  dot_deploy prometheus "services:
  prometheus:
    image: prom/prometheus:v3
    container_name: prometheus
    restart: unless-stopped
    network_mode: host
    command: \"--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus $flags\"
    volumes:
      - $conf:/etc/prometheus:ro
      - prometheus_data:/prometheus$ne$add
volumes:
  prometheus_data:"
  [ -n "${DOT_NO_START:-}" ] && exit 0
  # files new in scrape.d/ and rules/: compose leaves an unchanged container running
  dot_sudo docker kill -s HUP prometheus >/dev/null 2>&1
fi

dot_wait_http "http://$host:$port/-/ready" 30 || dot_die "Prometheus is not ready on $host:$port after 30 s, see its log"
[ -z "$am" ] || dot_wait_http "http://$host:$amport/-/ready" 30 ||
  dot_die "the Alertmanager is not ready on $host:$amport after 30 s, see its log"
[ -z "$bb" ] || dot_wait_http "http://$host:$bbport/-/healthy" 30 ||
  dot_die "the blackbox exporter does not answer on $host:$bbport after 30 s, see its log"
[ -z "$nx" ] || dot_wait_http "http://$host:$nxport/metrics" 30 ||
  dot_die "the nginx exporter does not answer on $host:$nxport after 30 s, see its log"
grafana_datasource

case $DOT_BIND in 0.0.0.0|127.0.0.1) shown=localhost ;; *) shown=$DOT_BIND ;; esac
addrs="http://$shown:$port http://$shown:$neport/metrics"
[ -z "$am" ] || addrs+=" http://$shown:$amport"
[ -z "$bb" ] || addrs+=" http://$shown:$bbport"
[ -z "$nx" ] || addrs+=" http://$shown:$nxport/metrics"
dot_summary prometheus "$addrs" \
  "none (Prometheus, Alertmanager and exporters have no auth; use 127.0.0.1 (--local) or a reverse proxy)"
printf '  config:  %s/prometheus.yml, scrape jobs in %s/scrape.d/, rules in %s/rules/ (apply: %s)\n' \
  "$conf" "$conf" "$conf" "$reload"
[ -z "$am" ] || printf '  alerts:  %s/alertmanager.yml sends nothing yet, see its examples (apply: %s); test: prom-test-alert.sh\n' \
  "$conf" "$amreload"
[ -z "$bb" ] || printf '  probes:  %s/scrape.d/blackbox.yml (example https://example.org), modules in %s/blackbox.yml\n' "$conf" "$conf"
printf '  example: /usr/local/bin/prom-textfile-example.sh -> /var/lib/node_exporter/textfile/example.prom\n'
printf '  push:    OTLP http://%s:%s/api/v1/otlp/v1/metrics, remote write http://%s:%s/api/v1/write\n' \
  "$shown" "$port" "$shown" "$port"
if [ -z "$nx" ]; then
  printf '  nginx:   no stub_status page found, so no nginx exporter. To add it, put this in a server block of nginx,\n'
  printf '           reload nginx and run prometheus.sh again (or set PROMETHEUS_NGINX_URL to an existing page):\n'
  printf '             location = /nginx_status { stub_status; allow 127.0.0.1; deny all; }\n'
fi
