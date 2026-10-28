#!/bin/bash
# installer: OpenTelemetry Collector (contrib), optional Tempo, Prometheus, Loki and Grafana
# systems: debian fedora rhel amd64 arm64
# modes: native compose portainer
# OpenTelemetry Collector contrib with OTLP (gRPC 4317, HTTP 4318) and host metrics, memory_limiter and batch.
#   otel.sh                 collector only: exports to OTEL_EXPORT_OTLP=http(s)://host:4318 if set, else to the local
#                           backends otel.sh or loki.sh installed before, else to the debug exporter (collector log)
#   otel.sh stack           (or --stack) the collector plus traces -> Tempo, metrics -> Prometheus 3 (OTLP receiver),
#                           logs -> Loki and Grafana with provisioned datasources (trace <-> logs links)
#   otel.sh lgtm            grafana/otel-lgtm all-in-one container (demo and development only, not for real data)
#   OTEL_KIND=collector|stack|lgtm   the same as environment variable (the menu asks); an argument adds to it
#   otel.sh … --no-start    install and configure only, start nothing (stops what packages start by themselves)
#   otel.sh … --public|--local   OTLP receivers and UIs on all interfaces (default) or on this host only
#   OTEL_GRPC_PORT=4317 OTEL_HTTP_PORT=4318 TEMPO_PORT=3200   other ports
#   GRAFANA_PORT=3000 LOKI_PORT=3100 OTEL_PROMETHEUS_PORT=9090   other ports in Docker (natively the installers of
#                           Grafana, Loki and Prometheus own them; PROMETHEUS_PORT would move a native Prometheus)
#   GRAFANA_ADMIN_PASSWORD=…  Grafana admin password in Docker (else generated), kept in /opt/otel/.env (0600)
# native:   collector .deb or .rpm from the GitHub release (sha256 checked, unit and user from the package), Tempo from
#           apt.grafana.com or rpm.grafana.com; prometheus.sh, loki.sh and grafana.sh when Prometheus, Loki or Grafana are missing
#           (Prometheus needs --web.enable-otlp-receiver, otel.sh warns when it is off)
# --docker / --portainer:  compose project "otel" (configs in /opt/otel, data in named volumes), images :latest
# RAM: collector alone about 100 MB (128 MB is enough); the stack needs about 1 GB, 2 GB to work with it; lgtm 1.5 GB.
# Configs carrying the line "written by otel.sh" are rewritten on every run (remove the line to keep your edits);
# a config from a package is kept once as <file>.orig. Running again updates binaries and images.
# category: monitoring
# ports: OTEL_GRPC_PORT=4317 OTEL_HTTP_PORT=4318 OTEL_KIND=lgtm:GRAFANA_PORT=3000 OTEL_KIND=stack:TEMPO_PORT=3200
# natively the stack reuses what grafana.sh, loki.sh and prometheus.sh run (@), in Docker it brings its own
# ports: OTEL_KIND=stack:INSTALL_MODE=compose,portainer:GRAFANA_PORT=3000
# ports: OTEL_KIND=stack:INSTALL_MODE=compose,portainer:LOKI_PORT=3100
# ports: OTEL_KIND=stack:INSTALL_MODE=native:3000@grafana OTEL_KIND=stack:INSTALL_MODE=native:3100@loki
# ports: OTEL_KIND=stack:INSTALL_MODE=compose,portainer:OTEL_PROMETHEUS_PORT=9090
# ports: OTEL_KIND=stack:INSTALL_MODE=native:PROMETHEUS_PORT=9090@prometheus
# check: otelcol-contrib.service stack:otel stack:otel-lgtm
# ask: OTEL_KIND=collector|stack|lgtm "collector only, stack (with Tempo, Prometheus, Loki, Grafana) or lgtm (demo)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

