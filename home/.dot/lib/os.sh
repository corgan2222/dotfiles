#!/bin/bash
# Shared helpers for the installers: which system, which package manager, latest versions.
# Load from an installer with:  . "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
# Detection is based on /etc/os-release plus the special systems, so new distro versions need no change.

# _dot_osr and dot_os_detect live in detect.sh, which the login shell uses as well
. "$(dirname "${BASH_SOURCE[0]}")/detect.sh"

dot_die() { echo "error: $*" >&2; exit 1; }
dot_info() { printf '\033[96m%s\033[0m\n' "$*"; }

dot_os_detect
# the login shell loads detect.sh only, so this stops installers and leaves the shell on Windows alone
case $DOT_OS in
  cygwin|msys) dot_die "the installers are for Linux; on Windows install packages with the Cygwin setup (setup-x86_64.exe -q -P <package>)" ;;
esac

# runs a command as root: directly when we are root, else with sudo
dot_sudo() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# waits up to 5 minutes while another apt or dpkg runs (apt-daily, unattended-upgrades and cloud-init right after a
# boot hold the lock), instead of failing on "Could not get lock"
_dot_apt_wait() {
  local i=0
  command -v pgrep >/dev/null 2>&1 || return 0
  # 2>/dev/null: pgrep warns about a pattern longer than 15 characters, the alternatives still match
  while pgrep -x 'apt|apt-get|dpkg|unattended-upgr' >/dev/null 2>&1 && [ $i -lt 300 ]; do
    [ $i -eq 0 ] && dot_info "waiting for another apt or dpkg run to finish"
    sleep 5; i=$((i + 5))
  done
}

# Every installer is a process of its own, the menu runs several in a row. A stamp /run/dotfiles-<name> tells the next
# one that the package index was refreshed: _dot_fresh <name> <source files…> is true while the stamp is younger than
# 60 minutes and no source file or folder changed after it. /run is empty after a reboot.
_dot_fresh() {
  local s=/run/dotfiles-$1; shift
  [ -n "$(find "$s" -mmin -60 2>/dev/null)" ] && [ -z "$(find "$@" -newer "$s" 2>/dev/null)" ]
}
_dot_stamp() { dot_sudo touch "/run/dotfiles-$1" 2>/dev/null || true; }

# refreshes the apt package index after any running apt has finished, always (call it after adding a repository)
dot_apt_update() { _dot_apt_wait; dot_sudo apt-get update -qq && _dot_apt_updated=1 && _dot_stamp apt-updated; }

# refreshes the apt package index unless this or another installer did so in the last hour and no source changed since
dot_apt_refresh() {
  [ -n "$_dot_apt_updated" ] || _dot_fresh apt-updated /etc/apt/sources.list /etc/apt/sources.list.d || dot_apt_update
}

_dot_pacman_syu() { dot_sudo pacman -Syu --noconfirm --needed "$@" && _dot_pacman_synced=1 && _dot_stamp pacman-synced; }

_dot_apt_install() {
  dot_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}

# installs packages with the package manager of this system, without questions; apt also takes .deb paths and keeps
# changed config files on upgrades instead of asking (dpkg conffiles: confdef, else confold)
_dot_apt_updated= _dot_pacman_synced=
dot_pkg_install() {
  [ $# -gt 0 ] || return 0
  case $DOT_PKG in
    # an index taken over from another installer can be an hour old: when the install of packages it knows fails (a
    # download 404s), refresh and try again; a package it does not know fails right away, without a refresh
    apt)
      _dot_apt_wait
      dot_apt_refresh || return
      _dot_apt_install "$@" || { [ -z "$_dot_apt_updated" ] && apt-cache show "$@" >/dev/null 2>&1 &&
        dot_apt_update && _dot_apt_install "$@"; } ;;
    # the first install of a run syncs and upgrades, unless another installer did so in the last hour: an old sync
    # database asks the mirror for package versions it no longer has (404), and -Sy without -u is a partial upgrade,
    # which Arch does not support. A failed install of known packages on a database taken over from another installer
    # syncs and retries.
    pacman)
      if [ -n "$_dot_pacman_synced" ] || _dot_fresh pacman-synced /etc/pacman.conf /etc/pacman.d; then
        dot_sudo pacman -S --noconfirm --needed "$@" ||
          { [ -z "$_dot_pacman_synced" ] && pacman -Si "$@" >/dev/null 2>&1 && _dot_pacman_syu "$@"; }
      else
        _dot_pacman_syu "$@"
      fi ;;
    apk)    dot_sudo apk add "$@" ;;
    opkg)   dot_sudo opkg install "$@" ;;
    dnf)    dot_sudo dnf install -y "$@" ;;
    yum)    dot_sudo yum install -y "$@" ;;
    zypper) dot_sudo zypper --non-interactive install --no-recommends "$@" ;;
    *)      dot_die "no supported package manager on $DOT_OS, install by hand: $*" ;;
  esac
}

# makes sure the commands exist; a missing command is installed from the package of the same name
dot_need() {
  local c missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  dot_pkg_install "${missing[@]}"
}

# prints the tag of the latest release of a GitHub project: dot_github_latest astral-sh/uv
# Reads the redirect of github.com/<repo>/releases/latest, not the API: the API allows 60 requests per hour and IP.
dot_github_latest() {
  local url
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
  case $url in */releases/tag/*) echo "${url##*/releases/tag/}" ;; *) return 1 ;; esac
}

# prints the download URL of the first asset of the latest GitHub release whose name matches an extended regex:
# dot_github_asset eza-community/eza 'x86_64-unknown-linux-gnu\.tar\.gz$'
# Lists the assets from the release page (expanded_assets), without the rate-limited API.
dot_github_asset() {
  local tag
  tag=$(dot_github_latest "$1") || return 1
  curl -fsSL "https://github.com/$1/releases/expanded_assets/$tag" |
    grep -oE 'href="/[^"]+/releases/download/[^"]+"' | sed 's#^href="#https://github.com#; s#"$##' |
    grep -E -- "$2" | head -n 1
}

