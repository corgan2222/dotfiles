#!/bin/bash
# installer: Zabbix agent 2 (newest LTS) from repo.zabbix.com
# systems: debian arch rhel
# modes: native compose portainer
# Installs Zabbix agent 2 from the official Zabbix repository (Ubuntu, Debian, Raspberry Pi OS, Proxmox, RHEL family)
# or the Arch package, points it at the Zabbix server and uses this host's name. Safe to run again.
# Zabbix publishes no repository for Fedora.
#   zabbix_agent.sh zabbix.example.org             server address (Server and ServerActive)
#   ZABBIX_SERVER=zabbix.example.org zabbix_agent.sh
#   ZABBIX_VERSION=7.0 zabbix_agent.sh ...         pin a version instead of the newest LTS
#   zabbix_agent.sh ... --docker | --portainer     image zabbix/zabbix-agent2:alpine-<LTS>-latest as compose project or
#                                                  Portainer stack "zabbix-agent2" from /opt/zabbix-agent2, with the
#                                                  host's network and process namespace (server and name in its .env)
#   --public / --local                             port 10050 on all interfaces or this host only (default all: the
#                                                  server polls it; only the Server address is allowed in either case)
# category: monitoring
# ports: 10050
# check: zabbix-agent2.service stack:zabbix-agent2
# ask: ZABBIX_SERVER "Zabbix server or proxy, e.g. zabbix.example.org"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

# used when repo.zabbix.com cannot be listed
ZABBIX_LTS=7.0
conf=/etc/zabbix/zabbix_agent2.conf
dest=/opt/zabbix-agent2

# prints the LTS versions (x.0) on repo.zabbix.com, newest first
zbx_lts_list() { curl -fsSL https://repo.zabbix.com/zabbix/ | grep -oE 'href="[0-9]+\.0/"' | grep -oE '[0-9]+\.0' | sort -rVu; }

# prints the apt base below repo.zabbix.com/zabbix/ for version $1, dir $2 (ubuntu, debian-arm64, ...), suite $3 and
# architecture $4, or nothing: from 7.2 on the packages lie in <ver>/stable/<dir> with all architectures in one dir,
# up to 7.0 in <ver>/<dir>, arm64 in <dir>-arm64 (zabbix_server.sh probes the same two layouts)
zbx_apt_base() {
  local b
  for b in "$1/stable/${2%-arm64}" "$1/$2"; do
    curl -fsSL "https://repo.zabbix.com/zabbix/$b/dists/$3/Release" 2>/dev/null |
      grep -q "^Architectures:.* $4\( \|$\)" && { echo "$b"; return; }
  done
}

# prints the newest LTS (x.0) that has packages for repository dir $1, suite $2, architecture $3
zbx_newest_lts() {
  local v
  for v in $(zbx_lts_list); do
    [ -n "$(zbx_apt_base "$v" "$1" "$2" "$3")" ] && { echo "$v"; return; }
  done
}

# Zabbix's apt repository for this system: amd64 and armhf in debian/ubuntu/raspbian, arm64 in the *-arm64 dirs
zbx_apt() {
  local dir arch ver base
  arch=$(dpkg --print-architecture)
  # by family: Linux Mint takes the ubuntu dir, Proxmox the debian dir, each with the release of its base
  case $DOT_OS:$DOT_OS_BASE in
    raspi:ubuntu) dir=ubuntu ;;
    raspi:*) dir=raspbian ;;
    *:ubuntu) dir=ubuntu ;;
    *:debian) dir=debian ;;
    *) dot_die "Zabbix has no apt repository for '$DOT_OS', see https://www.zabbix.com/download" ;;
  esac
  [ "$arch" = arm64 ] && [ "$dir" != raspbian ] && dir=$dir-arm64
  dot_need curl
  ver=${ZABBIX_VERSION:-$(zbx_newest_lts "$dir" "$DOT_OS_BASE_CODENAME" "$arch")}
  ver=${ver:-$ZABBIX_LTS}
  base=$(zbx_apt_base "$ver" "$dir" "$DOT_OS_BASE_CODENAME" "$arch")
  [ -n "$base" ] ||
    dot_die "Zabbix $ver has no $arch packages for $dir '$DOT_OS_BASE_CODENAME', see https://www.zabbix.com/download"
  dot_info "Zabbix $ver repository: $base $DOT_OS_BASE_CODENAME $arch"
  dot_apt_repo zabbix https://repo.zabbix.com/zabbix-official-repo-apr2024.gpg \
    "https://repo.zabbix.com/zabbix/$base" "$DOT_OS_BASE_CODENAME" main "$arch"
  dot_pkg_install zabbix-agent2 || dot_die "installing zabbix-agent2 failed"
}

