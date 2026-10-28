#!/bin/bash
# installer: CLI basics: lnav, ncdu, jq, yq, ripgrep, git, curl, htop, btop, bat, eza, tmux, nmap, 7zip, rar, lazygit and more
# systems: all
#
# Installs the basic command line tools with the package manager of this system (apt, pacman, apk, opkg, dnf, zypper;
# on Rocky and AlmaLinux with EPEL).
# Every package is checked first; a tool without a package here but with its own installer next to this file
# (eza.sh, btop.sh, bat.sh, duf.sh, gping.sh, lazydocker.sh, glow.sh, lazygit.sh, lsd.sh, delta.sh, rustnet.sh) is
# installed by that installer, anything else this system does not offer is skipped. nvtop only where a GPU is usable (not in containers or VMs without one).
# Safe to run again: present packages are left alone. No system upgrade, except on Arch: there dot_pkg_install syncs
# and upgrades (pacman -Syu) unless that happened in the last hour, a sync alone would be a partial upgrade.
#
#   basics.sh
# category: base
# check: git curl jq rsync tmux
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dir=$(dirname "$(readlink -f "$0")")

# tool, then the package per manager: apt pacman apk opkg dnf (Fedora and the RHEL family; rar: bsdtar, unrar is only
# in RPM Fusion) zypper (openSUSE).  a|b = first one present or available, - = none
# yq: the Python one (a jq wrapper with xq for XML -> JSON, named xq-python on Debian) where there is one; Fedora and
# openSUSE package only the Go yq of mikefarah: XML -> JSON there is "yq -p xml -o json" (28.10.26)
TOOLS='
git              git                    git          git          git         git                          git
curl             curl                   curl         curl         curl        curl|curl-minimal            curl
awk              mawk|gawk              gawk         busybox|gawk gawk        gawk                         gawk
wget             wget                   wget         wget         wget-ssl|wget wget2-wget|wget              wget
ca-certificates  ca-certificates        ca-certificates ca-certificates ca-certificates ca-certificates              ca-certificates
gnupg            gnupg                  gnupg        gnupg        gnupg       gnupg2                       gpg2
zip              zip                    zip          zip          zip         zip                          zip
unzip            unzip                  unzip        unzip        unzip       unzip                        unzip
7zip             7zip|p7zip-full        7zip|p7zip   7zip|p7zip   p7zip       7zip|p7zip                   7zip|p7zip-full
zstd             zstd                   zstd         zstd         zstd        zstd                         zstd
rar              unrar|unrar-free       unrar        unrar|libarchive-tools unrar bsdtar                       unrar|bsdtar
lnav             lnav                   lnav         lnav         -           lnav                         lnav
htop             htop                   htop         htop         htop        htop                         htop
btop             btop                   btop         btop         -           btop                         btop
procps           procps                 procps-ng    procps       procps-ng   procps-ng                    procps
psmisc           psmisc                 psmisc       psmisc       psmisc      psmisc                       psmisc
tree             tree                   tree         tree         tree        tree                         tree
jq               jq                     jq           jq           jq          jq                           jq
yq               yq                     yq           yq-python    -           yq                           yq
jo               jo                     jo           jo           -           jo                           jo
bat              bat                    bat          bat          -           bat                          bat
eza              eza                    eza          eza          -           eza                          eza
ncdu             ncdu                   ncdu         ncdu         ncdu        ncdu                         ncdu
mtr              mtr-tiny               mtr          mtr          mtr         mtr                          mtr
ping             iputils-ping           iputils      iputils-ping|iputils -   iputils                      iputils
pv               pv                     pv           pv           pv          pv                           pv
figlet           figlet                 figlet       figlet       -           figlet                       figlet
joe              joe                    joe          joe          joe         joe                          joe
nano             nano                   nano         nano         nano        nano                         nano
rsync            rsync                  rsync        rsync        rsync       rsync                        rsync
tmux             tmux                   tmux         tmux         tmux        tmux                         tmux
lsof             lsof                   lsof         lsof         lsof        lsof                         lsof
dnsutils         bind9-dnsutils|dnsutils bind        bind-tools   bind-dig    bind-utils                   bind-utils
net-tools        net-tools              net-tools    net-tools    net-tools   net-tools                    net-tools
iproute2         iproute2               iproute2     iproute2     ip-full     iproute                      iproute2
bash-completion  bash-completion        bash-completion bash-completion bash-completion bash-completion              bash-completion
less             less                   less         less         less        less                         less
file             file                   file         file         file        file                         file
man              man-db                 man-db       mandoc|man-db -          man-db                       man
ripgrep          ripgrep                ripgrep      ripgrep      -           ripgrep                      ripgrep
duf              duf                    duf          duf          -           duf                          duf
gping            gping                  gping        gping        -           gping                        gping
lazydocker       -                      lazydocker   lazydocker   -           -                            -
glow             glow                   glow         -            -           glow                         glow
lazygit          lazygit                lazygit      lazygit      -           -                            lazygit
lsd              -                      lsd          lsd          -           lsd                          lsd
delta            -                      git-delta    delta        -           git-delta                    git-delta
script           bsdutils               util-linux   util-linux-misc -        util-linux-script|util-linux util-linux
powertop         powertop               powertop     powertop     -           powertop                     powertop
nmap             nmap                   nmap         nmap         nmap        nmap                         nmap
rustnet          -                      -            -            -           -                            -
nvtop            nvtop                  nvtop        nvtop        -           nvtop                        nvtop
'
# rustnet always goes through rustnet.sh: it uses the package where there is one and grants the capture capabilities;
# lsd and delta go through their installers on apt: they take the package only from a minimum version on (Debian 12
# ships lsd 0.23.1, Ubuntu 24.04 delta 0.16.5), and Debian's package "delta" is another program;
# ping: container images come without it, and gping needs the iputils one ("Could not detect ping command type")