dir=$(dirname "$(readlink -f "$0")")
mark='# written by otel.sh, remove this line to keep your edits'
stack= lgtm= nostart=
case ${OTEL_KIND:-} in
  ''|collector) ;;
  stack) stack=1 ;;
  lgtm) lgtm=1 ;;
  *) dot_die "OTEL_KIND must be collector, stack or lgtm, got '$OTEL_KIND'" ;;
esac
for a in "$@"; do
  case $a in
    stack|--stack) stack=1 ;;
    lgtm|--lgtm) lgtm=1 ;;
    --no-start) nostart=1 ;;
    -h|--help) sed -n '5,23s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) dot_die "unknown argument '$a', usage: otel.sh [stack|lgtm] [--no-start] [--docker|--portainer] [--public|--local]" ;;
  esac
done
grpc=${OTEL_GRPC_PORT:-4317} http=${OTEL_HTTP_PORT:-4318} prom=${OTEL_PROMETHEUS_PORT:-9090} tempo=${TEMPO_PORT:-3200}
gport=${GRAFANA_PORT:-3000} lport=${LOKI_PORT:-3100}
for p in "$grpc" "$http" "$prom" "$tempo" "$gport" "$lport"; do
  case $p in ''|*[!0-9]*) dot_die "ports must be numbers, got '$p'" ;; esac
done
upstream=${OTEL_EXPORT_OTLP:-}
case $upstream in
  '') ;;
  *[[:space:]\"\'\\]*) dot_die "invalid OTEL_EXPORT_OTLP '$upstream'" ;;
  http://*|https://*) ;;
  *) dot_die "OTEL_EXPORT_OTLP must be an OTLP/HTTP URL like http://gateway:4318, got '$upstream'" ;;
esac
[ -n "$nostart" ] && export DOT_NO_START=1
dot_bind 0.0.0.0
local_ip=${DOT_BIND/0.0.0.0/127.0.0.1}
dot_need curl
tmp=$(mktemp -d) && chmod 755 "$tmp" && trap 'rm -rf "$tmp"' EXIT


# writes stdin to file $1 when it is missing or carries $mark; any other file is kept once as $1.orig and then
# replaced, unless a .orig exists already: then the file is the user's own and stays
put_conf() {
  local f=$1 new
  new=$(cat)
  if dot_sudo test -f "$f" && ! dot_sudo grep -qF "$mark" "$f"; then
    if dot_sudo test -e "$f.orig"; then dot_info "keeping $f (your own: it has no otel.sh line)"; return 0; fi
    dot_sudo cp -p "$f" "$f.orig" && dot_info "kept the previous $f as $f.orig"
  fi
  [ "$(dot_sudo cat "$f" 2>/dev/null)" = "$new" ] && return 0
  dot_sudo install -d "$(dirname "$f")" &&
    printf '%s\n' "$new" | dot_sudo tee "$f" >/dev/null || dot_die "could not write $f"
  changed=1
}

# dies when TCP port $1 is taken by something else than this installation
port_free() {
  dot_port_busy "$1" && dot_die "port $1 is in use: free it or choose another one (see otel.sh --help)"
  return 0
}

# (re)starts systemd unit $1, or stops it with --no-start (packages start their service on install)
svc() {
  [ -d /run/systemd/system ] || return 0
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable "$1" >/dev/null 2>&1 || dot_die "could not enable $1"
  if [ -n "$nostart" ]; then
    dot_sudo systemctl stop "$1"
  else
    dot_sudo systemctl restart "$1" || dot_die "$1 does not start, see: journalctl -u $1"
  fi
}

