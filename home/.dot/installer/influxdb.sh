#!/bin/bash
# installer: InfluxDB 1.x, 2.x or 3 Core from InfluxData's apt or rpm repository
# systems: debian arch fedora rhel
# modes: native compose portainer
# Installs one InfluxDB line from repos.influxdata.com (key fingerprint checked) and enables its service:
#   influxdb.sh 1     InfluxDB 1.x (package influxdb), newest 1.x in the repository, port 8086, no authentication
#                     INFLUX1_VERSION=1.8.10 influxdb.sh 1   exactly this version, held with apt-mark hold (dnf: not held)
#   influxdb.sh 2     InfluxDB 2.x (influxdb2 + influxdb2-cli), port 8086; Arch: its influxdb + influx-cli packages
#                     runs "influx setup" with INFLUX_ADMIN, INFLUX_PASSWORD (8+ chars), INFLUX_ORG, INFLUX_BUCKET (all or
#                     none; none: admin, a generated password, org and bucket "default"); login and operator token
#                     (INFLUX_TOKEN or generated) go to /etc/influxdb/setup.env (root only)
#   influxdb.sh 3     InfluxDB 3 Core (influxdb3-core), port $INFLUX3_PORT (default 8183 because restreamer.sh
#                     uses 8181, the vendor default; later runs keep it); admin token in /etc/influxdb3/admin-token.json
#   influxdb.sh       asks for the line (1, 2 or 3); anything else is an error
#   ... --chronograf  also runs chronograf.sh, pointed at the InfluxDB installed here
#   ... --docker | --portainer   official image (influxdb:1.<newest> or INFLUX1_VERSION, influxdb:2, influxdb:3-core) as
#                     compose project or Portainer stack influxdb1, influxdb2 or influxdb3 from /opt/<stack>, same ports
#                     and variables; secrets in /opt/influxdb2/.env or /opt/influxdb3/admin-token.json (root only)
#   ... --public | --local   all interfaces or this host only (else asked; default as before, else 1.x local, rest all)
# 1.x and 2.x share port 8086 and the service name influxdb: the one installed is never replaced by the other.
# All lines: amd64/arm64 only (1.x natively everywhere). 3 Core takes about 300 MB disk; InfluxData names no minimum
# RAM, its caches default to 20 % of RAM each: 512 MB is enough for a test, not for real data.
# category: db
# ports: INFLUX_LINE=1,2:8086 INFLUX_LINE=3:INFLUX3_PORT=8183
# check: influxd|influxdb3 stack:influxdb1 stack:influxdb2 stack:influxdb3
# ask: INFLUX_LINE=2|3|1 "InfluxDB line: 2 (most used, web UI and Flux), 3 (Core, SQL, new), 1 (InfluxQL, old)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
bind_given=${BIND_ADDR:-}
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

dir=$(dirname "$(readlink -f "$0")")
# the menu passes the line as INFLUX_LINE (# ask above), an argument wins
line=${INFLUX_LINE:-} chrono=
for a in "$@"; do
  case $a in
    1|2|3) line=$a ;;
    --chronograf) chrono=1 ;;
    -h|--help) sed -n '5,22s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) dot_die "unknown argument '$a', usage: influxdb.sh [1|2|3] [--chronograf] [--docker|--portainer]" ;;
  esac
done
if [ -z "$line" ]; then
  printf 'Which InfluxDB?\n  1) InfluxDB 1.x\n  2) InfluxDB 2.x\n  3) InfluxDB 3 Core\nchoice [1-3]: '
  read -r line || dot_die "no choice given"
  case $line in 1|2|3) ;; *) dot_die "invalid choice '$line', give 1, 2 or 3 (e.g. influxdb.sh 2)" ;; esac