# downloads the asset of the latest GitHub release whose URL matches an extended regex to <file> and checks it against
# the sha256 digest GitHub shows for every release asset; sets DOT_GITHUB_TAG to the release tag:
# dot_github_fetch orf/gping '/gping-Linux-musl-x86_64\.tar\.gz$' "$tmp/gping.tar.gz"
# A 4th argument takes that tag instead of the latest release (repos with several products, bitwarden/clients).
dot_github_fetch() {
  local page url name sum
  DOT_GITHUB_TAG=${4:-$(dot_github_latest "$1")} || { echo "cannot read the latest release of $1 from GitHub" >&2; return 1; }
  page=$(curl -fsSL "https://github.com/$1/releases/expanded_assets/$DOT_GITHUB_TAG") || return 1
  url=$(grep -oE 'href="/[^"]+/releases/download/[^"]+"' <<<"$page" | sed 's#^href="#https://github.com#; s#"$##' |
    grep -E -- "$2" | head -n 1)
  [ -n "$url" ] || { echo "$1 $DOT_GITHUB_TAG has no asset matching $2" >&2; return 1; }
  name=${url##*/}
  sum=$(grep -F "digest for $name\"" <<<"$page" | grep -oE 'sha256:[0-9a-f]{64}' | head -n 1)
  [ -n "$sum" ] || { echo "GitHub shows no sha256 digest for $name, not installing it unchecked" >&2; return 1; }
  curl -fsSL -o "$3" "$url" || { echo "download of $url failed" >&2; return 1; }
  [ "$(sha256sum "$3" | cut -d' ' -f1)" = "${sum#sha256:}" ] || { echo "checksum of $name does not match, aborting" >&2; return 1; }
}

# adds a vendor apt repository the way the vendors document it today: key in /etc/apt/keyrings, deb822 .sources file;
# replaces an older one-line .list of the same name and refreshes the package list.
# dot_apt_repo <name> <key url> <repo url> <suite> <components> [architectures]
dot_apt_repo() {
  local name=$1 key=$2 uri=$3 suite=$4 comp=$5 arch=${6:-$(dpkg --print-architecture)} tmp ext
  [ "$DOT_PKG" = apt ] || dot_die "dot_apt_repo needs apt"
  dot_need curl
  tmp=$(mktemp) && curl -fsSL -o "$tmp" "$key" || { rm -f "$tmp"; dot_die "could not download the key $key"; }
  # armored keys keep .asc, binary keys need .gpg, apt decides by the extension
  if grep -q 'BEGIN PGP PUBLIC KEY' "$tmp"; then ext=asc; else ext=gpg; fi
  dot_sudo install -m 0755 -d /etc/apt/keyrings
  dot_sudo install -m 0644 "$tmp" "/etc/apt/keyrings/$name.$ext" && rm -f "$tmp"
  dot_sudo rm -f "/etc/apt/sources.list.d/$name.list"
  printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: %s\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/%s.%s\n' \
    "$uri" "$suite" "$comp" "$arch" "$name" "$ext" | dot_sudo tee "/etc/apt/sources.list.d/$name.sources" >/dev/null
  # a repository apt cannot read breaks every later apt-get update: take it out again
  dot_apt_update || {
    dot_sudo rm -f "/etc/apt/sources.list.d/$name.sources" "/etc/apt/keyrings/$name.$ext"
    dot_die "apt-get update failed with the $name repository, removed it again"
  }
}

# adds a vendor rpm repository (Fedora, RHEL family): /etc/yum.repos.d/<name>.repo, either downloaded as the vendor
# publishes it (a URL with .repo) or written from base url and key; removes it again when dnf cannot read it.
#   dot_rpm_repo <name> <url of a .repo file> [key url]    the key url replaces its gpgkey= (dot_rpm_key)
#   dot_rpm_repo <name> <base url> <key url> [more lines, e.g. "priority=9"]
dot_rpm_repo() {
  local name=$1 url=$2 key=${3:-} more=${4:-} f=/etc/yum.repos.d/$1.repo
  case $DOT_PKG in dnf|yum) ;; *) dot_die "dot_rpm_repo needs dnf or yum" ;; esac
  if [[ $url == *.repo || $url == *.repo\?* ]]; then
    dot_need curl
    # through a file: in "curl | tee" the status of tee counted, a 404 left an empty .repo (28.10.26)
    local tmp
    tmp=$(mktemp) && curl -fsSL -o "$tmp" "$url" && grep -q '^\[' "$tmp" ||
      { rm -f "$tmp"; dot_die "could not download $url (or it is no .repo file)"; }
    [ -z "$key" ] || sed -i "s|^gpgkey=.*|gpgkey=$key|" "$tmp"
    dot_sudo install -m 0644 "$tmp" "$f" || { rm -f "$tmp"; dot_die "could not write $f"; }
    rm -f "$tmp"
  else
    printf '[%s]\nname=%s\nbaseurl=%s\nenabled=1\ngpgcheck=1\ngpgkey=%s\n%s' "$name" "$name" "$url" "$key" \
      "${more:+$more$'\n'}" | dot_sudo tee "$f" >/dev/null
  fi
  # a repository dnf cannot read breaks every later install: take it out again
  dot_sudo "$DOT_PKG" -q -y makecache >/dev/null 2>&1 || {
    dot_sudo rm -f "$f"
    dot_die "$DOT_PKG cannot read the $name repository, removed it again"
  }
}

