#!/bin/bash
# Which system is this: shared by the installers (through os.sh) and by the login shell (core.sh).
# Defines functions only, nothing that exits, so an interactive shell can source it.
# Detection is based on os-release plus the special systems, so new distro versions need no change.

# reads one key of os-release without sourcing it into the caller; /usr/lib/os-release when /etc has none, a later
# duplicate wins and the value may be quoted with " or ' (os-release spec)
# (pure bash: the login shell reads several keys, and every extra process costs on Windows and small routers)
_dot_osr() {
  local f=/etc/os-release k v r=
  [ -r "$f" ] || f=/usr/lib/os-release
  [ -r "$f" ] || return 0
  while IFS='=' read -r k v; do [ "$k" = "$1" ] && r=$v; done <"$f"
  r=${r#[\"\']}; printf '%s\n' "${r%[\"\']}"
}

# Sets DOT_OS (ubuntu, debian, arch, kali, alpine, proxmox, raspi, unraid, synology, asuswrt, …), DOT_OS_BASE (ubuntu,
# debian, arch, fedora, rhel, opensuse, alpine or empty), DOT_OS_BASE_CODENAME (release of the base: noble on Linux
# Mint 22), DOT_OS_VERSION, DOT_OS_CODENAME, DOT_OS_LIKE,
# DOT_PKG (apt|pacman|apk|opkg|dnf|yum|zypper|none) and DOT_ARCH (amd64|arm64|armv7|armv6|…)
dot_os_detect() {
  local p k v m f=/etc/os-release ID= VERSION_ID= VERSION_CODENAME= ID_LIKE= UBUNTU_CODENAME= DEBIAN_CODENAME=
  # all keys in one pass, without a subprocess
  [ -r "$f" ] || f=/usr/lib/os-release
  if [ -r "$f" ]; then
    while IFS='=' read -r k v; do
      case $k in
        ID|VERSION_ID|VERSION_CODENAME|ID_LIKE|UBUNTU_CODENAME|DEBIAN_CODENAME) v=${v#[\"\']}; printf -v "$k" '%s' "${v%[\"\']}" ;;
      esac
    done <"$f"
  fi
  DOT_OS=$ID DOT_OS_VERSION=$VERSION_ID DOT_OS_CODENAME=$VERSION_CODENAME DOT_OS_LIKE=$ID_LIKE
  # nearest family the scripts know: the ID itself, else the first known word of ID_LIKE (os-release spec), so
  # derivatives take the path of their base (Linux Mint: ubuntu, Manjaro: arch, Rocky: rhel, Kali: debian)
  DOT_OS_BASE=
  for p in $DOT_OS $DOT_OS_LIKE; do
    case $p in
      ubuntu|debian|arch|fedora|rhel|alpine) DOT_OS_BASE=$p; break ;;
      centos) DOT_OS_BASE=rhel; break ;;
      opensuse*|suse) DOT_OS_BASE=opensuse; break ;;
    esac
  done
  # vendor repositories are keyed by the base release: Linux Mint and Pop!_OS name it in UBUNTU_CODENAME, LMDE in
  # DEBIAN_CODENAME; elsewhere it is the codename itself
  case $DOT_OS_BASE in
    ubuntu) DOT_OS_BASE_CODENAME=$UBUNTU_CODENAME ;;
    debian) DOT_OS_BASE_CODENAME=$DEBIAN_CODENAME ;;
    *) DOT_OS_BASE_CODENAME= ;;
  esac
  [ -n "$DOT_OS_BASE_CODENAME" ] || DOT_OS_BASE_CODENAME=$DOT_OS_CODENAME
  # special systems first, they hide behind a generic os-release or have none
  if [ -d /etc/pve ] || command -v pveversion >/dev/null 2>&1; then
    DOT_OS=proxmox
  elif [ -r /etc/unraid-version ]; then
    DOT_OS=unraid DOT_OS_VERSION=$(sed -n 's/^version="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/unraid-version)
  elif [ -r /etc.defaults/VERSION ] || [ -r /etc/synoinfo.conf ]; then
    DOT_OS=synology DOT_OS_VERSION=$(sed -n 's/^productversion="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc.defaults/VERSION 2>/dev/null)
  elif command -v nvram >/dev/null 2>&1 && [ -n "$(nvram get productid 2>/dev/null)" ]; then
    DOT_OS=asuswrt DOT_OS_VERSION=$(nvram get buildno 2>/dev/null)
  elif [ "$DOT_OS" = raspbian ] || { [ -r /proc/device-tree/model ] && read -r -d '' v </proc/device-tree/model; [[ ${v:-} == *"Raspberry Pi"* ]]; }; then
    DOT_OS=raspi DOT_OS_LIKE=debian
  fi
  # Windows: Cygwin and Git Bash or MSYS2 have no os-release; the kernel name tells them apart (OSTYPE is "cygwin"
  # in both, 27.10.26). /proc/version starts with the name and the release of uname -s and -r ("MINGW64_NT-10.0-19045
  # version 3.6.10-5a1665c8.x86_64 ..."): a uname costs 40-70 ms there (28.10.26)
  if [ -z "$DOT_OS" ]; then
    if [ -r /proc/version ]; then read -r k _ v _ </proc/version; else k=$(uname -s) v=$(uname -r); fi
    case $k in
      CYGWIN*) DOT_OS=cygwin DOT_OS_VERSION=$v ;;
      MINGW*|MSYS*) DOT_OS=msys DOT_OS_VERSION=$v ;;
      *) DOT_OS=$(printf '%s' "$k" | tr '[:upper:]' '[:lower:]') ;;
    esac
    DOT_OS_VERSION=${DOT_OS_VERSION%%(*}
  fi

  DOT_PKG=none
  case $DOT_OS in
    # apt-cyg is Cygwin's optional command line front end; MSYS2's pacman needs no sudo and serves its own packages,
    # the Linux installers and package aliases must not take it
    cygwin) command -v apt-cyg >/dev/null 2>&1 && DOT_PKG=cyg ;;
    msys) ;;
    *)
      for p in apt-get:apt pacman:pacman apk:apk opkg:opkg dnf:dnf yum:yum zypper:zypper; do
        command -v "${p%%:*}" >/dev/null 2>&1 && { DOT_PKG=${p#*:}; break; }
      done ;;
  esac

  # bash knows the machine as HOSTTYPE, without a uname; for 32-bit ARM it says "arm", only uname -m tells v6 from v7
  m=${HOSTTYPE:-}
  case $m in x86_64|aarch64) ;; *) m=$(uname -m) ;; esac
  case $m in
    x86_64) DOT_ARCH=amd64 ;;
    aarch64|arm64) DOT_ARCH=arm64 ;;
    armv7l|armv8l) DOT_ARCH=armv7 ;;
    armv6l) DOT_ARCH=armv6 ;;
    *) DOT_ARCH=$m ;;
  esac
  # the kernel can be 64-bit under a 32-bit userland (Raspberry Pi OS armhf on a Pi 4 or 5 reports aarch64):
  # the package architecture says which binaries run here
  if command -v dpkg >/dev/null 2>&1; then
    case $(dpkg --print-architecture 2>/dev/null) in
      armhf) [ "$DOT_ARCH" = armv6 ] || DOT_ARCH=armv7 ;;
      i386) DOT_ARCH=386 ;;
    esac
  fi
  export DOT_OS DOT_OS_BASE DOT_OS_BASE_CODENAME DOT_OS_VERSION DOT_OS_CODENAME DOT_OS_LIKE DOT_PKG DOT_ARCH
}