fi
# prints "<address>:<port>" an earlier run of this line wrote into its config, nothing on the first run
earlier_bind() {
  case $DOT_MODE:$line in
    native:3) dot_sudo sed -n 's/^http-bind[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' /etc/influxdb3/influxdb3-core.conf ;;
    native:*) dot_sudo sed -n 's/^Environment=.*_BIND_ADDRESS=//p' /etc/systemd/system/influxdb.service.d/bind.conf ;;
    *:3) dot_sudo sed -n 's/^ *- "\(.*\):8181"$/\1/p' /opt/influxdb3/compose.yaml ;;
    *) dot_sudo sed -n 's/^ *- "\(.*\):8086"$/\1/p' "/opt/influxdb$line/compose.yaml" ;;
  esac 2>/dev/null | head -n 1
}
# address and port of an earlier run stay unless given again (28.10.26: a second run without INFLUX3_PORT moved
# InfluxDB 3 from 8190 back to 8183)
old=$(earlier_bind) old_addr= old_port=
case $old in *:*) old_addr=${old%:*} old_port=${old##*:} ;; esac
port3=${INFLUX3_PORT:-${old_port:-8183}}
case $port3 in ''|*[!0-9]*) dot_die "INFLUX3_PORT must be a number, got '$port3'" ;; esac

# enables and (re)starts service $1, then waits up to 30 s for health URL $2 (401 counts: running with authentication)
start_service() {
  dot_sudo systemctl enable "$1" && dot_sudo systemctl restart "$1" || dot_die "$1 does not start, see: journalctl -u $1"
  dot_wait_http "$2" 30 '2..|401' || dot_die "$1 does not answer on $2, see: journalctl -u $1"
}

# sets environment variable $2 (NAME=value) for service $1 in the systemd drop-in bind.conf
unit_env() {
  printf '[Service]\nEnvironment=%s\n' "$2" | dot_sudo install -D -m 0644 /dev/stdin "/etc/systemd/system/$1.service.d/bind.conf" &&
    dot_sudo systemctl daemon-reload || dot_die "could not write the systemd drop-in for $1"
}

# adds repos.influxdata.com after checking the key fingerprint the InfluxData docs give
influx_repo() {
  local fpr=24C975CBA61A024EE1B631787C3D57159FC2F927 key=https://repos.influxdata.com/influxdata-archive.key tmp
  dot_need gpg
  if [ "$DOT_PKG" != apt ]; then
    # rpm: the checked key goes to /etc/pki/rpm-gpg, the .repo file points at that copy
    tmp=$(mktemp) && curl -fsSL -o "$tmp" "$key" || { rm -f "$tmp"; dot_die "could not download the key $key"; }
    gpg --show-keys --with-colons "$tmp" 2>/dev/null | grep -q "^fpr:*$fpr:" ||
      { rm -f "$tmp"; dot_die "the InfluxData key has not the fingerprint $fpr"; }
    dot_sudo install -m 0644 "$tmp" /etc/pki/rpm-gpg/RPM-GPG-KEY-influxdata && rm -f "$tmp" || exit 1
    dot_rpm_repo influxdata 'https://repos.influxdata.com/stable/$basearch/main' file:///etc/pki/rpm-gpg/RPM-GPG-KEY-influxdata
    return
  fi
  dot_apt_repo influxdata https://repos.influxdata.com/influxdata-archive.key https://repos.influxdata.com/debian stable main
  gpg --show-keys --with-colons /etc/apt/keyrings/influxdata.asc 2>/dev/null | grep -q "^fpr:*$fpr:" || {
    dot_sudo rm -f /etc/apt/sources.list.d/influxdata.sources /etc/apt/keyrings/influxdata.asc
    dot_die "the InfluxData key has not the fingerprint $fpr, removed the repository again"
  }
}

# sets key = "value" in the TOML file $3, replacing an active line or appending one
toml_set() {
  if dot_sudo grep -q "^$1[[:space:]]*=" "$3"; then
    dot_sudo sed -i "s|^$1[[:space:]]*=.*|$1=\"$2\"|" "$3"
  else
    echo "$1=\"$2\"" | dot_sudo tee -a "$3" >/dev/null
  fi
}