# Keeps of the OpenPGP keys in <file> only the one whose primary fingerprint is listed (armored) and prints that
# fingerprint; fails when none matches. apt and rpm trust every key in the file, and a vendor that changes its key
# ships old and new together for a while (28.10.26). Needs gpg. dot_key_only <file> <fingerprint…>
dot_key_only() {
  local f=$1 g fp got rc=1; shift
  # a keyring of its own: the caller's keyring stays untouched
  g=$(mktemp -d) || return 1
  if gpg --homedir "$g" -q --batch --import "$f" 2>/dev/null; then
    for fp; do
      got=$(gpg --homedir "$g" --batch --with-colons --list-keys "$fp" 2>/dev/null |
        awk -F: '/^pub/ { p = 1; next } p && /^fpr/ { print $10; exit }')
      [ "$got" = "$fp" ] || continue
      gpg --homedir "$g" --batch --armor --export "$fp" > "$f.only" && mv "$f.only" "$f" && echo "$fp" && rc=0
      break
    done
  fi
  gpgconf --homedir "$g" --kill all 2>/dev/null
  rm -rf "$g" "$f.only"
  return $rc
}

# Downloads the key of an rpm repository, keeps of it only the key with a listed fingerprint (dot_key_only) and stores
# it as /etc/pki/rpm-gpg/RPM-GPG-KEY-<name>; prints its file:// URL for gpgkey= (dot_rpm_repo). dnf -y imports
# whatever gpgkey= names without a question, so a key from the vendor's URL was trusted unchecked (28.10.26, review).
#   key=$(dot_rpm_key <name> <key url> <fingerprint…>) || exit 1
dot_rpm_key() {
  local name=$1 url=$2 tmp f=/etc/pki/rpm-gpg/RPM-GPG-KEY-$1; shift 2
  # >&2: the caller reads the URL from stdout. Minimal Fedora and RHEL images have no gpg, its package is gnupg2.
  { dot_need curl && { command -v gpg >/dev/null 2>&1 || dot_pkg_install gnupg2; }; } >&2 ||
    dot_die "installing curl or gpg failed"
  tmp=$(mktemp) || return 1
  curl -fsSL -o "$tmp" "$url" || { rm -f "$tmp"; dot_die "could not download the key $url"; }
  dot_key_only "$tmp" "$@" >/dev/null ||
    { rm -f "$tmp"; dot_die "$url holds no key with a listed fingerprint ($*), not trusting it"; }
  dot_sudo install -D -m 0644 "$tmp" "$f" || { rm -f "$tmp"; dot_die "could not write $f"; }
  rm -f "$tmp"
  echo "file://$f"
}

# RHEL family (Rocky, AlmaLinux): turns on EPEL and CodeReady Builder, where many tools live (htop, ncdu, redis tools);
# a no-op elsewhere
dot_epel() {
  [ "$DOT_OS_BASE" = rhel ] || return 0
  dot_pkg_installed epel-release && return 0
  dot_pkg_install dnf-plugins-core epel-release || return
  dot_sudo dnf config-manager --set-enabled crb >/dev/null 2>&1 || dot_sudo dnf config-manager --set-enabled powertools >/dev/null 2>&1
  dot_sudo dnf -q -y makecache >/dev/null
}

# --- installation mode of a service: native packages, Docker compose or a Portainer stack on this host ---

# Sets DOT_MODE (native|compose|portainer) from --native, --docker/--compose, --portainer or $INSTALL_MODE
# (default native) and leaves the other arguments in DOT_ARGS. Also takes --public, --local and --bind=<address>
# for dot_bind. In an installer:
#   dot_mode "$@"; set -- "${DOT_ARGS[@]}"
dot_mode() {
  local a
  DOT_MODE=${INSTALL_MODE:-native} DOT_ARGS=()
  for a in "$@"; do
    case $a in
      --native) DOT_MODE=native ;;
      --docker|--compose) DOT_MODE=compose ;;
      --portainer) DOT_MODE=portainer ;;
      --public) BIND_ADDR=0.0.0.0 _dot_bind_given=0.0.0.0 ;;
      --local) BIND_ADDR=127.0.0.1 _dot_bind_given=127.0.0.1 ;;
      --bind=*) BIND_ADDR=${a#--bind=} _dot_bind_given=${a#--bind=} ;;
      *) DOT_ARGS+=("$a") ;;
    esac
  done
  [ "$DOT_MODE" = docker ] && DOT_MODE=compose
  case $DOT_MODE in native|compose|portainer) ;; *) dot_die "unknown install mode '$DOT_MODE' (native, compose, portainer)" ;; esac
  export DOT_MODE
}

# Sets DOT_BIND, the address a service listens on: 0.0.0.0 (all interfaces) or 127.0.0.1 (this host only).
# Order: --public/--local/--bind=… (dot_mode), else the address of an earlier run given as $2, else $BIND_ADDR (the
# menu asks once and sets it), else a question on a terminal, else the product's default given as $1. Use it for the
# service config and as "${DOT_BIND}:<port>:<port>" in compose files.
#   dot_bind 127.0.0.1 "$old"  (Redis-like services default to local, web UIs to 0.0.0.0; $old: empty on a first run)
# The earlier address beats BIND_ADDR: the menu always passes its answer, and an update from the menu moved
# VictoriaMetrics from 0.0.0.0 to 127.0.0.1 and cut off the hosts writing to it (28.10.26).
# BIND_ADDR=own: the product's default without a question; the menu passes it to services that are useless without
# the network (VPN servers, ssh, samba, zabbix_agent) instead of its own answer.
dot_bind() {
  local def=${1:-0.0.0.0} a
  if [ -n "${_dot_bind_given:-}" ]; then
    a=$_dot_bind_given
  elif [ -n "${2:-}" ]; then
    a=$2
  elif [ "${BIND_ADDR:-}" = own ]; then
    a=
  elif [ -n "${BIND_ADDR:-}" ]; then
    a=$BIND_ADDR
  elif [ -t 0 ] && [ -t 1 ]; then
    read -r -p "Listen on all interfaces (0.0.0.0) or on this host only (127.0.0.1)? [$def] " a
  fi
  case ${a:-$def} in
    all|public|0.0.0.0) DOT_BIND=0.0.0.0 ;;
    local|localhost|127.0.0.1) DOT_BIND=127.0.0.1 ;;
    *[!0-9.:a-fA-F]*) dot_die "not an IP address: ${a:-$def}" ;;
    *) DOT_BIND=${a:-$def} ;;
  esac
  export DOT_BIND BIND_ADDR=$DOT_BIND
}

