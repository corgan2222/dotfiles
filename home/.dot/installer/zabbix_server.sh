#!/bin/bash
# installer: Zabbix server with web frontend and agent 2 on PostgreSQL from repo.zabbix.com
# systems: debian rhel
# modes: native compose portainer
# Installs Zabbix server, the web frontend (nginx + PHP-FPM) and agent 2 from the official Zabbix repository and
# PostgreSQL from the distro, creates the database, imports the schema and writes the frontend config. Safe to run again.
# Zabbix publishes no repository for Fedora or Arch: there the menu runs it in Docker.
#   zabbix_server.sh [<x.y>|latest|lts]   a version like 7.0, latest: the newest with packages here (default), lts: the
#                                       newest x.0; also as ZABBIX_VERSION
#   zabbix_server.sh [--docker] --choices   the 5 newest versions with packages here (with images in Docker), for installer.sh
#   zabbix_server.sh ... --docker | --portainer   images zabbix/zabbix-server-pgsql, zabbix-web-nginx-pgsql and
#                     zabbix-agent2 (alpine-<x.y>-latest) with postgres:16-alpine as compose project or Portainer stack
#                     "zabbix-server" from /opt/zabbix-server; ZABBIX_AGENT=no leaves the agent out
#   ZABBIX_WEB_PORT=8080   port of the web frontend (default 8080)
#   --public / --local     web frontend and server port 10051 on all interfaces or this host only (default all)
# PostgreSQL, not MariaDB: the official images use it as well, its schema import needs no
# log_bin_trust_function_creators, and every supported distro ships a version Zabbix takes (13 or newer).
# The database password is generated and kept root-only in /etc/zabbix/zabbix-db.env (native) or /opt/zabbix-server/.env.
# Web login: user Admin with a random password, set through the API on the first run and kept in admin-password next
# to the database password (root only).
# category: server
# ports: ZABBIX_WEB_PORT=8080 10051
# check: zabbix-server.service stack:zabbix-server
# ask: ZABBIX_VERSION=@ "Zabbix version"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

choices=
if [ "${1:-}" = --choices ]; then
  choices=1 want=latest
else
  want=${1:-${ZABBIX_VERSION:-latest}}
  case $want in lts|latest|[1-9].[0-9]|[1-9][0-9].[0-9]) ;; *) dot_die "unknown Zabbix version '$want': x.y like 7.0, latest or lts" ;; esac
fi
port=${ZABBIX_WEB_PORT:-8080}
case $port in ''|*[!0-9]*) dot_die "ZABBIX_WEB_PORT must be a number, got '$port'" ;; esac
envf=/etc/zabbix/zabbix-db.env
dest=/opt/zabbix-server

# prints the versions to try, newest first: the 8 newest releases on repo.zabbix.com (x.y with an even y; an odd y is
# a development line) for latest, the x.0 ones of them for lts, else the one given
zbx_candidates() {
  case $want in
    lts|latest)
      curl -fsSL https://repo.zabbix.com/zabbix/ | grep -oE 'href="[0-9]+\.[0-9]*[02468]/"' | grep -oE '[0-9]+\.[0-9]+' |
        sort -rVu | head -n 8 | if [ "$want" = lts ]; then grep '\.0$'; else cat; fi ;;
    *) echo "$want" ;;
  esac
}

# sets zdir and arch: the folder of this system in Zabbix's repository and the architecture as the repository names it;
# zdir stays empty where Zabbix has no repository (Fedora, Arch).
# apt: by family, Linux Mint takes the ubuntu dir, Proxmox the debian dir, each with the release of its base.
zbx_sys() {
  zdir=
  case $DOT_PKG in
    apt)
      arch=$(dpkg --print-architecture)
      case $DOT_OS:$DOT_OS_BASE in
        raspi:ubuntu) zdir=ubuntu ;;
        raspi:*) zdir=raspbian ;;
        *:ubuntu) zdir=ubuntu ;;
        *:debian) zdir=debian ;;
      esac ;;
    dnf|yum)
      arch=$(uname -m)
      [ "$DOT_OS_BASE" = rhel ] || return 0
      case $DOT_OS in
        rocky|centos|rhel) zdir=$DOT_OS ;;
        almalinux) zdir=alma ;;
        ol) zdir=oracle ;;
        *) zdir=rhel ;;
      esac ;;
  esac
}