# refreshes the package index once, so the availability checks see what the mirrors offer today (apt: unless another
# installer did so in the last hour)
pkg_refresh() {
  case $DOT_PKG in
    apt)    dot_apt_refresh ;;
    apk)    dot_sudo apk update -q ;;
    opkg)   dot_sudo opkg update >/dev/null ;;
    # pacman: no -Sy on its own (partial upgrades); only a system without any sync database gets one
    pacman) ls /var/lib/pacman/sync/*.db >/dev/null 2>&1 || dot_sudo pacman -Sy --noconfirm ;;
    # Rocky and AlmaLinux keep htop, ncdu, btop and others in EPEL
    dnf|yum) dot_epel && dot_sudo "$DOT_PKG" -q -y makecache >/dev/null ;;
    zypper) dot_sudo zypper -n -q refresh >/dev/null ;;
  esac
}

# true when the package is installed already
pkg_installed() {
  case $DOT_PKG in
    apt)    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
    apk)    apk info -e "$1" >/dev/null 2>&1 ;;
    opkg)   [ -n "$(opkg list-installed "$1" 2>/dev/null)" ] ;;
    dnf|yum|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
  esac
}

# true when the package manager can install the package
pkg_available() {
  case $DOT_PKG in
    apt)    LC_ALL=C apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]' ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    apk)    [ -n "$(apk search -e "$1" 2>/dev/null)" ] ;;
    opkg)   opkg info "$1" 2>/dev/null | grep -q '^Package:' ;;
    dnf|yum) "$DOT_PKG" -q list --available "$1" >/dev/null 2>&1 ;;
    zypper) zypper -n -q search -x -t package "$1" >/dev/null 2>&1 ;;
  esac
}

# true when a NVIDIA, AMD or Intel GPU is usable here: its device node must exist, because containers see the host's
# /sys without having the card; the virtual GPUs of VMs have other vendor IDs
has_gpu() {
  local c
  [ -e /dev/nvidia0 ] && return 0
  for c in /dev/dri/card*; do
    [ -e "$c" ] && grep -qsxE '0x(10de|1002|8086)' "/sys/class/drm/${c##*/}/device/vendor" && return 0
  done
  return 1
}

# links ~/.local/bin/<name> to <command> when only the distro's renamed binary exists (batcat, 7zz)
link_alias() {
  command -v "$1" >/dev/null 2>&1 && return
  command -v "$2" >/dev/null 2>&1 || return 0
  mkdir -p ~/.local/bin && ln -sf "$(command -v "$2")" ~/.local/bin/"$1"
}

case $DOT_PKG in
  apt) col=1 ;; pacman) col=2 ;; apk) col=3 ;; opkg) col=4 ;; dnf|yum) col=5 ;; zypper) col=6 ;;
  *) dot_die "basics: $DOT_OS has no supported package manager (apt, pacman, apk, Entware opkg, dnf or zypper)" ;;
esac