# 2.x initial setup: all of INFLUX_ADMIN, INFLUX_PASSWORD, INFLUX_ORG, INFLUX_BUCKET or none of them (then admin, a
# generated password, org and bucket "default"); INFLUX_TOKEN is generated when not given
setup_vars() {
  local v f missing=
  for v in INFLUX_ADMIN INFLUX_PASSWORD INFLUX_ORG INFLUX_BUCKET; do [ -n "${!v:-}" ] || missing+=" $v"; done
  if [ "$missing" = " INFLUX_ADMIN INFLUX_PASSWORD INFLUX_ORG INFLUX_BUCKET" ]; then
    INFLUX_ADMIN=admin INFLUX_ORG=default INFLUX_BUCKET=default
    INFLUX_PASSWORD=$(dot_password 20)
  elif [ -n "$missing" ]; then
    dot_die "influx setup needs all of INFLUX_ADMIN INFLUX_PASSWORD INFLUX_ORG INFLUX_BUCKET or none, missing:$missing"
  fi
  [ ${#INFLUX_PASSWORD} -ge 8 ] || dot_die "INFLUX_PASSWORD needs at least 8 characters"
  INFLUX_TOKEN=${INFLUX_TOKEN:-$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')}
  for f in "$INFLUX_ADMIN" "$INFLUX_PASSWORD" "$INFLUX_ORG" "$INFLUX_BUCKET" "$INFLUX_TOKEN"; do
    dot_secret_ok "$f" || dot_die "the INFLUX_* values must not contain spaces, quotes, \$ or backslashes"
  done
}

# 1.x: newest from the repository, or INFLUX1_VERSION held
install_v1() {
  local v=${INFLUX1_VERSION:-}
  dot_pkg_installed influxdb2 && dot_die "InfluxDB 2 (influxdb2) is installed: 1.x would take its port 8086 and service name. Remove influxdb2 first."
  case $v in *[!0-9.]*) dot_die "INFLUX1_VERSION must look like 1.8.10, got '$v'" ;; esac
  if [ "$DOT_PKG" != apt ]; then
    # dnf has no hold without the versionlock plugin: the pinned version is installed, not held
    dot_pkg_install "influxdb${v:+-$v}" || dot_die "installing influxdb${v:+ $v} failed (versions: dnf list --showduplicates influxdb)"
    [ -z "$v" ] || dot_info "influxdb $v is not held: add excludepkgs=influxdb to /etc/yum.repos.d/influxdata.repo to keep it"
  elif [ -n "$v" ]; then
    dot_sudo apt-mark unhold influxdb >/dev/null 2>&1
    dot_pkg_install "influxdb=$v-*" ||
      dot_die "installing influxdb $v failed (versions: apt-cache madison influxdb; a downgrade is refused)"
    dot_sudo apt-mark hold influxdb >/dev/null
    dot_info "influxdb is held at $v: apt-mark unhold influxdb before upgrading"
  elif apt-mark showhold | grep -qx influxdb; then
    dot_info "influxdb is held at $(dpkg-query -W -f '${Version}' influxdb), keeping it (apt-mark unhold influxdb to upgrade)"
  else
    dot_pkg_install influxdb || dot_die "installing influxdb failed"
  fi
  if [ -d /run/systemd/system ]; then
    unit_env influxdb "INFLUXDB_HTTP_BIND_ADDRESS=$DOT_BIND:8086"
    start_service influxdb "http://$here:8086/ping"
  fi
  dot_info "InfluxDB $(dot_pkg_version influxdb) installed, config /etc/influxdb/influxdb.conf"
  dot_info "authentication is off (1.x default): create an admin user with influx, then set auth-enabled = true in [http]"
  dot_summary influxdb "http://localhost:8086" "none (authentication off)"
}

# 2.x: influxdb2 + CLI, "influx setup" from INFLUX_* variables or generated values
install_v2() {
  local env=/etc/influxdb/setup.env url=http://$here:8086 login
  case $DOT_PKG in
    pacman) dot_pkg_install influxdb influx-cli || dot_die "installing influxdb failed" ;;
    *)
      dot_pkg_installed influxdb && dot_die "InfluxDB 1.x (influxdb) is installed: 2.x would take its port 8086 and service name. Remove influxdb first."
      dot_pkg_install influxdb2 influxdb2-cli || dot_die "installing influxdb2 failed" ;;
  esac
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start InfluxDB with: sudo -u influxdb influxd --http-bind-address $DOT_BIND:8086 &   then run influx setup"
    return
  fi
  unit_env influxdb "INFLUXD_HTTP_BIND_ADDRESS=$DOT_BIND:8086"
  start_service influxdb "$url/health"
  dot_info "InfluxDB 2 ($(influxd version 2>/dev/null | cut -d' ' -f2)) installed"

  if curl -fsS "$url/api/v2/setup" | grep -q '"allowed": *true'; then
    setup_vars
    influx setup --host "$url" --username "$INFLUX_ADMIN" --password "$INFLUX_PASSWORD" --org "$INFLUX_ORG" \
      --bucket "$INFLUX_BUCKET" --token "$INFLUX_TOKEN" --force || dot_die "influx setup failed"
    dot_sudo install -d -m 0755 /etc/influxdb
    printf 'INFLUX_HOST=%s\nINFLUX_ORG=%s\nINFLUX_TOKEN=%s\nINFLUX_USERNAME=%s\nINFLUX_PASSWORD=%s\n' \
      "$url" "$INFLUX_ORG" "$INFLUX_TOKEN" "$INFLUX_ADMIN" "$INFLUX_PASSWORD" |
      dot_sudo install -m 0600 /dev/stdin "$env" || dot_die "could not write $env"
    dot_info "set up: user $INFLUX_ADMIN, org $INFLUX_ORG, bucket $INFLUX_BUCKET; login and operator token in $env (root only)"
  else
    dot_info "InfluxDB 2 is set up already"
  fi
  if dot_sudo test -f "$env"; then login="user, password and operator token: sudo cat $env"; else login="as set up before"; fi
  dot_summary influxdb "http://localhost:8086" "$login"
}