# true when Zabbix $1 has packages for this system (zbx_sys), sets base to its path below repo.zabbix.com/zabbix/.
# Two layouts: up to 7.0 <ver>/<dir>, from 7.2 <ver>/stable/<dir> with all architectures; a version still in testing
# (8.0 in 2026) has no stable dir. apt: <dir>/dists/<codename>, arm64 up to 7.0 in <dir>-arm64; rpm: <dir>/<major>/<arch>.
zbx_has() {
  local b
  [ -n "$zdir" ] || return 1
  case $DOT_PKG in
    apt)
      for b in "$1/stable/$zdir" "$1/$zdir$([ "$arch" = arm64 ] && [ "$zdir" != raspbian ] && echo -arm64)"; do
        curl -fsSL "https://repo.zabbix.com/zabbix/$b/dists/$DOT_OS_BASE_CODENAME/Release" 2>/dev/null |
          grep -q "^Architectures:.* $arch\( \|$\)" && { base=$b; return 0; }
      done ;;
    dnf|yum)
      for b in "$1/stable/$zdir/${DOT_OS_VERSION%%.*}" "$1/$zdir/${DOT_OS_VERSION%%.*}"; do
        curl -fsS -o /dev/null "https://repo.zabbix.com/zabbix/$b/$arch/repodata/repomd.xml" 2>/dev/null &&
          { base=$b; return 0; }
      done ;;
  esac
  return 1
}

# true when Docker Hub has the server image of Zabbix $1
zbx_image() {
  curl -fsS -o /dev/null "https://hub.docker.com/v2/repositories/zabbix/zabbix-server-pgsql/tags/alpine-$1-latest" 2>/dev/null
}

# prints the 5 newest versions that install here, newest first: with packages (native) or images (Docker);
# the versions are asked in parallel, the menu waits for this
zbx_choices() {
  local v
  zbx_sys
  for v in $(zbx_candidates); do
    { if [ "$DOT_MODE" = native ]; then zbx_has "$v"; else zbx_image "$v"; fi && echo "$v"; } &
  done | sort -rV | head -n 5
}

# Zabbix's apt repository for this system, the first version of zbx_candidates that has one
zbx_apt() {
  local v
  [ -n "$zdir" ] || dot_die "Zabbix has no apt repository for '$DOT_OS', see https://www.zabbix.com/download"
  for v in $(zbx_candidates); do zbx_has "$v" && { ver=$v; break; }; done
  [ -n "$ver" ] || dot_die "no Zabbix $want packages for $zdir '$DOT_OS_BASE_CODENAME' $arch, see https://www.zabbix.com/download"
  dot_info "Zabbix $ver repository: $base $DOT_OS_BASE_CODENAME $arch"
  dot_apt_repo zabbix https://repo.zabbix.com/zabbix-official-repo-apr2024.gpg \
    "https://repo.zabbix.com/zabbix/$base" "$DOT_OS_BASE_CODENAME" main "$arch"
}

# Zabbix's rpm repository for the RHEL family, the first version of zbx_candidates that has one
zbx_rpm() {
  local v
  for v in $(zbx_candidates); do zbx_has "$v" && { ver=$v; break; }; done
  [ -n "$ver" ] || dot_die "no Zabbix $want packages for $zdir ${DOT_OS_VERSION%%.*} $arch, see https://www.zabbix.com/download"
  dot_info "Zabbix $ver repository: $base $arch"
  # fping and others come from EPEL; priority: EPEL carries older Zabbix packages, the lower number wins
  dot_epel || dot_die "turning on EPEL failed"
  dot_rpm_repo zabbix "https://repo.zabbix.com/zabbix/$base/\$basearch/" \
    https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005 priority=10
}

# sets "key=value" in the config file $1: drops every active line of that key and appends the new one
zbx_set() {
  dot_sudo sed -i "/^$2=/d" "$1" && echo "$2=$3" | dot_sudo tee -a "$1" >/dev/null
}

# psql as the superuser postgres, from / (its home is not ours)
pg() { (cd / && dot_sudo runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 "$@"); }

