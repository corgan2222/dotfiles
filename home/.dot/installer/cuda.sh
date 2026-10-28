#!/bin/bash
# installer: NVIDIA CUDA toolkit from NVIDIA's apt or rpm repository
# systems: debian fedora rhel amd64 arm64
# Adds NVIDIA's CUDA repository for this distro (apt: cuda-keyring package, dnf: cuda-<distro>.repo) and installs the
# CUDA toolkit. Derivatives take the repository of the Ubuntu or Debian release they are built on (Linux Mint, Pop!_OS,
# Raspberry Pi OS); Kali is rolling and has no matching repository, it gets a hint to its own package.
# apt: cuda-keyring comes from the repository itself, signed with a key whose fingerprint is listed below (NVIDIA
# signs newer releases with a key of their own: a new release fails here until its key is added after a check);
# dnf: the key of the .repo the same way, stored as /etc/pki/rpm-gpg/RPM-GPG-KEY-cuda.
# Does not install the GPU driver, it prints the command for that.
#   cuda.sh                  latest toolkit
#   cuda.sh 12               latest toolkit of CUDA 12
#   cuda.sh --cudnn          also cuDNN for that CUDA version
#   cuda.sh --dry-run        add the repository, only simulate the package install
# category: dev
# check: /usr/local/cuda
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

major= cudnn= dry=
for a in "$@"; do
  case $a in
    --cudnn) cudnn=1 ;;
    --dry-run) dry=1 ;;
    [0-9]|[0-9][0-9]) major=$a ;;
    *) dot_die "unknown argument '$a', usage: cuda.sh [major version] [--cudnn] [--dry-run]" ;;
  esac
done

case $DOT_OS_BASE in
  ubuntu)
    # Linux Mint counts its own versions, the Ubuntu release is in upstream-release; Pop!_OS uses Ubuntu's numbers
    v=$(sed -n 's/^DISTRIB_RELEASE=//p' /etc/upstream-release/lsb-release 2>/dev/null)
    v=${v:-$DOT_OS_VERSION} distro=ubuntu${v//./} ;;
  debian)
    # Debian, Proxmox, Raspberry Pi OS and LMDE name the Debian release in /etc/debian_version, Kali "kali-rolling"
    v=$(cut -d. -f1 /etc/debian_version 2>/dev/null)
    case $v in
      [0-9]*) distro=debian$v ;;
      *) dot_die "NVIDIA builds CUDA repositories for Debian releases, $DOT_OS is '$v':" \
           "use its own package: sudo apt-get install nvidia-cuda-toolkit" ;;
    esac ;;
  fedora) distro=fedora$DOT_OS_VERSION ;;
  # NVIDIA's rhel<major> repository also serves Rocky and AlmaLinux
  rhel) distro=rhel${DOT_OS_VERSION%%.*} ;;
  *) dot_die "NVIDIA has no CUDA repository for '$DOT_OS', see https://developer.nvidia.com/cuda-downloads" ;;
esac
case $DOT_ARCH in
  amd64) narch=x86_64 ;;
  arm64) narch=sbsa ;;
  *) dot_die "NVIDIA has no CUDA packages for $DOT_ARCH" ;;
esac
repo=https://developer.download.nvidia.com/compute/cuda/repos/$distro/$narch

if [ "$DOT_PKG" = dnf ]; then
  dot_need curl
  gpgkey=$(curl -fsS "$repo/cuda-$distro.repo" 2>/dev/null | sed -n 's/^gpgkey=//p' | head -n 1)
  [ -n "$gpgkey" ] ||
    dot_die "NVIDIA has no CUDA repository for $distro/$narch ($repo), see https://developer.nvidia.com/cuda-downloads"
  # NVIDIA's rpm keys (checked 28.10.26): D42D0685 RHEL 8, 9 and Fedora up to 42, CDF6BA43 RHEL 10, 1940C73E Fedora
  # 43, 73CD9B30 Fedora 44. dnf -y imports the key of gpgkey= without a question, so only one of these counts
  # (28.10.26, review). A new one: compare it with the key in NVIDIA's install guide, then add it here.
  k=$(dot_rpm_key cuda "$gpgkey" 610C7B14E068A878070DA4E99CD0A493D42D0685 327FC5D76A76DC2099AEF71F7ABC4241CDF6BA43 \
    8033132AA30E535FF7F6059764E003B61940C73E 129994480EC63D2789BC98E490DFED2F73CD9B30) || exit 1
  dot_rpm_repo cuda "$repo/cuda-$distro.repo" "$k"
  pkgs=(cuda-toolkit${major:+-$major})
  if [ -n "$cudnn" ]; then
    if [ -n "$major" ]; then
      c=$(dnf -q repoquery --qf '%{name}\n' "cudnn*-cuda-$major" 2>/dev/null | grep -E "^cudnn[0-9]+-cuda-$major\$" | sort -uV | tail -n 1)
      [ -n "$c" ] || dot_die "no cuDNN package for CUDA $major in $repo"
      pkgs+=("$c")
    else
      pkgs+=(cudnn)
    fi
  fi
  # not every release repository has cuDNN (fedora44 has none)
  for p in "${pkgs[@]}"; do
    dnf -q repoquery "$p" 2>/dev/null | grep -q . || dot_die "$p is not in $repo"
  done
  if [ -n "$dry" ]; then
    # --assumeno always ends with an error code, the transaction summary is the result
    dot_info "dry run: dnf install --assumeno ${pkgs[*]}"
    out=$(dot_sudo dnf install --assumeno "${pkgs[@]}" 2>&1)
    grep -E '^ *(cuda-toolkit|cudnn|cuda-nvcc)' <<<"$out"
    grep -iE '^ *install(ing)?:? +[0-9]+ packages?' <<<"$out" || { echo "$out" >&2; dot_die "the simulated install of ${pkgs[*]} failed"; }
    exit 0
  fi
  dot_info "Installing ${pkgs[*]} (several GB)"
  dot_pkg_install "${pkgs[@]}" || dot_die "installing ${pkgs[*]} failed"
  /usr/local/cuda/bin/nvcc --version | tail -n 1
  dot_info "nvcc lives in /usr/local/cuda/bin, add it to PATH to use it"
  command -v nvidia-smi >/dev/null ||
    dot_info "No NVIDIA driver found. Install it with: sudo dnf install -y nvidia-open   (or cuda-drivers for the proprietary modules), then reboot"
  exit 0