# 3 Core: influxdb3-core with its own port and an offline-created admin token
install_v3() {
  local port=$port3 conf=/etc/influxdb3/influxdb3-core.conf tok=/etc/influxdb3/admin-token.json data
  dot_pkg_installed influxdb3-enterprise && dot_die "InfluxDB 3 Enterprise is installed, it conflicts with influxdb3-core"
  dot_pkg_install influxdb3-core || dot_die "installing influxdb3-core failed"
  dot_sudo test -f "$conf" || dot_die "$conf is missing after the install"

  toml_set http-bind "$DOT_BIND:$port" "$conf"
  # the server loads the token file only while it has no admin token, i.e. on its first start
  data=$(dot_sudo sed -n 's/^data-dir[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$conf")
  if ! dot_sudo test -f "$tok"; then
    if [ -n "$(dot_sudo find "${data:-/var/lib/influxdb3/data}" -mindepth 1 -print -quit 2>/dev/null)" ]; then
      dot_info "InfluxDB 3 has data already: create an admin token with: influxdb3 create token --admin --host http://$here:$port"
    else
      dot_sudo influxdb3 create token --admin --offline --output-file "$tok" >/dev/null || dot_die "could not create the admin token"
      dot_sudo chown influxdb3:influxdb3 "$tok" && dot_sudo chmod 0600 "$tok"
      toml_set admin-token-file "$tok" "$conf"
      dot_info "admin token in $tok (readable by root and influxdb3)"
    fi
  fi

  if [ -d /run/systemd/system ]; then
    start_service influxdb3-core "http://$here:$port/health"
  elif [ ! -x /etc/init.d/influxdb3-core ]; then
    # the rpm package brings no SysV script
    dot_info "no systemd running: start it as user influxdb3 with the ExecStart line of influxdb3-core.service"
  else
    dot_sudo sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/default/influxdb3-core
    dot_sudo /etc/init.d/influxdb3-core restart || dot_die "influxdb3-core does not start"
  fi
  dot_info "$(influxdb3 --version 2>/dev/null | head -n 1) installed, config $conf"
  dot_info "CLI: influxdb3 <command> --host http://$here:$port --token <the \"token\" field of $tok>"
  dot_summary influxdb3 "http://localhost:$port" "admin token: sudo cat $tok" influxdb3-core
}

# Docker 1.x: influxdb:<INFLUX1_VERSION or the newest 1.N tag on Docker Hub>, authentication off as natively
docker_v1() {
  local tag=${INFLUX1_VERSION:-}
  case $tag in *[!0-9.]*) dot_die "INFLUX1_VERSION must look like 1.8.10, got '$tag'" ;; esac
  [ -n "$tag" ] || tag=$(curl -fsSL "https://hub.docker.com/v2/repositories/library/influxdb/tags?page_size=100&name=1." |
    grep -oE '"name": *"1\.[0-9]+"' | grep -oE '1\.[0-9]+' | sort -V | tail -n 1)
  dot_deploy influxdb1 "services:
  influxdb:
    image: influxdb:${tag:-1.12}
    container_name: influxdb1
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:8086:8086\"
    volumes:
      - data:/var/lib/influxdb
volumes:
  data:"
  [ -n "${DOT_NO_START:-}" ] || dot_wait_http "http://$here:8086/ping" 30 '2..|401' ||
    dot_die "influxdb1 does not answer, see: sudo docker logs influxdb1"
  dot_summary influxdb1 "http://localhost:8086" "none (authentication off)"
}