# role, database, login over TCP from localhost with password, schema; needs a running PostgreSQL
zbx_db() {
  local hba sql
  pg -tAc "select 1 from pg_roles where rolname = 'zabbix'" | grep -q 1 || pg -c "create role zabbix login" ||
    dot_die "could not create the PostgreSQL role zabbix"
  pg -c "alter role zabbix password '$pw'" || dot_die "could not set the password of the role zabbix"
  # Zabbix needs UTF8; a system without a UTF-8 locale (containers) would create SQL_ASCII
  pg -tAc "select 1 from pg_database where datname = 'zabbix'" | grep -q 1 ||
    pg -c "create database zabbix owner zabbix encoding 'UTF8' lc_collate 'C' lc_ctype 'C' template template0" ||
    dot_die "could not create the database zabbix"
  # the RHEL family's initdb allows TCP logins with ident only; md5 also takes scram passwords
  hba=$(pg -tAc 'show hba_file')
  if ! dot_sudo grep -q '^host zabbix zabbix 127.0.0.1/32' "$hba"; then
    dot_sudo sed -i '1i host zabbix zabbix 127.0.0.1/32 md5\nhost zabbix zabbix ::1/128 md5' "$hba" &&
      pg -tAc 'select pg_reload_conf()' >/dev/null || dot_die "could not allow the zabbix login in $hba"
  fi
  if [ "$(pg -d zabbix -tAc "select to_regclass('public.users')")" != users ]; then
    sql=$(ls /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz 2>/dev/null | head -n 1)
    [ -n "$sql" ] || dot_die "server.sql.gz of zabbix-sql-scripts is missing"
    dot_info "importing the Zabbix schema ($sql), takes a minute"
    # as the owner zabbix (local peer login), so the tables belong to it
    zcat "$sql" | (cd / && dot_sudo runuser -u zabbix -- psql -X -q -v ON_ERROR_STOP=1 -d zabbix >/dev/null) ||
      dot_die "the schema import failed"
  fi
}

# Replaces the default web login Admin / zabbix with a random password through the API and keeps it in $1 (root only);
# prints the login text for the summary. A password changed before stays (the default login fails then). Waits up to
# 5 minutes: on the first start of the images the server creates the database first.
# Zabbix 7.0 and later take the token as header, 6.x in the body ("auth").
zbx_admin() {
  local file=$1 api="http://$([ "$DOT_BIND" = 0.0.0.0 ] && echo localhost || echo "$DOT_BIND"):$port/api_jsonrpc.php"
  local r tok pw v end=$((SECONDS + 300)) auth=() body
  if dot_sudo test -s "$file"; then echo "user Admin, password: sudo cat $file"; return; fi
  call() { curl -fsS -m 20 -H 'Content-Type: application/json-rpc' "${auth[@]}" -d "$1" "$api" 2>/dev/null; }
  while :; do
    r=$(call '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}')
    tok=$(jq -r '.result // empty' <<<"$r" 2>/dev/null)
    [ -n "$tok" ] && break
    # the frontend answers, but the default login is gone: changed by hand before
    grep -qi 'incorrect user name or password' <<<"$r" && break
    [ "$SECONDS" -lt "$end" ] || break
    dot_progress 0 0 "Zabbix creates its database, waiting for the web login" >&2
    sleep 3
  done
  dot_progress_end >&2
  if [ -z "$tok" ]; then echo "Admin / your password (the default zabbix no longer works or the API did not answer)"; return; fi
  # 6.4 and later: token as header and the current password in user.update; 6.0 and 6.2 know neither (28.10.26,
  # 6.0 answered "Invalid parameter" to current_passwd)
  v=$(call '{"jsonrpc":"2.0","method":"apiinfo.version","params":[],"id":1}' | jq -r '.result // "7.0"' |
    awk -F. '{ print $1 * 100 + $2 }')
  pw=$(dot_password 24)
  if [ "$v" -ge 604 ]; then
    auth=(-H "Authorization: Bearer $tok")
    body=$(jq -nc --arg p "$pw" '{jsonrpc: "2.0", method: "user.update", params: {userid: "1", current_passwd: "zabbix", passwd: $p}, id: 1}')
  else
    body=$(jq -nc --arg p "$pw" --arg t "$tok" '{jsonrpc: "2.0", method: "user.update", params: {userid: "1", passwd: $p}, auth: $t, id: 1}')
  fi
  if call "$body" | jq -e '.result.userids' >/dev/null 2>&1; then
    printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$file'"
    echo "user Admin, password: sudo cat $file"
  else
    echo "Admin / zabbix (setting a random password failed): change it right away"
  fi
}