# Prints how to reach a service that was just installed, the same way in every installer:
#   dot_summary <name> "<url or host:port> …" ["<where the login is>"] [systemd unit, default <name>]
# localhost in the addresses is shown as this host's IP when the service listens on all interfaces.
# With DOT_SUMMARY_FILE set (installer.sh does), the lines are also appended there for a recap after several installers.
# The secret files it names follow with their content (_dot_show_secrets, off with DOT_SHOW_SECRETS=0).
dot_summary() {
  # address and login in orange: what the user has to note
  local name=$1 addrs=$2 login=${3:-} unit=${4:-$1} ip a o='\033[38;5;208m' r='\033[0m' shown=() where lines
  # without awk: minimal openSUSE images have none (28.10.26)
  read -r ip _ < <(hostname -I 2>/dev/null)
  for a in $addrs; do
    [ "${DOT_BIND:-}" = 0.0.0.0 ] && [ -n "$ip" ] && a=${a//localhost/$ip}
    shown+=("$a")
  done
  case ${DOT_MODE:-native} in
    native)    where="service: systemctl status $unit   logs: journalctl -u $unit -f" ;;
    compose)   where="docker:  /opt/$name/compose.yaml   logs: sudo docker compose -p $name logs -f" ;;
    portainer) where="stack:   $name in Portainer (files in /opt/$name)" ;;
  esac
  lines=$(_dot_secret_lines "$name" "$login")
  # with an unlocked Bitwarden vault (installer.sh asks, lib/bw.sh) the login goes there first, also with
  # DOT_SHOW_SECRETS=0, so the summary and its recap name the item; without user, password or secret nothing is stored.
  # The session comes from BW_SESSION or the file of this boot (installer.sh passes it no further), in a subshell:
  # the installer's other commands never see it.
  local vault=
  if command -v bw >/dev/null 2>&1; then
    . "$(dirname "${BASH_SOURCE[0]}")/bw.sh"
    vault=$( { [ -n "${BW_SESSION:-}" ] || dot_bw_resume; } || exit 0
      dot_bw_store "$name" "${shown[*]}" "$login" "${where%%   *}" "$lines") ||
      { vault=; echo "warning: could not store the login of $name in Bitwarden" >&2; }
  fi
  {
  printf '\n\033[92m=== %s is ready ===\033[0m\n' "$name"
  for a in "${shown[@]}"; do printf "  address: $o%s$r\n" "$a"; done
  [ -n "${DOT_BIND:-}" ] && printf '  listens: %s\n' "$([ "$DOT_BIND" = 127.0.0.1 ] && echo "this host only ($DOT_BIND)" || echo "all interfaces ($DOT_BIND)")"
  # Docker publishes its ports past firewalld and ufw, only a native service needs a hole
  if [ "${DOT_MODE:-native}" = native ] && [ -n "${DOT_BIND:-}" ] && [ "$DOT_BIND" != 127.0.0.1 ]; then
    dot_firewall_open $(_dot_addr_ports $addrs)
  fi
  printf "  login:   $o%s$r\n" "${login:-none}"
  printf '  %s\n' "$where"
  [ -z "$vault" ] || printf '  vault:   \033[95mBitwarden, folder dotfiles: %s\033[0m\n' "$vault"
  [ "${DOT_SHOW_SECRETS:-1}" = 0 ] || [ -z "$lines" ] || _dot_show_secrets <<<"$lines"
  } | if [ -n "${DOT_SUMMARY_FILE:-}" ]; then tee -a "$DOT_SUMMARY_FILE"; else cat; fi
}