# Docker 2.x: the image runs "influx setup" on its first start from DOCKER_INFLUXDB_INIT_* in /opt/influxdb2/.env
docker_v2() {
  setup_vars
  dot_deploy influxdb2 "services:
  influxdb:
    image: influxdb:2
    container_name: influxdb2
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:8086:8086\"
    environment:
      DOCKER_INFLUXDB_INIT_MODE: \${DOCKER_INFLUXDB_INIT_MODE:-}
      DOCKER_INFLUXDB_INIT_USERNAME: \${DOCKER_INFLUXDB_INIT_USERNAME:-}
      DOCKER_INFLUXDB_INIT_PASSWORD: \${DOCKER_INFLUXDB_INIT_PASSWORD:-}
      DOCKER_INFLUXDB_INIT_ORG: \${DOCKER_INFLUXDB_INIT_ORG:-}
      DOCKER_INFLUXDB_INIT_BUCKET: \${DOCKER_INFLUXDB_INIT_BUCKET:-}
      DOCKER_INFLUXDB_INIT_ADMIN_TOKEN: \${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-}
    volumes:
      - data:/var/lib/influxdb2
      - config:/etc/influxdb2
volumes:
  data:
  config:" "DOCKER_INFLUXDB_INIT_MODE=setup
DOCKER_INFLUXDB_INIT_USERNAME=$INFLUX_ADMIN
DOCKER_INFLUXDB_INIT_PASSWORD=$INFLUX_PASSWORD
DOCKER_INFLUXDB_INIT_ORG=$INFLUX_ORG
DOCKER_INFLUXDB_INIT_BUCKET=$INFLUX_BUCKET
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$INFLUX_TOKEN"
  # the first start runs the setup before the server answers on 8086
  [ -n "${DOT_NO_START:-}" ] || dot_wait_http "http://$here:8086/health" 60 '2..|401' ||
    dot_die "influxdb2 does not answer, see: sudo docker logs influxdb2"
  dot_summary influxdb2 "http://localhost:8086" "user, password and operator token: sudo cat /opt/influxdb2/.env"
}