# prints the collector config; $1 = native|docker, then the exporter endpoints for traces, metrics and logs
# ("" = debug exporter): a gRPC host:port for traces, OTLP/HTTP base URLs for metrics and logs
collector_conf() {
  local exp= t=debug m=debug l=debug root=
  [ "$1" = docker ] && root='
    root_path: /hostfs'
  [ -n "$2" ] && t=otlp_grpc/traces exp+="
  otlp_grpc/traces:
    endpoint: $2
    tls:
      insecure: true"
  [ -n "$3" ] && m=otlp_http/metrics exp+="
  otlp_http/metrics:
    endpoint: $3"
  [ -n "$4" ] && l=otlp_http/logs exp+="
  otlp_http/logs:
    endpoint: $4"
  # an upstream gateway takes all three signals, unless the local stack does
  if [ -n "$upstream" ] && [ -z "$stack" ]; then
    t=otlp_http/upstream m=otlp_http/upstream l=otlp_http/upstream exp="
  otlp_http/upstream:
    endpoint: $upstream"
  fi
  cat <<EOF
$mark
# OTLP in, host metrics; exporters: traces -> $t, metrics -> $m, logs -> $l
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: $([ "$1" = docker ] && echo 0.0.0.0:4317 || echo "$DOT_BIND:$grpc")
      http:
        endpoint: $([ "$1" = docker ] && echo 0.0.0.0:4318 || echo "$DOT_BIND:$http")
  host_metrics:
    collection_interval: 30s$root
    scrapers:
      cpu:
      memory:
      load:
      network:
      filesystem:
        exclude_fs_types:
          match_type: strict
          fs_types: [autofs, binfmt_misc, bpf, cgroup2, configfs, debugfs, devpts, devtmpfs, fusectl, hugetlbfs,
                     mqueue, nsfs, overlay, proc, pstore, securityfs, squashfs, sysfs, tmpfs, tracefs]

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25
  batch:

exporters:
  debug:
    verbosity: basic$exp

service:
  telemetry:
    metrics:
      level: none
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [$t]
    metrics:
      receivers: [otlp, host_metrics]
      processors: [memory_limiter, batch]
      exporters: [$m]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [$l]
EOF
}

# prints the Tempo config (single binary, local storage); $1 = OTLP gRPC listen address, $2 = WAL/blocks dir,
# $3 = HTTP listen address, $4 = HTTP port
tempo_conf() {
  cat <<EOF
$mark
stream_over_http_enabled: true
server:
  http_listen_address: $3
  http_listen_port: $4
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "$1"
storage:
  trace:
    backend: local
    wal:
      path: $2/wal
    local:
      path: $2/blocks
usage_report:
  reporting_enabled: false
EOF
}

# prints the Prometheus config for OTLP ingestion (recommendations of the Prometheus OpenTelemetry guide); $1 = port
prom_conf() {
  cat <<EOF
$mark
global:
  scrape_interval: 30s
otlp:
  promote_resource_attributes: [service.instance.id, service.name, service.namespace, service.version,
                                deployment.environment.name, host.name, container.name]
storage:
  tsdb:
    out_of_order_time_window: 30m
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:$1"]
EOF
}

# prints the Grafana datasources for Prometheus, Tempo and Loki ($1 $2 $3 = their URLs), with trace <-> logs links
# ($$ is a literal $ in Grafana provisioning files)
datasources_conf() {
  cat <<EOF
$mark
apiVersion: 1
datasources:
  - name: OTel Prometheus
    uid: otel-prometheus
    type: prometheus
    access: proxy
    url: $1
    jsonData:
      httpMethod: POST
  - name: OTel Tempo
    uid: otel-tempo
    type: tempo
    access: proxy
    url: $2
    jsonData:
      tracesToLogsV2:
        datasourceUid: otel-loki
        spanStartTimeShift: -5m
        spanEndTimeShift: 5m
        tags:
          - key: service.name
            value: service_name
        customQuery: true
        query: '{\$\${__tags}} | trace_id="\$\${__span.traceId}"'
  - name: OTel Loki
    uid: otel-loki
    type: loki
    access: proxy
    url: $3
    jsonData:
      derivedFields:
        - name: TraceID
          matcherType: label
          matcherRegex: trace_id
          datasourceUid: otel-tempo
          url: '\$\${__value.raw}'
          urlDisplayLabel: Trace
EOF
}

