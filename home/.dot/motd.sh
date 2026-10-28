#!/bin/bash
# Login screen (MOTD) for every Linux without one of its own (Ubuntu, Debian, Fedora, Arch, ...): system, uptime,
# load, memory, disk and IP addresses. Reads /proc where it can, so a login stays fast. .bashrc sources it through
# _loadMotd; off with DOT_MOTD=0 (setup.sh --motd).

_m_b=$'\e[1m' _m_c=$'\e[36m' _m_g=$'\e[32m' _m_y=$'\e[33m' _m_r=$'\e[31m' _m_d=$'\e[90m' _m_0=$'\e[0m'

# percentage in green, yellow from 70, red from 90
_m_pct() { local c=$_m_g; [ "$1" -ge 70 ] && c=$_m_y; [ "$1" -ge 90 ] && c=$_m_r; printf '%s%d%%%s' "$c" "$1" "$_m_0"; }
# kB to a short size: 1.5G, 512M
_m_size() { awk -v k="$1" 'BEGIN { if (k >= 1048576) printf "%.1fG", k / 1048576; else printf "%dM", k / 1024 }'; }

echo
if command -v figlet >/dev/null 2>&1; then
  printf '%s' "$_m_c"; figlet -k -f slant "${HOSTNAME%%.*}" 2>/dev/null || figlet "${HOSTNAME%%.*}"; printf '%s' "$_m_0"
else
  printf '  %s%s%s\n\n' "$_m_b$_m_c" "${HOSTNAME%%.*}" "$_m_0"
fi

# system and kernel
_m_os=
[ -r /etc/os-release ] && _m_os=$(. /etc/os-release; echo "${PRETTY_NAME:-$NAME}")
read -r _m_k </proc/sys/kernel/osrelease 2>/dev/null
printf '  %-10s %s %s(%s)%s\n' "System" "${_m_os:-$(uname -s)}" "$_m_d" "${_m_k:-$(uname -r)}" "$_m_0"

# uptime and load against the number of cores
read -r _m_up _ </proc/uptime
_m_up=${_m_up%.*}
# counted by shootProfile (core.sh) already
_m_cores=; [ "${CPU_CORES:-0}" -gt 0 ] && _m_cores=$CPU_CORES
read -r _m_l1 _m_l5 _m_l15 _ </proc/loadavg
printf '  %-10s %dd %dh %dm   %sload%s %s %s %s %s(%s cores)%s\n' "Uptime" $((_m_up / 86400)) $((_m_up / 3600 % 24)) \
  $((_m_up / 60 % 60)) "$_m_d" "$_m_0" "$_m_l1" "$_m_l5" "$_m_l15" "$_m_d" "${_m_cores:-?}" "$_m_0"

# memory from /proc/meminfo: used = total - available
while read -r _m_key _m_val _; do
  case $_m_key in
    MemTotal:) _m_mt=$_m_val ;; MemAvailable:) _m_ma=$_m_val ;;
    SwapTotal:) _m_st=$_m_val ;; SwapFree:) _m_sf=$_m_val ;;
  esac
done </proc/meminfo
if [ -n "${_m_mt:-}" ] && [ -n "${_m_ma:-}" ]; then
  _m_mu=$((_m_mt - _m_ma))
  printf '  %-10s %s / %s %s' "Memory" "$(_m_size $_m_mu)" "$(_m_size $_m_mt)" "$(_m_pct $((_m_mu * 100 / _m_mt)))"
  [ "${_m_st:-0}" -gt 0 ] && printf '   %sswap%s %s / %s' "$_m_d" "$_m_0" "$(_m_size $((_m_st - _m_sf)))" "$(_m_size $_m_st)"
  echo
fi

# disk of /
read -r _ _m_dt _m_du _ _m_dp _ < <(command df -Pk / 2>/dev/null | tail -n 1)
[ -n "${_m_dt:-}" ] && printf '  %-10s %s / %s %s\n' "Disk /" "$(_m_size "$_m_du")" "$(_m_size "$_m_dt")" "$(_m_pct "${_m_dp%\%}")"

# addresses, whatever the interfaces are called; container networks add up to one entry (lib/net.sh)
. "$HOME/.dot/lib/net.sh"
_m_ips=$(dot_ips 3 | awk -v c="$_m_g" -v r="$_m_0" '{ printf "%s", (n++ ? "   " : "") }
  $1 == "+" { printf "%s", $0; next } { printf "%s %s%s%s", $1, c, $2, r }')
printf '  %-10s %s\n' "IP" "${_m_ips:--}"

# running containers, only when the socket answers without sudo
if [ -S /var/run/docker.sock ] && [ -r /var/run/docker.sock ] && [ -w /var/run/docker.sock ] && command -v docker >/dev/null 2>&1; then
  _m_dc=$(timeout 2 docker ps -q 2>/dev/null | wc -l)
  printf '  %-10s %s running\n' "Docker" "$_m_dc"
fi
echo

unset -f _m_pct _m_size
unset _m_b _m_c _m_g _m_y _m_r _m_d _m_0 _m_os _m_k _m_up _m_cores _m_l1 _m_l5 _m_l15 _m_key _m_val _m_mt _m_ma _m_st \
  _m_sf _m_mu _m_dt _m_du _m_dp _m_ips _m_dc