if [ -n "$choices" ]; then zbx_choices; exit 0; fi
dot_need curl jq
# without ZABBIX_WEB_PORT: the port of an earlier run, else 8080 or, when something else has it (restreamer and
# zigbee2mqtt use 8080 too, 28.10.26), the next free one
if [ -z "${ZABBIX_WEB_PORT:-}" ]; then
  if [ "$DOT_MODE" != native ] && dot_sudo test -f "$dest/compose.yaml"; then
    p=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dest/compose.yaml") port=${p##*:}
  elif [ "$DOT_MODE" = native ] && dot_pkg_installed zabbix-server-pgsql; then
    p=$(dot_sudo sed -n 's/^ *listen *\([^ ;]*\);.*/\1/p' /etc/zabbix/nginx.conf /etc/nginx/conf.d/zabbix.conf 2>/dev/null |
      head -n 1) p=${p##*:}
    port=${p:-8080}
  elif dot_port_busy 8080; then
    port=$(dot_free_port 8081) || dot_die "port 8080 is taken and no port up to 8130 is free: set ZABBIX_WEB_PORT"
    dot_info "port 8080 is taken, the Zabbix frontend gets port $port"
  fi
  port=${port:-8080}
fi
dot_mode_guard zabbix-server zabbix-server "$port" 10051
dot_bind 0.0.0.0
ver=
zbx_sys

if [ "$DOT_MODE" != native ]; then
  case $DOT_ARCH in amd64|arm64|armv7) ;; *) dot_die "the Zabbix images have no build for $DOT_ARCH" ;; esac
  for ver in $(zbx_candidates); do zbx_image "$ver" && { tag=alpine-$ver-latest; break; }; done
  [ -n "${tag:-}" ] || dot_die "Docker Hub has no zabbix/zabbix-server-pgsql image for Zabbix $want"
  # the agent sees the container, not the host: zabbix_agent.sh watches the host
  agent=
  [ "${ZABBIX_AGENT:-yes}" = no ] || agent="
  zabbix-agent:
    image: zabbix/zabbix-agent2:$tag
    restart: unless-stopped
    depends_on: [zabbix-server]
    environment:
      ZBX_SERVER_HOST: zabbix-server
      ZBX_HOSTNAME: Zabbix server"
  dot_deploy zabbix-server "services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: zabbix
    volumes:
      - db:/var/lib/postgresql/data
  zabbix-server:
    image: zabbix/zabbix-server-pgsql:$tag
    restart: unless-stopped
    depends_on: [postgres]
    ports:
      - \"$DOT_BIND:10051:10051\"
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: zabbix
  zabbix-web:
    image: zabbix/zabbix-web-nginx-pgsql:$tag
    restart: unless-stopped
    depends_on: [postgres, zabbix-server]
    ports:
      - \"$DOT_BIND:$port:8080\"
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: zabbix
      ZBX_SERVER_HOST: zabbix-server$agent
volumes:
  db:" "POSTGRES_PASSWORD=$(dot_password 24)"
  dot_info "Zabbix $ver ($tag)"
  [ -z "$agent" ] || dot_info "agent: in host \"Zabbix server\" set the agent interface to the DNS name zabbix-agent"
  login=$(zbx_admin "$dest/admin-password")
  dot_summary zabbix-server "http://localhost:$port localhost:10051" "$login; database password: sudo cat $dest/.env"
  exit 0
fi

# nginx installed before this run is the admin's, its default site stays (see below)
had_nginx=; dot_pkg_installed nginx && had_nginx=1
case $DOT_PKG in
  apt)
    zbx_apt
    dot_pkg_install zabbix-server-pgsql zabbix-frontend-php php-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent2 \
      postgresql || dot_die "installing the Zabbix packages failed"
    nginx_conf=/etc/zabbix/nginx.conf pool=/etc/zabbix/php-fpm.conf
    fpm=$(basename "$(ls /lib/systemd/system/php*-fpm.service 2>/dev/null | sort -V | tail -n 1)" .service) ;;
  dnf|yum)
    [ "$DOT_OS_BASE" = rhel ] || dot_die "Zabbix has no rpm repository for '$DOT_OS', run it in Docker: zabbix_server.sh --docker"
    zbx_rpm
    dot_pkg_install zabbix-server-pgsql zabbix-web-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy \
      zabbix-agent2 postgresql-server || dot_die "installing the Zabbix packages failed"
    nginx_conf=/etc/nginx/conf.d/zabbix.conf pool=/etc/php-fpm.d/zabbix.conf fpm=php-fpm ;;
  *) dot_die "no Zabbix server packages for '$DOT_OS', run it in Docker: zabbix_server.sh --docker" ;;
esac

# the database password: kept from an earlier run, else generated
pw=$(dot_sudo sed -n 's/^DB_PASSWORD=//p' "$envf" 2>/dev/null)
if [ -z "$pw" ]; then
  pw=$(dot_password 24)
  dot_env_set "$envf" DB_USER zabbix && dot_env_set "$envf" DB_PASSWORD "$pw" || dot_die "could not write $envf"
fi