# Zabbix's rpm repository for the RHEL family (what its zabbix-release package writes): <ver>/<dir>/<major>/<arch>
zbx_rpm() {
  local dir major=${DOT_OS_VERSION%%.*} arch v base ver=${ZABBIX_VERSION:-}
  case $DOT_OS in
    rocky|centos|rhel) dir=$DOT_OS ;;
    almalinux) dir=alma ;;
    ol) dir=oracle ;;
    *) dir=rhel ;;
  esac
  arch=$(uname -m)
  dot_need curl
  if [ -z "$ver" ]; then
    for v in $(zbx_lts_list); do
      curl -fsS -o /dev/null "https://repo.zabbix.com/zabbix/$v/$dir/$major/$arch/repodata/repomd.xml" 2>/dev/null &&
        { ver=$v; break; }
    done
  fi
  ver=${ver:-$ZABBIX_LTS}
  # from 7.2 on <ver>/stable/<dir>/<major>, up to 7.0 <ver>/<dir>/<major>
  base=$ver/$dir/$major
  curl -fsS -o /dev/null "https://repo.zabbix.com/zabbix/$ver/stable/$dir/$major/$arch/repodata/repomd.xml" 2>/dev/null &&
    base=$ver/stable/$dir/$major
  dot_info "Zabbix $ver repository: $base $arch"
  # priority: EPEL carries older Zabbix packages, the Zabbix docs exclude them; the lower number wins instead
  dot_rpm_repo zabbix "https://repo.zabbix.com/zabbix/$base/\$basearch/" \
    https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005 priority=10
  dot_pkg_install zabbix-agent2 || dot_die "installing zabbix-agent2 failed"
}

# prints the image tag for ZABBIX_VERSION, else for the newest LTS (x.0) with an alpine-x.0-latest image
zbx_docker_tag() {
  local v
  if [ -n "${ZABBIX_VERSION:-}" ]; then echo "alpine-$ZABBIX_VERSION-latest"; return; fi
  for v in $(zbx_lts_list); do
    curl -fsS -o /dev/null "https://hub.docker.com/v2/repositories/zabbix/zabbix-agent2/tags/alpine-$v-latest" 2>/dev/null &&
      { echo "alpine-$v-latest"; return; }
  done
  echo "alpine-$ZABBIX_LTS-latest"
}

# sets "key=value" in the agent config: drops every active line of that key and appends the new one
zbx_set() {
  dot_sudo sed -i "/^$1=/d" "$conf" && echo "$1=$2" | dot_sudo tee -a "$conf" >/dev/null
}

server=${1:-${ZABBIX_SERVER:-}}
[ -n "$server" ] || dot_die "the Zabbix server is required: zabbix_agent.sh <server>  or  ZABBIX_SERVER=<server> zabbix_agent.sh"
dot_secret_ok "$server" || dot_die "invalid Zabbix server '$server'"
host=$(hostname 2>/dev/null || uname -n)
dot_mode_guard zabbix-agent2 zabbix-agent2 10050
dot_bind 0.0.0.0

# Docker: host network (passive checks on the host's port 10050, the host's interfaces in net.* items) and host PID
# namespace (proc.* items see the host's processes). Not privileged: the Zabbix docs ask for --privileged or mounts of
# what the items need; CPU, memory, load, network and processes work without, the host's file systems and disks would
# need extra read-only mounts. Server and host name live in the .env and are updated on every run.
# /etc/localtime only when the host has it (without, Docker creates a directory there; see frigate.sh)
if [ "$DOT_MODE" != native ]; then
  dot_need curl
  dot_sudo install -d -m 0755 "$dest"
  dot_env_set "$dest/.env" ZBX_SERVER_HOST "$server" && dot_env_set "$dest/.env" ZBX_HOSTNAME "$host" ||
    dot_die "could not write $dest/.env"
  dot_deploy zabbix-agent2 "services:
  zabbix-agent2:
    image: zabbix/zabbix-agent2:$(zbx_docker_tag)
    container_name: zabbix-agent2
    restart: unless-stopped
    init: true
    network_mode: host
    pid: host
    environment:
      ZBX_SERVER_HOST: \${ZBX_SERVER_HOST}
      ZBX_HOSTNAME: \${ZBX_HOSTNAME}
      ZBX_LISTENIP: $DOT_BIND$([ -f /etc/localtime ] && printf '\n    volumes:\n      - /etc/localtime:/etc/localtime:ro')"
  dot_summary zabbix-agent2 "localhost:10050" "none (only Server=$server may connect), Hostname=$host"
  exit 0
fi

case $DOT_PKG in
  apt) zbx_apt ;;
  dnf|yum) [ "$DOT_OS_BASE" = rhel ] || dot_die "Zabbix has no rpm repository for '$DOT_OS', see https://www.zabbix.com/download"; zbx_rpm ;;
  pacman) dot_pkg_install zabbix-agent2 || dot_die "installing zabbix-agent2 failed" ;;
  *) dot_die "no Zabbix agent 2 installer for '$DOT_OS', see https://www.zabbix.com/download" ;;
esac
[ -f "$conf" ] || dot_die "$conf is missing after the install"

zbx_set Server "$server"
zbx_set ServerActive "$server"
zbx_set Hostname "$host"
zbx_set ListenIP "$DOT_BIND"
# the Pi temperature and throttling items (vcgencmd) need the group video
[ "$DOT_OS" = raspi ] && getent group video >/dev/null && dot_sudo usermod -aG video zabbix

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable zabbix-agent2 && dot_sudo systemctl restart zabbix-agent2 ||
    dot_die "could not start zabbix-agent2"
else
  dot_info "no systemd running: start the agent with: sudo -u zabbix zabbix_agent2 -c $conf"
fi
dot_info "$(dot_sudo zabbix_agent2 -V | head -n 1) installed: Server=$server, Hostname=$host ($conf)"
dot_summary zabbix-agent2 "localhost:10050" "none (only Server=$server may connect)"
