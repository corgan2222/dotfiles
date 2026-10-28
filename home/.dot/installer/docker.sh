#!/bin/bash
# installer: Docker Engine with compose and buildx for this system
# systems: all
# Installs Docker Engine with the compose and buildx plugins for the system it runs on,
# adds the calling user to the group docker and starts the service where systemd runs.
# Usage: docker.sh   (as a normal user with sudo; safe to run again)
# category: docker
# check: docker
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# Docker's official apt repository (docs.docker.com/engine/install): $1 = ubuntu|debian|raspbian, $2 = codename
docker_apt() {
  local repo=$1 codename=$2 arch release pkgs
  arch=$(dpkg --print-architecture)
  dot_need curl
  # check the repo before touching apt: EOL or too new releases have no packages there
  release=$(curl -fsSL "https://download.docker.com/linux/$repo/dists/$codename/Release") ||
    dot_die "Docker's $repo repository has no packages for '$codename', see https://docs.docker.com/engine/install/"
  grep -q "^Architectures:.* $arch\( \|$\)" <<<"$release" ||
    dot_die "Docker's $repo repository has no $arch packages for '$codename'"

  # unofficial packages that conflict with docker-ce, as listed in the docs
  pkgs=$(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx \
    podman-docker containerd runc 2>/dev/null | awk '$2 == "install" {print $1}')
  [ -z "$pkgs" ] || { dot_info "removing conflicting packages: $pkgs"; dot_sudo apt-get remove -y $pkgs; }

  dot_pkg_install ca-certificates curl || exit 1
  dot_sudo install -m 0755 -d /etc/apt/keyrings
  dot_sudo curl -fsSL "https://download.docker.com/linux/$repo/gpg" -o /etc/apt/keyrings/docker.asc ||
    dot_die "could not download Docker's apt key"
  dot_sudo chmod a+r /etc/apt/keyrings/docker.asc
  # older installers wrote a one-line docker.list, keep only one source
  dot_sudo rm -f /etc/apt/sources.list.d/docker.list
  dot_sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/$repo
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  dot_apt_update || dot_die "apt-get update failed"
  dot_pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ||
    dot_die "installing the Docker packages failed"
}

# Docker's official rpm repository: $1 = fedora|centos|rhel (Rocky and AlmaLinux use centos, as the docs say)
docker_rpm() {
  local pkgs p
  # unofficial packages that conflict with docker-ce, as listed in the docs (podman itself stays)
  for p in docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate \
    docker-logrotate docker-engine podman-docker; do dot_pkg_installed "$p" && pkgs="$pkgs $p"; done
  [ -z "$pkgs" ] || { dot_info "removing conflicting packages:$pkgs"; dot_sudo dnf remove -y $pkgs; }
  dot_rpm_repo docker-ce "https://download.docker.com/linux/$1/docker-ce.repo"
  # containerd.io replaces the distribution's runc
  dot_sudo dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ||
    dot_die "installing the Docker packages failed"
}

# enables and starts the service, adds the calling user to the group docker, runs a smoke test
docker_setup() {
  # the calling user: ourselves, or the user behind "sudo docker.sh"
  local user
  user=$(dot_user)
  if [ -d /run/systemd/system ]; then
    dot_sudo systemctl enable --now docker
  elif [ "$DOT_PKG" = apk ]; then
    dot_info "no systemd: start Docker with: sudo rc-update add docker default && sudo rc-service docker start"
  else
    dot_info "no systemd running: start the daemon by hand, e.g. sudo dockerd &"
  fi

  if [ "$user" != root ]; then
    getent group docker >/dev/null || dot_sudo groupadd -r docker
    if id -nG "$user" | grep -qw docker; then
      dot_info "$user is already in the group docker"
    else
      # usermod lives in /usr/sbin, outside a normal user's PATH on Debian: try it through sudo, busybox has addgroup
      if dot_sudo usermod -aG docker "$user" 2>/dev/null || dot_sudo addgroup "$user" docker 2>/dev/null; then
        dot_info "added $user to the group docker: log out and in again to use docker without sudo"
      else
        echo "warning: could not add $user to the group docker" >&2
      fi
    fi
  fi

  if dot_sudo docker info >/dev/null 2>&1; then
    local out
    if ! out=$(dot_sudo docker run --rm hello-world 2>&1); then
      echo "$out" >&2
      # Docker inside a container whose root file system is overlay itself: Docker's overlay storage cannot mount
      # there, the daemon answers but no container starts (27.10.26, Docker 29 in Docker)
      if grep -q 'failed to mount.*overlay' <<<"$out" && { [ -f /.dockerenv ] || [ -f /run/.containerenv ] ||
         grep -qs 'container=' /proc/1/environ; }; then
        dot_die "Docker runs, but cannot start containers inside this container (overlay on overlay). Give the outer
       container volumes for Docker's data, e.g. docker run -v /var/lib/docker -v /var/lib/containerd …"
      fi
      dot_die "Docker is installed, but the hello-world test container did not run (see above)"
    fi
    echo "$out" | grep -m1 'Hello from Docker'
  else
    dot_info "the Docker daemon is not running, skipped the hello-world test"
  fi
  # how to use docker, for the summary at the end
  note="sudo docker …"
  id -nG "$user" | grep -qw docker && note="docker … as $user (group docker, after a new login) or sudo docker …"
  [ "$user" = root ] && note="docker … as root"
  docker --version
  docker compose version
  docker buildx version
}