# collector .deb (.rpm with dnf) of the latest release for this architecture, checked against the published sha256
install_collector() {
  local repo=open-telemetry/opentelemetry-collector-releases tag v deb url sum ext=deb
  tag=$(dot_github_latest "$repo") || dot_die "could not find the latest collector release on GitHub"
  v=${tag#v}
  if [ "$(dot_pkg_version otelcol-contrib)" = "$v" ]; then
    dot_info "otelcol-contrib $v is already installed"
    return
  fi
  [ "$DOT_PKG" = apt ] || ext=rpm
  deb=otelcol-contrib_${v}_linux_$DOT_ARCH.$ext
  url=https://github.com/$repo/releases/download/$tag/$deb
  dot_info "Downloading $deb"
  curl -fsSL -o "$tmp/$deb" "$url" && sum=$(curl -fsSL "$url.sha256") ||
    dot_die "download of $deb failed (no collector package for $DOT_ARCH?)"
  (cd "$tmp" && echo "${sum%% *}  $deb" | sha256sum -c --quiet) || dot_die "checksum of $deb does not match"
  dot_pkg_install "$tmp/$deb" || dot_die "installing $deb failed"
}

# native stack: Prometheus, Loki and Grafana through their installers when missing, Tempo, Grafana datasources
native_stack() {
  if ! command -v prometheus >/dev/null 2>&1 && [ ! -x /usr/local/bin/prometheus ]; then
    bash "$dir/prometheus.sh" </dev/null || dot_die "prometheus.sh failed"
    [ -n "$nostart" ] && svc prometheus
  fi
  # the collector sends metrics over OTLP: Prometheus accepts them only with --web.enable-otlp-receiver
  if [ -d /run/systemd/system ] &&
     ! { dot_sudo systemctl cat prometheus 2>/dev/null; dot_sudo cat /etc/default/prometheus 2>/dev/null; } |
       grep -q 'web.enable-otlp-receiver'; then
    echo "warning: Prometheus runs without --web.enable-otlp-receiver, metrics from the collector are refused: add it to its service" >&2
  fi
  if ! dot_pkg_installed loki; then
    bash "$dir/loki.sh" </dev/null || dot_die "loki.sh failed"
    [ -n "$nostart" ] && svc loki
  fi
  if ! dot_pkg_installed grafana && ! dot_pkg_installed grafana-enterprise; then
    bash "$dir/grafana.sh" </dev/null || dot_die "grafana.sh failed"
  fi

  # Tempo's package config listens on 4317 like the collector: ours moves OTLP to 127.0.0.1:4417
  if [ "$DOT_PKG" = apt ]; then
    [ -f /etc/apt/sources.list.d/grafana.sources ] ||
      dot_apt_repo grafana https://apt.grafana.com/gpg.key https://apt.grafana.com stable main
    dot_need adduser # the tempo postinst uses it
  else
    [ -f /etc/yum.repos.d/grafana.repo ] ||
      dot_rpm_repo grafana https://rpm.grafana.com https://rpm.grafana.com/gpg.key repo_gpgcheck=1
  fi
  dot_pkg_install tempo || dot_die "installing the tempo package failed"
  put_conf /etc/tempo/config.yml < <(tempo_conf 127.0.0.1:4417 /var/tempo "$DOT_BIND" "$tempo")
  out=$(dot_sudo tempo -config.file=/etc/tempo/config.yml -config.verify -config.verify-errors-only 2>&1) ||
    { echo "$out" >&2; dot_die "/etc/tempo/config.yml is not valid"; }
  svc tempo

  native_urls
  put_conf /etc/grafana/provisioning/datasources/otel.yaml < <(
    datasources_conf "$prom_url" "http://$local_ip:$tempo" "$loki_url")
  svc grafana-server
}

# sets prom_url and loki_url, where the native Prometheus and Loki answer: the address in their unit or config, which
# their installers keep from an earlier run; 0.0.0.0 or none means 127.0.0.1 (28.10.26: with --bind=<IP> the
# datasources and exporters pointed at 127.0.0.1, where nothing listened)
native_urls() {
  local a
  a=$(dot_sudo sed -n 's/.*--web.listen-address=\([^ "]*\).*/\1/p' /etc/systemd/system/prometheus.service 2>/dev/null |
    head -n 1)
  a=${a:-127.0.0.1:$prom}
  case $a in 0.0.0.0:*|:*) a=127.0.0.1:${a##*:} ;; esac
  prom_url=http://$a prom=${a##*:}
  a=$(dot_sudo sed -n 's/^  http_listen_address: *//p' /etc/loki/config.yml 2>/dev/null)
  case $a in ''|0.0.0.0) a=127.0.0.1 ;; esac
  loki_url=http://$a:3100
}