# Prints "<file><TAB><line>" for each line of the secret files of a summary, so nobody has to "sudo cat" them
# afterwards: every path in the login text whose name says secret (.env, password, credentials, token, secret; e.g.
# cloudflared's /etc/cloudflared/tunnel.env), plus /opt/<name>/.env of a Docker install; of other files only the lines
# a "sudo grep <word> <file>" in the login text names (garage's admin_token in garage.toml). Hashes (passwd,
# users.yml) stay out.
_dot_secret_lines() {
  local f l w seen=' ' extra= rest=$2 re='sudo grep ([A-Za-z0-9_]+) (/[A-Za-z0-9_./-]+)'
  [ "${DOT_MODE:-native}" = native ] || extra=/opt/$1/.env
  for f in $(grep -oE '/[A-Za-z0-9_./-]+' <<<"$2") $extra; do
    case ${f##*/} in *.env|*password*|*credentials*|*token*|*secret*|*-auth.conf) ;; *) continue ;; esac
    [[ $seen == *" $f "* ]] && continue
    seen+="$f "
    dot_sudo test -f "$f" || continue
    [ "$(dot_sudo stat -c %s "$f" 2>/dev/null || echo 0)" -le 4096 ] || continue
    while IFS= read -r l || [ -n "$l" ]; do printf '%s\t%s\n' "$f" "$l"; done < <(dot_sudo cat "$f")
  done
  while [[ $rest =~ $re ]]; do
    w=${BASH_REMATCH[1]} f=${BASH_REMATCH[2]} rest=${rest#*"${BASH_REMATCH[0]}"}
    [[ $seen == *" $f "* ]] && continue
    seen+="$f "
    dot_sudo test -f "$f" || continue
    while IFS= read -r l; do printf '%s\t%s\n' "$f" "$l"; done < <(dot_sudo grep -- "$w" "$f")
  done
}

# prints the lines of _dot_secret_lines under their file names, values in orange (DOT_SHOW_SECRETS=0: dot_summary
# leaves them out, for screen sharing and logs)
_dot_show_secrets() {
  local f l last= o='\033[38;5;208m' r='\033[0m'
  while IFS=$'\t' read -r f l; do
    [ "$f" = "$last" ] || { printf '  secret:  \033[1m%s\033[0m\n' "$f"; last=$f; }
    printf "           $o%s$r\n" "$l"
  done
}

# Draws one progress line on the terminal and redraws it in place: dot_progress <done> <total> <text>.
# total 0: a spinner with the seconds since the first call with this text. dot_progress_end clears the line.
# Nothing without a terminal (logs, pipes).
dot_progress() {
  [ -t 1 ] || return 0
  local w=30 n=$1 t=$2 i bar rest f full=█ empty=░ spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  # bars and braille only with a UTF-8 locale, else plain ASCII
  [[ ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} == *[Uu][Tt][Ff]* ]] || { full='#' empty='-' spin='|/-\'; }
  [ "${_dot_prog_text:-}" = "$3" ] || { _dot_prog_text=$3 _dot_prog_t0=$SECONDS _dot_prog_i=0; }
  if [ "$t" -gt 0 ]; then
    i=$((n * w / t)); [ $i -le $w ] || i=$w
    printf -v bar '%*s' $i ''; printf -v rest '%*s' $((w - i)) ''
    printf "\r  %s \033[38;5;208m%s\033[90m%s\033[0m %d/%d  %ds \033[K" "$3" "${bar// /$full}" "${rest// /$empty}" \
      "$n" "$t" $((SECONDS - _dot_prog_t0))
  else
    f=${spin:$((_dot_prog_i++ % ${#spin})):1}
    printf "\r  \033[38;5;208m%s\033[0m %s  %ds \033[K" "$f" "$3" $((SECONDS - _dot_prog_t0))
  fi
}
dot_progress_end() { [ -t 1 ] && [ -n "${_dot_prog_text:-}" ] && printf '\r\033[K'; _dot_prog_text=; }

# prints the TCP ports in the addresses of dot_summary: host:port, else the port of the scheme (http, https, smb)
_dot_addr_ports() {
  local a
  for a; do
    if [[ $a =~ (localhost|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+) ]]; then echo "${BASH_REMATCH[2]}"
    else case $a in http://localhost*) echo 80 ;; https://localhost*) echo 443 ;; smb://*|\\\\*) echo 445 ;; esac; fi
  done | sort -un
}

# Opens ports permanently in an active firewalld (Fedora, RHEL family) or ufw (Ubuntu): dot_firewall_open 3000 9993/udp
# A port without /udp is TCP. Does nothing when neither runs. dot_summary calls it for a native service on all
# interfaces; an installer calls it itself for UDP ports.
dot_firewall_open() {
  local p fw opened= path=$PATH:/usr/sbin:/sbin
  [ $# -gt 0 ] || return 0
  if PATH=$path command -v firewall-cmd >/dev/null 2>&1 &&
    [ "$(dot_sudo firewall-cmd --state 2>/dev/null)" = running ]; then fw=firewalld
  elif PATH=$path command -v ufw >/dev/null 2>&1 && dot_sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
    fw=ufw
  else
    return 0
  fi
  for p; do
    case $p in */*) ;; *) p=$p/tcp ;; esac
    case $fw in
      # permanent and at runtime, no --reload: it drops every rule set at runtime only, also those of others
      # (28.10.26, review)
      firewalld) dot_sudo firewall-cmd -q --permanent --add-port="$p" && dot_sudo firewall-cmd -q --add-port="$p" ;;
      ufw) dot_sudo ufw allow "$p" >/dev/null ;;
    esac || { echo "warning: could not open $p in $fw" >&2; continue; }
    opened="$opened $p"
  done
  [ -z "$opened" ] || printf '  firewall: opened%s (%s)\n' "$opened" "$fw"
}

# Runs a stack on this host from a compose file: dot_deploy <name> <compose yaml> [.env content]
# Files go to /opt/<name>/compose.yaml and /opt/<name>/.env (0600); both are written on the first run only, later runs
# keep local edits and pull newer images. DOT_MODE compose starts it with docker compose, DOT_MODE portainer hands the
# same file to the local Portainer as a stack (bind mounts work, Portainer manages this host's Docker).
# Bind mounts need absolute paths (/opt/<name>/…): a stack in Portainer has no project directory, ./x breaks there.
# DOT_NO_START=1 only writes the files (for heavy services in small test systems).
dot_deploy() {
  local name=$1 yaml=$2 envs=${3:-} dir=/opt/$1
  dot_sudo install -d -m 0755 "$dir"
  if dot_sudo test -f "$dir/compose.yaml"; then
    dot_info "keeping $dir/compose.yaml (delete it to get the default again)"
  else
    printf '%s\n' "$yaml" | dot_sudo tee "$dir/compose.yaml" >/dev/null
  fi
  if [ -n "$envs" ] && ! dot_sudo test -f "$dir/.env"; then
    printf '%s\n' "$envs" | dot_sudo sh -c "umask 077; cat > '$dir/.env'"
  fi
  [ -n "${DOT_NO_START:-}" ] && { dot_info "files in $dir written, not started (DOT_NO_START)"; return 0; }
  dot_docker_ready "$name"
  # images first, with Docker's own progress bars: Portainer pulls silently in the background, so a stack of big
  # images looked stuck (Grafana, 28.10.26); Portainer then finds them here
  # a failed pull (Docker Hub's rate limit, 429, hit the tests of 28.10.26) is no reason to stop when every image is
  # here already: the stack then starts with those
  if ! dot_sudo docker compose -f "$dir/compose.yaml" --project-directory "$dir" -p "$name" pull; then
    local img
    for img in $(dot_sudo docker compose -f "$dir/compose.yaml" --project-directory "$dir" -p "$name" config --images 2>/dev/null); do
      dot_sudo docker image inspect "$img" >/dev/null 2>&1 || dot_die "could not pull the images of $name ($img is missing)"
    done
    echo "warning: could not pull newer images of $name, going on with the ones here" >&2
  fi
  case $DOT_MODE in
    portainer) dot_portainer_stack "$name" "$dir" ;;
    *) dot_sudo docker compose -f "$dir/compose.yaml" --project-directory "$dir" -p "$name" up -d --remove-orphans ||
         dot_die "docker compose could not start $name" ;;
  esac
}

# true when something listens on the port, TCP unless /udp follows (IPv4 and IPv6): dot_port_busy 1883,
# dot_port_busy 51820/udp
dot_port_busy() {
  local p=${1%/*} t=tcp st=0A
  [ "${1#*/}" = udp ] && t=udp st=07
  if command -v ss >/dev/null 2>&1; then
    # -l with -u: the unconnected UDP sockets, the ones a server receives on
    ss -Hl"${t:0:1}"n "sport = :$p" 2>/dev/null | grep -q .
  else
    # local address :PORT, remote address all zeros (8 hex digits in tcp, 32 in tcp6); state 0A = LISTEN, an
    # unconnected UDP socket is 07 (CLOSE)
    grep -qiE ":$(printf '%04X' "$p") 0{8}(0{24})?:0000 $st" "/proc/net/$t" "/proc/net/${t}6" 2>/dev/null
  fi
}

# prints the first free port from $1 on (TCP, or UDP with /udp), at most 50 further, without the /udp:
# port=$(dot_free_port 8081)
dot_free_port() {
  local p=${1%/*} s=
  [ "$p" = "$1" ] || s=/${1#*/}
  while dot_port_busy "$p$s"; do p=$((p + 1)); [ "$p" -lt $((${1%/*} + 50)) ] || return 1; done
  echo "$p"
}

# the URL Portainer gives its environment of this host's Docker (portainer.sh mounts the socket there)
DOT_DOCKER_SOCK=unix:///var/run/docker.sock

# Creates or updates the Portainer stack <name> from <dir>/compose.yaml (+ .env) on Portainer's local Docker environment.
# Portainer and its API token come from portainer.sh (/etc/portainer/api-token) or PORTAINER_URL/PORTAINER_TOKEN.
dot_portainer_stack() {
  local name=$1 dir=$2 url=${PORTAINER_URL:-https://localhost:9443} token=${PORTAINER_TOKEN:-} k= ep id env_json body r
  [ -n "$token" ] || token=$(dot_sudo cat /etc/portainer/api-token 2>/dev/null)
  [ -n "$token" ] || dot_die "no Portainer API token: run portainer.sh first or set PORTAINER_TOKEN"
  dot_need jq curl
  # Portainer on this host uses its own self-signed certificate
  case $url in https://localhost*|https://127.0.0.1*) k=-k ;; esac
  # every answer goes through a variable: in "curl | jq" the status of jq counted, so a 500 on creating the stack
  # left the id empty and the stack was reported as deployed (28.10.26)
  r=$(curl -fsS $k -H "X-API-Key: $token" "$url/api/endpoints") || dot_die "Portainer at $url does not answer"
  # the environment on this host's socket: type 1 is any Docker API, also a remote one added before (28.10.26, review)
  ep=$(jq -r --arg s "$DOT_DOCKER_SOCK" '[.[] | select(.Type == 1 and .URL == $s)][0].Id // empty' <<<"$r")
  [ -n "$ep" ] || dot_die "Portainer has no environment for this host's Docker ($DOT_DOCKER_SOCK): run portainer.sh"
  env_json=$(dot_sudo cat "$dir/.env" 2>/dev/null |
    jq -Rn '[inputs | select(test("^[A-Za-z_][A-Za-z0-9_]*=")) | capture("^(?<name>[^=]+)=(?<value>.*)$")]')
  body=$(dot_sudo cat "$dir/compose.yaml" | jq -Rs --arg n "$name" --argjson e "${env_json:-[]}" \
    '{name: $n, stackFileContent: ., env: $e}')
  r=$(curl -fsS $k -H "X-API-Key: $token" "$url/api/stacks") || dot_die "Portainer does not list its stacks"
  id=$(jq -r --arg n "$name" --argjson ep "$ep" '[.[] | select(.Name == $n and .EndpointId == $ep)][0].Id // empty' \
    <<<"$r")
  if [ -n "$id" ]; then
    _dot_portainer_wait "$url" "$k" "$token" "$id" "$name"
    jq '{stackFileContent, env, prune: true, pullImage: true}' <<<"$body" |
      curl -fsS $k -X PUT -H "X-API-Key: $token" -H 'Content-Type: application/json' --data @- \
        "$url/api/stacks/$id?endpointId=$ep" >/dev/null || dot_die "updating the Portainer stack $name failed"
  else
    r=$(curl -fsS $k -X POST -H "X-API-Key: $token" -H 'Content-Type: application/json' --data "$body" \
      "$url/api/stacks/create/standalone/string?endpointId=$ep") || dot_die "creating the Portainer stack $name failed"
    id=$(jq -r '.Id // empty' <<<"$r")
    [ -n "$id" ] || dot_die "Portainer created no stack $name: $r"
  fi
  _dot_portainer_wait "$url" "$k" "$token" "$id" "$name"
  dot_info "Portainer stack $name is deployed ($url)"
}

# Portainer 2.3x and later deploy a stack in the background: the API answers at once, DeploymentStatus[-1].Status is 3
# while it pulls and starts, 1 when done (28.10.26, Portainer 2.45.3: node_exporter checked its port while the stack
# was still "Deploying", grafana-plugins updated a stack that was still deploying). Waits up to 10 minutes; an older
# Portainer without DeploymentStatus counts as done. _dot_portainer_wait <url> <-k or ""> <token> <id> <name>
_dot_portainer_wait() {
  local s end=$((SECONDS + 600)) said=
  [ -n "$4" ] || dot_die "no id of the Portainer stack $5"
  while :; do
    s=$(curl -fsS $2 -H "X-API-Key: $3" "$1/api/stacks/$4") || dot_die "Portainer does not answer for the stack $5"
    s=$(jq -c '.DeploymentStatus[-1] // {Status: 1}' <<<"$s")
    case $(jq -r .Status <<<"$s") in
      1) dot_progress_end; return 0 ;;
      3) ;;
      *) dot_progress_end; dot_die "Portainer could not deploy the stack $5: $s (see Stacks → $5 in Portainer)" ;;
    esac
    [ "$SECONDS" -lt "$end" ] || { dot_progress_end; dot_die "the Portainer stack $5 is still deploying after 10 minutes"; }
    dot_progress 0 0 "Portainer deploys $5"
    [ -t 1 ] || [ -n "$said" ] || { dot_info "waiting for Portainer to deploy $5"; said=1; }
    sleep 1
  done
}

# Installs Docker with docker.sh (next to the calling installer) when it is missing and dies unless the daemon answers.
# Call it before "docker run"/"docker pull" of your own; dot_deploy calls it. dot_docker_ready [for what]
dot_docker_ready() {
  command -v docker >/dev/null 2>&1 || bash "$(dirname "$(readlink -f "$0")")/docker.sh" </dev/null ||
    dot_die "Docker is needed${1:+ for $1}, docker.sh failed"
  dot_sudo docker info >/dev/null 2>&1 || dot_die "the Docker daemon is not running (sudo systemctl start docker)"
}

# true when a container of the compose project or Portainer stack <name> runs: dot_stack_running grafana
dot_stack_running() {
  command -v docker >/dev/null 2>&1 &&
    dot_sudo docker ps -q --filter "label=com.docker.compose.project=$1" 2>/dev/null | grep -q .
}

# Prints how Grafana runs in Docker here (grafana.sh --docker/--portainer, /opt/grafana): "host" in the host network
# (since 28.10.26), it reaches services on this host's 127.0.0.1 and reads /opt/grafana/provisioning/datasources;
# "bridge" (compose.yaml of an earlier run, kept), it reaches the host's network address only and reads no
# provisioning from the host; nothing without Grafana in Docker.
dot_grafana_docker() {
  dot_sudo test -f /opt/grafana/compose.yaml || return 0
  if dot_sudo grep -q '^ *network_mode: *host' /opt/grafana/compose.yaml; then echo host; else echo bridge; fi
}

# Refuses a second copy of a service on the same ports, native next to its Docker stack or the other way round:
#   dot_mode_guard <stack> <systemd unit> [port…]     after dot_mode, e.g. dot_mode_guard grafana grafana-server 3000
# native: dies while the stack <stack> runs (/opt/<stack>). compose/portainer: dies while <unit> is active and, as long
# as the stack does not run yet (first deploy), when one of the ports is in use.
dot_mode_guard() {
  local s=$1 u=$2 p; shift 2
  if [ "$DOT_MODE" = native ]; then
    dot_stack_running "$s" && dot_die "$s runs in Docker here (/opt/$s): remove that stack before installing it natively"
    return 0
  fi
  systemctl is-active -q "$u" 2>/dev/null && dot_die "$u runs natively here, stop it first: sudo systemctl disable --now $u"
  dot_stack_running "$s" && return 0
  for p; do dot_port_busy "$p" && dot_die "port $p is already in use, $s cannot start in Docker"; done
  return 0
}

# sets KEY=value in the root-only env file (created 0600 when missing), other lines stay: dot_env_set <file> <key> <value>
# The value goes in on stdin: as an argument of sh -c a password or token stood in the process list (28.10.26)
dot_env_set() {
  printf '%s' "$3" | dot_sudo sh -c 'umask 077; v=$(cat); touch "$1" &&
    { grep -v "^$2=" "$1"; printf "%s=%s\n" "$2" "$v"; } > "$1.new" && mv "$1.new" "$1"' sh "$1" "$2"
}

# prints a random password of letters and digits, default 24 characters: pw=$(dot_password 32)
dot_password() { head -c $((${1:-24} * 4)) /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "${1:-24}"; }

# true when a secret or address can go unquoted into .env files, configs and command lines (no spaces, quotes, $ or
# backslashes): dot_secret_ok "$pw" || dot_die "PASSWORD must not contain spaces, quotes, \$ or backslashes"
dot_secret_ok() { case $1 in *[[:space:]\$\'\"\\]*) return 1 ;; esac; }

# Waits until the URL answers with an HTTP status matching the extended regex (default 2..), at most <seconds>
# (default 30); https on localhost skips the certificate check. dot_wait_http <url> [seconds] [status regex]
#   dot_wait_http http://localhost:8086/health 60 '2..|401'  || dot_die "influxdb does not answer"
dot_wait_http() {
  local url=$1 end=$((SECONDS + ${2:-30})) want=${3:-2..} k= code
  case $url in https://localhost*|https://127.0.0.1*) k=-k ;; esac
  while :; do
    code=$(curl -s $k -m 10 -o /dev/null -w '%{http_code}' "$url")
    [[ $code =~ ^($want)$ ]] && { dot_progress_end; return 0; }
    [ "$SECONDS" -lt "$end" ] || { dot_progress_end; return 1; }
    dot_progress 0 0 "waiting for ${url%%/*}//${url#*//}"
    sleep 1
  done
}

# prints the user who called the installer: ourselves, or the user behind "sudo installer.sh" (root when none)
dot_user() { if [ "$(id -u)" -eq 0 ]; then echo "${SUDO_USER:-root}"; else id -un; fi; }

# prints the home directory of a user, default dot_user: home=$(dot_user_home "$user")
dot_user_home() { getent passwd "${1:-$(dot_user)}" | cut -d: -f6; }

# true when the package is installed, asked from the package manager of this system: dot_pkg_installed influxdb2
dot_pkg_installed() {
  case $DOT_PKG in
    apt)            dpkg-query -W -f '${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
    dnf|yum|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman)         pacman -Q "$1" >/dev/null 2>&1 ;;
    apk)            apk info -e "$1" >/dev/null 2>&1 ;;
    *)              return 1 ;;
  esac
}

# prints the installed version of the package (rpm: without the release), nothing when it is not installed:
# dot_pkg_version grafana
dot_pkg_version() {
  case $DOT_PKG in
    apt)            dpkg-query -W -f '${Version}' "$1" 2>/dev/null ;;
    dnf|yum|zypper) dot_pkg_installed "$1" && rpm -q --qf '%{VERSION}' "$1" ;;
    pacman)         pacman -Q "$1" 2>/dev/null | cut -d' ' -f2 ;;
  esac
}

# true when node is at least version $1 (22, 22.9; 0: any) and npm is there
_dot_node_ok() {
  local have
  have=$(node -v 2>/dev/null) && command -v npm >/dev/null 2>&1 || return 1
  [ "$(printf '%s\n%s\n' "$1" "${have#v}" | sort -V | head -n 1)" = "$1" ]
}

# Makes sure Node.js with npm is installed, at least the version given (22 or 22.9; none: any): runs nodejs.sh
# (next to the calling installer, current LTS) otherwise and dies when node is still too old. dot_node_min [version]
dot_node_min() {
  local need=${1:-0} dir
  _dot_node_ok "$need" && return 0
  dir=$(dirname "$(readlink -f "$0")")
  [ -f "$dir/nodejs.sh" ] || dot_die "Node.js${1:+ $1 or newer} is needed and there is no nodejs.sh next to this installer"
  dot_info "Node.js${1:+ $1 or newer} is needed, running nodejs.sh"
  bash "$dir/nodejs.sh" </dev/null || dot_die "nodejs.sh failed"
  hash -r
  _dot_node_ok "$need" || dot_die "Node.js${1:+ $1 or newer} with npm is needed, found: $(node -v 2>/dev/null || echo none)"
}

# installs the PHP command line unless php is there; on Debian the package "php" would pull in Apache
dot_php_cli() {
  command -v php >/dev/null 2>&1 && return
  case $DOT_PKG in pacman) dot_pkg_install php ;; *) dot_pkg_install php-cli ;; esac || dot_die "installing PHP failed"
}

# Installs the latest uv release into ${UV_DIR:-~/.local/bin}, checked against its published sha256; the static musl
# build runs on every glibc, also the old one of Ubuntu 20.04. dot_uv_install
dot_uv_install() {
  local triple tag url dest=${UV_DIR:-$HOME/.local/bin}
  case $DOT_ARCH in
    amd64) triple=x86_64-unknown-linux-musl ;;
    arm64) triple=aarch64-unknown-linux-musl ;;
    armv7) triple=armv7-unknown-linux-musleabihf ;;
    armv6) triple=arm-unknown-linux-musleabihf ;;
    *) dot_die "uv has no build for architecture $DOT_ARCH" ;;
  esac
  dot_need curl tar
  tag=$(dot_github_latest astral-sh/uv)
  [ -n "$tag" ] || dot_die "cannot find the latest uv release on GitHub (no network?)"
  url="https://github.com/astral-sh/uv/releases/download/$tag/uv-$triple.tar.gz"
  # global: the EXIT trap runs after this function has returned
  _dot_uv_tmp=$(mktemp -d) && trap 'rm -rf "$_dot_uv_tmp"' EXIT
  dot_info "Downloading uv $tag ($triple)"
  curl -fsSL -o "$_dot_uv_tmp/uv.tar.gz" "$url" && curl -fsSL -o "$_dot_uv_tmp/uv.sha256" "$url.sha256" ||
    dot_die "download of $url failed"
  echo "$(cut -d' ' -f1 "$_dot_uv_tmp/uv.sha256")  $_dot_uv_tmp/uv.tar.gz" | sha256sum -c --quiet ||
    dot_die "checksum of uv-$triple.tar.gz does not match, aborting"
  tar -xzf "$_dot_uv_tmp/uv.tar.gz" -C "$_dot_uv_tmp" && mkdir -p "$dest" &&
    install -m 755 "$_dot_uv_tmp/uv-$triple/uv" "$_dot_uv_tmp/uv-$triple/uvx" "$dest/" || dot_die "could not install uv into $dest"
}

# writes stdin to the file unless it exists (examples belong to the user after the first run): … | dot_put_new <file>
dot_put_new() {
  if dot_sudo test -e "$1"; then cat >/dev/null; dot_info "keeping $1"; else dot_sudo tee "$1" >/dev/null && dot_info "wrote $1"; fi
}

# Downloads <project>-<version>.linux-<arch>.tar.gz of release <tag> of github.com/prometheus/<project> into <dir>,
# checks it against the release's sha256sums.txt and unpacks it there: dot_prometheus_release node_exporter v1.12.1 "$tmp"
dot_prometheus_release() {
  local f=$1-${2#v}.linux-$DOT_ARCH.tar.gz url=https://github.com/prometheus/$1/releases/download/$2 d=$3
  dot_info "Downloading $f"
  curl -fsSL -o "$d/$f" "$url/$f" && curl -fsSL -o "$d/sha256sums.txt" "$url/sha256sums.txt" ||
    dot_die "download of $f failed"
  (cd "$d" && awk -v f="$f" '$2 == f' sha256sums.txt | sha256sum -c --quiet) || dot_die "checksum of $f does not match"
  tar -xzf "$d/$f" -C "$d" || dot_die "could not unpack $f"
}