# Docker 3 Core: the admin token file is written before the first start (format of "influxdb3 create token
# --admin --offline") and mounted read-only; the image runs as uid 1500 and needs to read it
docker_v3() {
  local dest=/opt/influxdb3 tok=/opt/influxdb3/admin-token.json tokarg= tokmount=
  dot_sudo install -d -m 0755 "$dest"
  if ! dot_sudo test -f "$tok"; then
    if command -v docker >/dev/null 2>&1 && dot_sudo docker volume inspect influxdb3_data >/dev/null 2>&1; then
      dot_info "InfluxDB 3 has data already: create an admin token with: sudo docker exec influxdb3 influxdb3 create token --admin"
    else
      printf '{"token": "apiv3_%s", "name": "_admin"}\n' "$(head -c 48 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')" |
        dot_sudo install -m 0600 -o 1500 -g 1500 /dev/stdin "$tok" || dot_die "could not write $tok"
    fi
  fi
  if dot_sudo test -f "$tok"; then
    tokarg="
      - --admin-token-file=/etc/influxdb3/admin-token.json"
    tokmount="
      - $tok:/etc/influxdb3/admin-token.json:ro"
  fi
  dot_deploy influxdb3 "services:
  influxdb:
    image: influxdb:3-core
    container_name: influxdb3
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port3:8181\"
    command:
      - influxdb3
      - serve
      - --node-id=node0
      - --object-store=file
      - --data-dir=/var/lib/influxdb3/data$tokarg
    volumes:
      - data:/var/lib/influxdb3$tokmount
volumes:
  data:"
  [ -n "${DOT_NO_START:-}" ] || dot_wait_http "http://$here:$port3/health" 30 '2..|401' ||
    dot_die "influxdb3 does not answer, see: sudo docker logs influxdb3"
  dot_info "CLI: sudo docker exec influxdb3 influxdb3 <command> --token <the \"token\" field of $tok>"
  dot_summary influxdb3 "http://localhost:$port3" "admin token: sudo cat $tok"
}

# 1.x without login stays on this host unless asked otherwise; 2.x and 3 have logins and usually take remote writes
if [ "$line" = 1 ]; then dot_bind 127.0.0.1 "$old_addr"; else dot_bind 0.0.0.0 "$old_addr"; fi
here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=localhost
case $line in
  3) dot_mode_guard influxdb3 influxdb3-core "$port3" ;;
  *) dot_mode_guard "influxdb$line" influxdb 8086
     # natively 1.x and 2.x also clash with the other line's stack on 8086
     [ "$DOT_MODE" = native ] && dot_mode_guard "influxdb$((3 - line))" influxdb ;;
esac

if [ "$DOT_MODE" = native ]; then
  case $DOT_PKG in
    apt|dnf|yum)
      case $line in 2|3) [ "$DOT_ARCH" = amd64 ] || [ "$DOT_ARCH" = arm64 ] ||
        dot_die "InfluxData has InfluxDB $line packages for amd64 and arm64 only, not $DOT_ARCH" ;; esac
      influx_repo ;;
    pacman) [ "$line" = 2 ] || dot_die "on Arch only InfluxDB 2 is packaged (influxdb.sh 2)" ;;
    *) dot_die "influxdb.sh supports Debian-based systems, Arch, Fedora and the RHEL family, not $DOT_OS" ;;
  esac
  dot_need curl
  install_v$line
else
  [ "$DOT_ARCH" = amd64 ] || [ "$DOT_ARCH" = arm64 ] || dot_die "the InfluxDB images are for amd64 and arm64 only, not $DOT_ARCH"
  dot_need curl
  docker_v$line
fi
[ -z "$chrono" ] || INSTALL_MODE=$DOT_MODE BIND_ADDR=$bind_given bash "$dir/chronograf.sh" </dev/null || dot_die "chronograf.sh failed"
