#!/bin/bash
# Proxmox VE login MOTD — two-column layout

C_RST=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_GREEN=$'\e[32m'
C_RED=$'\e[31m'
C_YELLOW=$'\e[33m'
C_CYAN=$'\e[36m'

# the visible text: $1 without ANSI escapes
# (in bash, without sed and wc: the table calls it twice per line)
_plain() {
    local s=$1 out= pre
    while [[ $s == *$'\e['* ]]; do
        pre=${s%%$'\e['*}; out+=$pre; s=${s#*$'\e['}
        s=${s#"${s%%[a-zA-Z]*}"}; s=${s#?}
    done
    printf '%s' "$out$s"
}

# pad $1 to visible width $2; a longer value (host name, kernel, uptime) is cut to the width and loses its colours,
# else it pushed the frame of its line to the right (28.10.26)
_pad() {
    local s=$1 n=$2 p LC_ALL=C.UTF-8
    p=$(_plain "$s")
    [ ${#p} -gt "$n" ] && s="${p:0:n-1}…" p=$s
    printf '%s%*s' "$s" $(( n - ${#p} )) ''
}

# print N box-drawing horizontal bars
_hline() { local i; for ((i=0; i<$1; i++)); do printf '─'; done; }

# ── header ─────────────────────────────────────────────────────────────────
if command -v figlet >/dev/null 2>&1; then
    if command -v lolcat >/dev/null 2>&1; then
        figlet -k -f slant "$(hostname)" | lolcat
    else
        printf '%s' "${C_CYAN}"
        figlet -k -f slant "$(hostname)"
        printf '%s' "${C_RST}"
    fi
fi

# ── left column: system info ───────────────────────────────────────────────
L=()
L+=( "${C_BOLD}${C_YELLOW} SYSTEM${C_RST}" )
L+=( "  Host    : ${C_CYAN}$(hostname -f 2>/dev/null || hostname)${C_RST}" )

if command -v pveversion >/dev/null 2>&1; then
    # dpkg-query answers in 0.01 s, pveversion (perl) in 0.8 s (27.10.26)
    _pve=pve-manager/$(dpkg-query -W -f '${Version}' pve-manager 2>/dev/null)
    L+=( "  PVE     : ${C_GREEN}${_pve}${C_RST}" )
fi

L+=( "  Kernel  : $(uname -r)" )
_uptime=$(uptime -p 2>/dev/null \
    | sed -e 's/ weeks\?/w/g' -e 's/ days\?/d/g' \
          -e 's/ hours\?/h/g' -e 's/ minutes\?/m/g' \
          -e 's/, / /g')
L+=( "  Uptime  : ${_uptime:-$(uptime)}" )
L+=( "  Load    : $(awk '{ print $1, $2, $3 }' /proc/loadavg)" )

if [ -r /etc/pve/.members ]; then
    # the cluster file system keeps the state in .members ("quorate": 1); pvecm status needs 0.3 s for it
    _q=$(grep -o '"quorate": *[01]' /etc/pve/.members | grep -o '[01]$')
    case $_q in 1) _q=Yes ;; 0) _q=No ;; esac
    if [ -n "$_q" ]; then
        _qc=$C_GREEN; [ "$_q" != "Yes" ] && _qc=$C_RED
        L+=( "  Quorum  : ${_qc}${_q}${C_RST}" )
    fi
fi

L+=( "" )
L+=( "${C_BOLD}${C_YELLOW} MEMORY${C_RST}" )
L+=( "  RAM     : $(command free -h | awk '/^Mem:/  { printf "%s / %s", $3, $2 }')" )
L+=( "  Swap    : $(command free -h | awk '/^Swap:/ { printf "%s / %s", $3, $2 }')" )

L+=( "" )
L+=( "${C_BOLD}${C_YELLOW} STORAGE${C_RST}" )
L+=( "  /       : $(command df -h / | awk 'NR==2 { print $3 " / " $2 " (" $5 ")" }')" )

if command df -h /var/lib/vz >/dev/null 2>&1; then
    L+=( "  /vz     : $(command df -h /var/lib/vz | awk 'NR==2 { print $3 " / " $2 " (" $5 ")" }')" )
fi

# ── right column: network, services, help ─────────────────────────────────
R=()

# IPs
R+=( "${C_BOLD}${C_YELLOW} NETWORK${C_RST}" )
# every interface, whatever it is called (lib/net.sh); container and VM bridges count in one line, so many guests
# cannot stretch the table
. "${BASH_SOURCE[0]%/*}/../lib/net.sh"
_any_ip=0
while read -r _iface _ip; do
    if [ "$_iface" = + ]; then R+=( "  ${C_DIM}+ ${_ip}${C_RST}" )
    else R+=( "  ${C_CYAN}$(printf '%-8s' "${_iface:0:8}")${C_RST} ${_ip}" ); fi
    _any_ip=1
done < <(dot_ips 5)
[ $_any_ip -eq 0 ] && R+=( "  (none)" )

# get IP of a running LXC container
# lxc-info reads the address from the running container, much faster than pct exec
_lxc_ip() {
    # skip loopback, IPv6 and the gateway address .0.1 that Docker gives its bridges in 172.16/12 inside the container
    lxc-info -n "$1" -iH 2>/dev/null | grep -v -e '^127\.' -e ':' -e '^172\.\(1[6-9]\|2[0-9]\|3[01]\)\.0\.1$' | head -n 1
}

# get listening ports of a running LXC container (excludes 22/53/loopback)
_lxc_ports() {
    timeout 3 pct exec "$1" -- ss -tlnH 2>/dev/null \
        | awk '{
            split($4, a, ":");
            p = a[length(a)]+0;
            if (p > 0 && p != 22 && p != 53 && !seen[p]++) printf "%d ", p
          }' \
        | tr ' ' '\n' | sort -n | tr '\n' ' ' | sed 's/ $//'
}

# get IP of a running KVM VM via QEMU guest agent
_kvm_ip() {
    pvesh get "/nodes/$(hostname)/qemu/$1/agent/network-get-interfaces" \
        --output-format json 2>/dev/null \
        | python3 -c "
import sys,json
try:
    for i in json.load(sys.stdin).get('result',[]):
        for a in i.get('ip-addresses',[]):
            if a.get('ip-address-type')=='ipv4' and not a['ip-address'].startswith('127.'):
                print(a['ip-address']); sys.exit()
except: pass
" 2>/dev/null
}

# scan common app ports on a KVM VM IP (requires nmap; skips 22/53)
_NMAP_PORTS="80,443,1883,3000,3306,4443,5000,5432,6379,8080,8081,8086,\
8096,8123,8443,8888,8920,9000,9090,9117,9999,27017,32400"
_kvm_ports() {
    [ -z "$1" ] && return
    command -v nmap >/dev/null 2>&1 || return
    nmap -p "$_NMAP_PORTS" --open -T4 -q --host-timeout 4s "$1" 2>/dev/null \
        | awk '/^[0-9]+\/tcp.*open/ { split($1,a,"/"); printf "%s ", a[1] }' \
        | sed 's/ $//'
}

# containers & VMs: asking every guest (pct exec, guest agent, nmap) takes seconds, so the lines come from a cache
# that a background job renews when it is older than 5 minutes; a login never waits for it
_gl() { printf '%s\n' "$1"; }
_guest_lines() {

    _any_guest=0
    if command -v pct >/dev/null 2>&1; then
        while read -r _id _st _name; do
            _sc=$C_GREEN; [ "$_st" != "running" ] && _sc=$C_RED
            if [ "$_st" = "running" ]; then
                _gip=$(_lxc_ip "$_id")
                _gports=$(_lxc_ports "$_id")
            else
                _gip=""; _gports=""
            fi
            _gl "  ${C_DIM}LXC${C_RST}[${_id}] $(printf '%-13s' "${_name:0:13}") ${C_CYAN}$(printf '%-15s' "${_gip:--}")${C_RST} ${_sc}${_st}${C_RST}"
            [ ${#_gports} -gt 44 ] && _gports="${_gports:0:42} …"
            [ -n "$_gports" ] && _gl "  ${C_DIM}↳${C_RST} ${C_CYAN}${_gports}${C_RST}"
            _any_guest=1
        done < <(pct list 2>/dev/null | awk 'NR>1 { print $1, $2, $NF }')
    fi

    if command -v qm >/dev/null 2>&1; then
        while read -r _id _name _st; do
            _sc=$C_GREEN; [ "$_st" != "running" ] && _sc=$C_RED
            if [ "$_st" = "running" ]; then
                _gip=$(_kvm_ip "$_id")
                _gports=$(_kvm_ports "$_gip")
            else
                _gip=""; _gports=""
            fi
            _gl "  ${C_DIM}KVM${C_RST}[${_id}] $(printf '%-13s' "${_name:0:13}") ${C_CYAN}$(printf '%-15s' "${_gip:--}")${C_RST} ${_sc}${_st}${C_RST}"
            [ ${#_gports} -gt 44 ] && _gports="${_gports:0:42} …"
            [ -n "$_gports" ] && _gl "  ${C_DIM}↳${C_RST} ${C_CYAN}${_gports}${C_RST}"
            _any_guest=1
        done < <(qm list 2>/dev/null | awk 'NR>1 { print $1, $2, $3 }')
    fi

    [ $_any_guest -eq 0 ] && _gl "  (none)"
    return 0
}
if command -v pct >/dev/null 2>&1 || command -v qm >/dev/null 2>&1; then
    R+=( "" )
    R+=( "${C_BOLD}${C_YELLOW} CONTAINERS & VMs${C_RST}" )
    _cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/motd-guests
    mkdir -p "${_cache%/*}"
    if [ -z "$(find "$_cache" -mmin -5 2>/dev/null)" ]; then
        # double fork: no job notice in the login shell; exec 255>&-: the job must not hold the stderr of the login
        # shell, which bash keeps on fd 255 (else "bash -lic cmd 2>&1 | ..." waits for the job, 28.10.26)
        ( ( exec 255>&-; _guest_lines > "$_cache.$$" 2>/dev/null && mv -f "$_cache.$$" "$_cache" ) \
            </dev/null >/dev/null 2>&1 & )
    fi
    if [ -s "$_cache" ]; then
        while IFS= read -r _line; do R+=( "$_line" ); done < "$_cache"
    else
        R+=( "  ${C_DIM}(collecting, shown at the next login)${C_RST}" )
    fi
fi

# quick help
R+=( "" )
R+=( "${C_BOLD}${C_YELLOW} QUICK HELP${C_RST}" )
R+=( "  ${C_GREEN}ctl${C_RST}       list LXC containers" )
R+=( "  ${C_GREEN}vml${C_RST}       list KVM VMs" )
R+=( "  ${C_GREEN}pveps${C_RST}     all CTs + VMs at a glance" )
R+=( "  ${C_GREEN}pvever${C_RST}    PVE version verbose" )
R+=( "  ${C_GREEN}pvestat${C_RST}   cluster status" )
R+=( "  ${C_GREEN}ctsnap${C_RST} N  snapshot CT by ID" )
R+=( "  ${C_GREEN}h${C_RST}         search aliases + functions" )

# ── render two-column table ────────────────────────────────────────────────
LW=40   # visible content width — left
RW=48   # visible content width — right

_ROWS=$(( ${#L[@]} > ${#R[@]} ? ${#L[@]} : ${#R[@]} ))

# top border
printf "${C_DIM}┌$(_hline $((LW+2)))┬$(_hline $((RW+2)))┐${C_RST}\n"

for (( _i=0; _i<_ROWS; _i++ )); do
    _lc="${L[$_i]-}"
    _rc="${R[$_i]-}"
    # the content goes in as an argument, not into the format: a "%" from df would end the line there
    printf '%s\n' "${C_DIM}│${C_RST} $(_pad "$_lc" $LW) ${C_DIM}│${C_RST} $(_pad "$_rc" $RW) ${C_DIM}│${C_RST}"
done

# bottom border
printf "${C_DIM}└$(_hline $((LW+2)))┴$(_hline $((RW+2)))┘${C_RST}\n"