# prints the host port /opt/otel/compose.yaml publishes for container port $1 ("[addr:]host:container")
published() { dot_sudo sed -n "s/^ *- \"\([0-9.]*:\)\{0,1\}\([0-9]*\):$1\"\$/\2/p" /opt/otel/compose.yaml | head -n 1; }

# --- lgtm: one demo container ---
if [ -n "$lgtm" ]; then
  [ -z "$stack" ] || dot_die "use either stack or lgtm"
  [ "$DOT_MODE" = native ] && { dot_info "lgtm runs in Docker only, using compose"; DOT_MODE=compose; }
  dot_sudo test -f /opt/otel/compose.yaml && dot_die "the otel project (/opt/otel) uses the same ports, remove it first"
  dot_pkg_installed otelcol-contrib && dot_die "a native collector runs here on the same ports"
  dot_deploy otel-lgtm "services:
  lgtm:
    image: grafana/otel-lgtm:latest
    container_name: otel-lgtm
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$gport:3000\"
      - \"$DOT_BIND:$grpc:4317\"
      - \"$DOT_BIND:$http:4318\"
    volumes:
      - lgtm_data:/data
volumes:
  lgtm_data:"
  dot_summary otel-lgtm "Grafana=http://localhost:$gport OTLP-gRPC=localhost:$grpc OTLP-HTTP=http://localhost:$http" \
    "Grafana admin/admin (demo image, not for real data)"
  exit 0
fi

# one installation per host: native and Docker would take the same ports
if [ "$DOT_MODE" = native ] && dot_sudo test -f /opt/otel/compose.yaml; then
  dot_info "the collector runs in Docker here (/opt/otel/compose.yaml), staying with compose (--portainer for a stack)"
  DOT_MODE=compose
fi
[ "$DOT_MODE" != native ] && dot_pkg_installed otelcol-contrib && dot_die "the collector is installed natively here (otelcol-contrib): use --native"

# --- native ---
if [ "$DOT_MODE" = native ]; then
  case $DOT_PKG in apt|dnf|yum) ;; *) dot_die "otel.sh natively supports Debian-based systems, Fedora and the RHEL family, not $DOT_OS; use --docker" ;; esac
  dot_sudo grep -qsF "$mark" /etc/tempo/config.yml && stack=1 # a stack from an earlier run stays one
  if ! dot_pkg_installed otelcol-contrib; then port_free "$grpc"; port_free "$http"; fi
  if [ -n "$stack" ] && ! dot_sudo grep -qsF "$mark" /etc/tempo/config.yml; then port_free "$tempo"; port_free 4417; fi
  [ -n "$stack" ] && native_stack

  install_collector
  native_urls
  if [ -n "$stack" ]; then
    set -- 127.0.0.1:4417 "$prom_url/api/v1/otlp" "$loki_url/otlp"
  elif dot_pkg_installed loki; then
    set -- "" "" "$loki_url/otlp"
  else
    set -- "" "" ""
  fi
  conf=/etc/otelcol-contrib/config.yaml
  put_conf "$conf" < <(collector_conf native "$@")
  out=$(dot_sudo otelcol-contrib validate --config="$conf" 2>&1) || { echo "$out" >&2; dot_die "$conf is not valid"; }
  svc otelcol-contrib
  [ -d /run/systemd/system ] || dot_info "no systemd running: start the collector with: sudo -u otelcol-contrib otelcol-contrib --config=$conf"
  gport=3000 # grafana.sh
  grafana_login="Grafana: see the grafana.sh summary (/etc/grafana)"