# special systems first, then the family: derivatives (Linux Mint, Pop!_OS, Rocky, AlmaLinux, Manjaro) take the
# repository of their base and its release (DOT_OS_BASE_CODENAME: noble on Linux Mint 22)
case $DOT_OS in
  raspi)
    # Ubuntu on a Pi uses the ubuntu repo, 32-bit Raspberry Pi OS the raspbian repo, 64-bit the debian repo
    if [ "$DOT_OS_BASE" = ubuntu ]; then docker_apt ubuntu "$DOT_OS_BASE_CODENAME"
    elif [ "$(dpkg --print-architecture)" = armhf ]; then docker_apt raspbian "$DOT_OS_BASE_CODENAME"
    else docker_apt debian "$DOT_OS_BASE_CODENAME"; fi ;;
  proxmox)
    echo "warning: Docker on the Proxmox host itself is discouraged, it fights with the PVE firewall and networking." >&2
    echo "         Prefer a VM or an LXC container for Docker." >&2
    # without a terminal (dot_docker_ready, a pipe) nobody can answer; "aborted" with exit 0 let the caller report a
    # stopped Docker daemon instead (28.10.26)
    [ -t 0 ] || dot_die "Docker on a Proxmox host needs a yes on a terminal: run docker.sh there by hand"
    read -r -p "Install Docker on this Proxmox host anyway? [y/N] " answer
    case $answer in [yY]|[yY][eE][sS]) ;; *) dot_die "aborted, Docker is not installed" ;; esac
    docker_apt debian "$DOT_OS_BASE_CODENAME" ;;
  kali) dot_pkg_install docker.io docker-compose docker-buildx || dot_die "installing the Docker packages failed" ;;
  unraid|synology) echo "Docker comes with $DOT_OS, nothing to install."; exit 0 ;;
  asuswrt) dot_die "Docker is not supported on $DOT_OS" ;;
  *)
    case $DOT_OS_BASE in
      ubuntu) docker_apt ubuntu "$DOT_OS_BASE_CODENAME" ;;
      debian) docker_apt debian "$DOT_OS_BASE_CODENAME" ;;
      fedora) docker_rpm fedora ;;
      rhel) if [ "$DOT_OS" = rhel ]; then docker_rpm rhel; else docker_rpm centos; fi ;;
      arch) dot_pkg_install docker docker-compose docker-buildx || dot_die "installing the Docker packages failed" ;;
      alpine) dot_pkg_install docker docker-cli-compose docker-cli-buildx || dot_die "installing the Docker packages failed" ;;
      # Docker has no repository for openSUSE, its own packages are current (Tumbleweed) or close (Leap)
      opensuse) dot_pkg_install docker docker-compose docker-buildx ||
        dot_die "installing the Docker packages failed" ;;
      *) dot_die "no Docker installer for '$DOT_OS', see https://docs.docker.com/engine/install/" ;;
    esac ;;
esac
docker_setup
# a parent installer (dot_deploy) may have exported its mode and address: Docker itself has neither
DOT_MODE=native DOT_BIND= dot_summary docker "" "none; $note, try: docker ps, docker compose ls"