systemd=; [ -d /run/systemd/system ] && systemd=1
# RHEL family: the cluster is created by hand, postgresql-setup needs systemd
if [ "$DOT_PKG" != apt ] && ! dot_sudo test -f /var/lib/pgsql/data/PG_VERSION && [ -n "$systemd" ]; then
  dot_sudo postgresql-setup --initdb || dot_die "postgresql-setup --initdb failed"
fi
[ -n "$systemd" ] && { dot_sudo systemctl enable --now postgresql || dot_die "PostgreSQL does not start"; }
if pg -tAc 'select 1' >/dev/null 2>&1; then
  zbx_db
else
  dot_info "PostgreSQL is not running: start it, then run zabbix_server.sh again for the database and the schema"
fi

conf=/etc/zabbix/zabbix_server.conf
zbx_set "$conf" DBHost localhost
zbx_set "$conf" DBName zabbix
zbx_set "$conf" DBUser zabbix
zbx_set "$conf" DBPassword "$pw"
zbx_set "$conf" ListenIP "$DOT_BIND"

# the frontend's server block: the first listen line, commented out in the package
dot_sudo sed -i -E "0,/^#? *listen /s|^#? *listen .*|        listen          $DOT_BIND:$port;|" "$nginx_conf" ||
  dot_die "could not set the port in $nginx_conf"

# zabbix-nginx-conf pulls in nginx, and with it the package's default server on port 80: unnoticed it keeps the port
# open and a reverse proxy installed later (caddy.sh, traefik.sh) cannot start (28.10.26). Off when nginx came now.
if [ -z "$had_nginx" ]; then
  if [ "$DOT_PKG" = apt ]; then
    dot_sudo rm -f /etc/nginx/sites-enabled/default
  else
    # the server block in nginx.conf, indented by 4 like its closing brace; its inner blocks close deeper. The prefix
    # names who did it, nginx.sh takes it out again.
    dot_sudo sed -i '/^    server {/,/^    }/ s/^/#zabbix_server.sh: /' /etc/nginx/nginx.conf
  fi && dot_info "turned off nginx's default server on port 80 (nginx came with Zabbix)"
fi

# the frontend config the setup wizard would write; kept when it is there
web=/etc/zabbix/web/zabbix.conf.php
if ! dot_sudo test -f "$web"; then
  example=$(find /usr/share/zabbix -name zabbix.conf.php.example 2>/dev/null | head -n 1)
  [ -n "$example" ] || dot_die "zabbix.conf.php.example is missing in /usr/share/zabbix"
  group=$(sed -n 's/^group *= *//p' "$pool")
  sed -E -e "s/^(\\\$DB\['TYPE'\][[:space:]]*=).*/\1 'POSTGRESQL';/" \
    -e "s/^(\\\$DB\['SERVER'\][[:space:]]*=).*/\1 'localhost';/" \
    -e "s/^(\\\$DB\['PORT'\][[:space:]]*=).*/\1 '0';/" \
    -e "s/^(\\\$DB\['DATABASE'\][[:space:]]*=).*/\1 'zabbix';/" \
    -e "s/^(\\\$DB\['USER'\][[:space:]]*=).*/\1 'zabbix';/" \
    -e "s/^(\\\$DB\['PASSWORD'\][[:space:]]*=).*/\1 '$pw';/" "$example" |
    dot_sudo install -m 0640 -o root -g "${group:-root}" /dev/stdin "$web" || dot_die "could not write $web"
fi

if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  dot_sudo setsebool -P httpd_can_connect_zabbix on httpd_can_network_connect_db on
fi

if [ -n "$systemd" ]; then
  dot_sudo systemctl enable zabbix-server zabbix-agent2 nginx "$fpm" &&
    dot_sudo systemctl restart zabbix-server zabbix-agent2 "$fpm" nginx || dot_die "could not start the Zabbix services"
  dot_wait_http "http://$([ "$DOT_BIND" = 0.0.0.0 ] && echo localhost || echo "$DOT_BIND"):$port/" 30 ||
    dot_die "the Zabbix frontend does not answer on port $port, see: journalctl -u nginx -u $fpm"
else
  dot_info "no systemd running: start postgresql, zabbix-server, zabbix-agent2, $fpm and nginx by hand"
fi
dot_info "$(dot_sudo zabbix_server -V 2>/dev/null | head -n 1) installed, config $conf, frontend $web"
if [ -n "$systemd" ]; then login=$(zbx_admin /etc/zabbix/admin-password)
else login="Admin / zabbix (default), change it at the first login"; fi
dot_summary zabbix-server "http://localhost:$port localhost:10051" "$login; database password: sudo cat $envf"