# --- Docker compose / Portainer ---
else
  dest=/opt/otel
  compose=$dest/compose.yaml
  dot_sudo grep -qs '^  tempo:' "$compose" && stack=1
  if [ -n "$stack" ] && dot_sudo test -f "$compose" && ! dot_sudo grep -qs '^  tempo:' "$compose"; then
    dot_sudo mv "$compose" "$compose.collector-only" && dot_info "collector-only compose file kept as $compose.collector-only"
  fi
  if ! dot_sudo test -f "$compose"; then
    for p in "$grpc" "$http"; do port_free "$p"; done
    [ -z "$stack" ] || for p in "$prom" "$tempo" "$gport" "$lport"; do port_free "$p"; done
  fi
  dot_sudo install -d -m 0755 "$dest" || exit 1
  changed=
  if [ -n "$stack" ]; then
    put_conf "$dest/collector.yaml" < <(collector_conf docker tempo:4317 http://prometheus:9090/api/v1/otlp http://loki:3100/otlp)
    put_conf "$dest/tempo.yaml" < <(tempo_conf 0.0.0.0:4317 /var/tempo 0.0.0.0 3200)
    put_conf "$dest/prometheus.yml" < <(prom_conf 9090)
    put_conf "$dest/grafana-datasources.yaml" < <(datasources_conf http://prometheus:9090 http://tempo:3200 http://loki:3100)
  else
    put_conf "$dest/collector.yaml" < <(collector_conf docker "" "" "")
  fi
  # bind mounts use absolute paths: Portainer stacks have no project directory
  yaml="services:
  collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    restart: unless-stopped
    command: [\"--config=/etc/otelcol-contrib/config.yaml\"]
    volumes:
      - $dest/collector.yaml:/etc/otelcol-contrib/config.yaml:ro
      - /:/hostfs:ro
    ports:
      - \"$DOT_BIND:$grpc:4317\"
      - \"$DOT_BIND:$http:4318\""
  [ -n "$stack" ] && yaml+="
  tempo:
    image: grafana/tempo:latest
    container_name: otel-tempo
    restart: unless-stopped
    command: [\"-config.file=/etc/tempo.yaml\"]
    volumes:
      - $dest/tempo.yaml:/etc/tempo.yaml:ro
      - tempo_data:/var/tempo
    ports:
      - \"$DOT_BIND:$tempo:3200\"
  prometheus:
    image: prom/prometheus:latest
    container_name: otel-prometheus
    restart: unless-stopped
    command: [\"--config.file=/etc/prometheus/prometheus.yml\", \"--storage.tsdb.path=/prometheus\",
              \"--web.enable-otlp-receiver\", \"--web.enable-remote-write-receiver\"]
    volumes:
      - $dest/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    ports:
      - \"$DOT_BIND:$prom:9090\"
  loki:
    image: grafana/loki:latest
    container_name: otel-loki
    restart: unless-stopped
    volumes:
      - loki_data:/loki
    ports:
      - \"$DOT_BIND:$lport:3100\"
  grafana:
    image: grafana/grafana:latest
    container_name: otel-grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_PASSWORD: \${GF_SECURITY_ADMIN_PASSWORD}
    volumes:
      - $dest/grafana-datasources.yaml:/etc/grafana/provisioning/datasources/otel.yaml:ro
      - grafana_data:/var/lib/grafana
    ports:
      - \"$DOT_BIND:$gport:3000\"
volumes:
  tempo_data:
  prometheus_data:
  loki_data:
  grafana_data:"
  if [ -z "$nostart" ]; then
    dot_docker_ready
    # validate checks that root_path exists (28.10.26: "invalid root_path: stat /hostfs"), so it gets the same mount
    out=$(dot_sudo docker run --rm -v "$dest/collector.yaml:/c.yaml:ro" -v /:/hostfs:ro \
      otel/opentelemetry-collector-contrib:latest validate --config=/c.yaml 2>&1) ||
      { echo "$out" >&2; dot_die "$dest/collector.yaml is not valid"; }
    existing=$(dot_sudo docker ps -aq --filter label=com.docker.compose.project=otel)
  fi
  # Grafana's admin password goes to /opt/otel/.env on the first run (dot_deploy keeps an existing .env);
  # Grafana applies it only when its database is created
  envs=
  if [ -n "$stack" ]; then
    pw=${GRAFANA_ADMIN_PASSWORD:-$(dot_password 24)}
    dot_secret_ok "$pw" || dot_die "GRAFANA_ADMIN_PASSWORD must not contain spaces, quotes, \\ or \$"
    [ ${#pw} -ge 8 ] || dot_die "GRAFANA_ADMIN_PASSWORD needs at least 8 characters"
    envs="GF_SECURITY_ADMIN_PASSWORD=$pw"
  fi
  dot_deploy otel "$yaml" "$envs"
  grafana_login="Grafana user admin, password: GF_SECURITY_ADMIN_PASSWORD in $dest/.env"
  # containers that were there before read changed bind-mounted configs only after a restart
  if [ -n "$changed" ] && [ -n "${existing:-}" ]; then
    dot_sudo docker restart $existing >/dev/null || dot_die "could not restart the otel containers"
  fi
  # the kept compose file decides the ports
  grpc=$(published 4317) http=$(published 4318)
  [ -z "$stack" ] || { prom=$(published 9090) tempo=$(published 3200) gport=$(published 3000); }
fi

if [ -n "$nostart" ]; then
  dot_info "--no-start: installed and configured, nothing started; start with: otel.sh${stack:+ stack} --$DOT_MODE"
elif [ -d /run/systemd/system ] || [ "$DOT_MODE" != native ]; then
  # the OTLP/HTTP receiver answers an empty export with 200 once the collector runs
  up=
  for _ in $(seq 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' \
      "http://$local_ip:$http/v1/traces")
    [ "$code" = 200 ] && { up=1; break; }
    sleep 1
  done
  if [ -z "$up" ]; then
    [ "$DOT_MODE" = native ] && log='journalctl -u otelcol-contrib' || log='sudo docker logs otel-collector'
    dot_die "the collector does not answer on port $http, see: $log"
  fi
fi

addrs="OTLP-gRPC=localhost:$grpc OTLP-HTTP=http://localhost:$http"
if [ -n "$stack" ]; then
  dot_summary otel "$addrs Grafana=http://localhost:$gport Prometheus=http://localhost:$prom Tempo=http://localhost:$tempo" \
    "OTLP without auth; $grafana_login" otelcol-contrib
  [ -z "$upstream" ] || dot_info "OTEL_EXPORT_OTLP is not used with the stack"
else
  dot_summary otel "$addrs" "OTLP without auth" otelcol-contrib
  if [ -n "$upstream" ]; then
    dot_info "exports traces, metrics and logs to $upstream"
  elif [ "$DOT_MODE" = native ] && dot_pkg_installed loki; then
    dot_info "exports logs to the local Loki; traces and metrics go to the debug exporter (collector log)"
  else
    dot_info "no backend: data goes to the debug exporter (collector log); use otel.sh stack or OTEL_EXPORT_OTLP=http://host:4318"
  fi
fi