fi

# NVIDIA's repository keys (checked 28.10.26): 3bf863cc Ubuntu 20.04 to 24.04 and Debian 12, 8793F200 Debian 13,
# 60DF8A40 Ubuntu 26.04. A new one: compare it with the key in NVIDIA's install guide, then add it here.
fprs=(EB693B3035CD5710E231E123A4B469963BF863CC 02182E60104FCDC26EAE1B8597A5D4CB8793F200
  14BAFBC7562AD710CA04E69905FBB6DA60DF8A40)
if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
  dot_need curl gpg
  keys=$(curl -fsSL "$repo/" 2>/dev/null | grep -oE "[0-9A-Fa-f]{8}\.pub" | sort -u)
  [ -n "$keys" ] ||
    dot_die "NVIDIA has no CUDA repository for $distro/$narch ($repo), see https://developer.nvidia.com/cuda-downloads"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  # the first key file of the repository with a listed key, cut down to that key: apt trusts every key in the file
  # (older repositories also offer the retired 7fa2af80; a file may hold old and new key at a key change)
  ok=
  for k in $keys; do
    curl -fsSL -o "$tmp/nvidia.asc" "$repo/$k" || continue
    dot_key_only "$tmp/nvidia.asc" "${fprs[@]}" >/dev/null && ok=1 && break
  done
  [ -n "$ok" ] || dot_die "no key in $repo ($(echo $keys)) has a fingerprint listed in $0, not trusting them"
  # the repository once with that key, only to install NVIDIA's cuda-keyring from it (apt checks the signature); the
  # package then keeps key and source list, also when NVIDIA changes its key. Our source goes again: the same
  # repository with two Signed-By breaks apt.
  dot_apt_repo cuda-bootstrap "file://$tmp/nvidia.asc" "$repo/" / ""
  dot_pkg_install cuda-keyring; rc=$?
  dot_sudo rm -f /etc/apt/sources.list.d/cuda-bootstrap.sources /etc/apt/keyrings/cuda-bootstrap.asc
  [ $rc = 0 ] || { dot_apt_update; dot_die "installing cuda-keyring from $repo failed"; }
fi
dot_apt_update || dot_die "apt-get update failed after adding the CUDA repository"

pkgs=(cuda-toolkit${major:+-$major})
if [ -n "$cudnn" ]; then
  if [ -n "$major" ]; then
    # newest cuDNN generation built for this CUDA major, e.g. cudnn9-cuda-12
    c=$(apt-cache pkgnames cudnn | grep -E "^cudnn[0-9]+-cuda-$major\$" | sort -V | tail -n 1)
    [ -n "$c" ] || dot_die "no cuDNN package for CUDA $major in $repo"
    pkgs+=("$c")
  else
    pkgs+=(cudnn)
  fi
fi
apt-cache show "${pkgs[0]}" >/dev/null 2>&1 || dot_die "${pkgs[0]} is not in $repo"

if [ -n "$dry" ]; then
  dot_info "dry run: apt-get install -s ${pkgs[*]}"
  out=$(apt-get install -s "${pkgs[@]}") || dot_die "the simulated install of ${pkgs[*]} failed"
  grep -E '^Inst (cuda-toolkit|cudnn|cuda-nvcc)' <<<"$out"
  dot_info "$(grep -c '^Inst' <<<"$out") packages would be installed"
  exit 0
fi
dot_info "Installing ${pkgs[*]} (several GB)"
dot_pkg_install "${pkgs[@]}" || dot_die "installing ${pkgs[*]} failed"
/usr/local/cuda/bin/nvcc --version | tail -n 1
dot_info "nvcc lives in /usr/local/cuda/bin, add it to PATH to use it"
command -v nvidia-smi >/dev/null ||
  dot_info "No NVIDIA driver found. Install it with: sudo apt-get install -y nvidia-open   (or cuda-drivers for the proprietary modules), then reboot"