# progress on a terminal: one line that overwrites itself, so the user sees that something happens without a wall of
# package manager output; elsewhere (logs) plain lines
step() { local s="$*"; [ -t 1 ] && printf '\r\033[K  %s' "${s:0:$((${COLUMNS:-80} - 3))}"; }
step_end() { [ -t 1 ] && printf '\r\033[K'; return 0; }
# the lines of the package managers that name a package being unpacked, installed or set up (apt, pacman, apk, dnf,
# zypper), as step lines; on a terminal only, logs keep the whole output
pkg_progress() {
  if [ -t 1 ]; then
    awk -v w="$((${COLUMNS:-80} - 3))" '/^(Unpacking|Setting up) |[Ii]nstalling|^\( *[0-9]+\/[0-9]+\)|^\[ *[0-9]+\/[0-9]+\]/ {
      printf "\r\033[K  %s", substr($0, 1, w); fflush() } END { printf "\r\033[K" }'
  else
    cat
  fi
}

dot_info "basics: refreshing the $DOT_PKG package index on $DOT_OS $DOT_OS_VERSION"
pkg_refresh || dot_die "could not refresh the $DOT_PKG package index"

todo=() present=() missing=() own=() nogpu=
total=$(grep -c . <<<"$TOOLS") i=0
dot_info "basics: checking $total tools"
while read -r tool cols; do
  [ -n "$tool" ] || continue
  i=$((i + 1)); step "[$i/$total] $tool"
  if [ "$tool" = nvtop ] && ! has_gpu; then nogpu=1; continue; fi
  read -r -a f <<<"$cols"
  IFS='|' read -r -a cands <<<"${f[$((col - 1))]}"
  for p in "${cands[@]}"; do
    [ "$p" != - ] && pkg_installed "$p" && { present+=("$p"); continue 2; }
  done
  for p in "${cands[@]}"; do
    [ "$p" != - ] && pkg_available "$p" && { todo+=("$p"); continue 2; }
  done
  # no package: an installer of the same name next to this file takes over
  if [ -f "$dir/$tool.sh" ]; then
    if command -v "$tool" >/dev/null 2>&1 || [ -x ~/.local/bin/"$tool" ]; then present+=("$tool"); else own+=("$tool"); fi
  else
    missing+=("$tool")
  fi
done <<<"$TOOLS"
step_end

# what comes now, before the long part
[ ${#todo[@]} -eq 0 ] || dot_info "basics: installing ${#todo[@]} packages with $DOT_PKG: ${todo[*]}"
[ ${#own[@]} -eq 0 ] || dot_info "basics: then with their own installers (no $DOT_PKG package here): ${own[*]}"
[ ${#todo[@]} -gt 0 ] || [ ${#own[@]} -gt 0 ] || dot_info "basics: everything is installed already"

# one call for all; should it fail, each package on its own so one bad package cannot block the rest
failed=()
if [ ${#todo[@]} -gt 0 ]; then
  dot_pkg_install "${todo[@]}" | pkg_progress
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    dot_info "basics: installing them together failed, now one by one"
    i=0
    for p in "${todo[@]}"; do
      i=$((i + 1)); step "[$i/${#todo[@]}] $p"
      dot_pkg_install "$p" | pkg_progress; [ "${PIPESTATUS[0]}" -eq 0 ] || failed+=("$p")
    done
    step_end
  fi
fi
installed=()
for p in "${todo[@]}"; do [[ " ${failed[*]} " == *" $p "* ]] || installed+=("$p"); done

# tools without a package, through their own installer (release binary into ~/.local/bin)
i=0
for t in "${own[@]}"; do
  i=$((i + 1))
  dot_info "basics: [$i/${#own[@]}] no $t package on $DOT_OS, running $t.sh"
  if bash "$dir/$t.sh"; then installed+=("$t (via $t.sh)"); else failed+=("$t.sh"); fi
done

link_alias bat batcat
link_alias 7z 7zz

rar=none
for c in unrar unrar-free unar bsdtar; do command -v "$c" >/dev/null 2>&1 && { rar=$c; break; }; done

dot_info "basics: done"
echo "  installed:         ${installed[*]:--}"
echo "  already present:   ${present[*]:--}"
echo "  not available:     ${missing[*]:--}"
[ ${#failed[@]} -eq 0 ] || echo "  failed to install: ${failed[*]}"
echo "  .rar extraction:   $rar"
[ -z "$nogpu" ] || echo "  nvtop:             skipped, no GPU found"
[ ${#failed[@]} -eq 0 ]
