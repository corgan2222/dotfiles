#!/bin/bash
# Proxmox VE login MOTD — two-column layout

C_RST=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_GREEN=$'\e[32m'
C_RED=$'\e[31m'
C_YELLOW=$'\e[33m'
C_CYAN=$'\e[36m'

# visible character length (strips ANSI escapes)
_vlen() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | wc -m; }

# pad $1 to visible width $2
_pad() {
    local s="$1" n="$2" vis pad
    vis=$(_vlen "$s")
    pad=$(( n - vis ))
    [ $pad -lt 0 ] && pad=0
    printf '%s%*s' "$s" "$pad" ''
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
    _pve=$(pveversion 2>/dev/null | head -1 | awk '{print $1}' | cut -d'/' -f1-2)
    L+=( "  PVE     : ${C_GREEN}${_pve}${C_RST}" )
fi

L+=( "  Kernel  : $(uname -r)" )
_uptime=$(uptime -p 2>/dev/null \
    | sed -e 's/ weeks\?/w/g' -e 's/ days\?/d/g' \
          -e 's/ hours\?/h/g' -e 's/ minutes\?/m/g' \
          -e 's/, / /g')
L+=( "  Uptime  : ${_uptime:-$(uptime)}" )
L+=( "  Load    : $(awk '{ print $1, $2, $3 }' /proc/loadavg)" )

if command -v pvecm >/dev/null 2>&1; then
    _q=$(pvecm status 2>/dev/null | awk -F: '/Quorate/ { gsub(/ /,"",$2); print $2 }')
    if [ -n "$_q" ]; then
        _qc=$C_GREEN; [ "$_q" != "Yes" ] && _qc=$C_RED
        L+=( "  Quorum  : ${_qc}${_q}${C_RST}" )
    fi
fi

L+=( "" )
L+=( "${C_BOLD}${C_YELLOW} MEMORY${C_RST}" )
L+=( "  RAM     : $(free -h | awk '/^Mem:/  { printf "%s / %s", $3, $2 }')" )
L+=( "  Swap    : $(free -h | awk '/^Swap:/ { printf "%s / %s", $3, $2 }')" )

L+=( "" )
L+=( "${C_BOLD}${C_YELLOW} STORAGE${C_RST}" )
L+=( "  /       : $(df -h / | awk 'NR==2 { print $3 " / " $2 " (" $5 ")" }')" )

if df -h /var/lib/vz >/dev/null 2>&1; then
    L+=( "  /vz     : $(df -h /var/lib/vz | awk 'NR==2 { print $3 " / " $2 " (" $5 ")" }')" )
fi

# ── right column: network, services, help ─────────────────────────────────
R=()

# IPs
R+=( "${C_BOLD}${C_YELLOW} NETWORK${C_RST}" )
_any_ip=0
while read -r _cidr _iface; do
    _ip=${_cidr%%/*}
    R+=( "  ${C_CYAN}$(printf '%-8s' "$_iface")${C_RST} ${_ip}" )
    _any_ip=1
done < <(ip -4 addr show 2>/dev/null \
    | awk '/^[0-9]+:/ { iface=$2; sub(/:$/,"",iface) }
           /inet / && !/127\.0\.0\.1/ { print $2, iface }')
[ $_any_ip -eq 0 ] && R+=( "  (none)" )

# containers & VMs
if command -v pct >/dev/null 2>&1 || command -v qm >/dev/null 2>&1; then
    R+=( "" )
    R+=( "${C_BOLD}${C_YELLOW} CONTAINERS & VMs${C_RST}" )

    _any_guest=0
    if command -v pct >/dev/null 2>&1; then
        while read -r _id _st _name; do
            _sc=$C_GREEN; [ "$_st" != "running" ] && _sc=$C_RED
            R+=( "  ${C_DIM}LXC${C_RST} [${_id}] $(printf '%-18s' "$_name") ${_sc}${_st}${C_RST}" )
            _any_guest=1
        done < <(pct list 2>/dev/null | awk 'NR>1 { print $1, $2, $NF }')
    fi

    if command -v qm >/dev/null 2>&1; then
        while read -r _id _name _st; do
            _sc=$C_GREEN; [ "$_st" != "running" ] && _sc=$C_RED
            R+=( "  ${C_DIM}KVM${C_RST} [${_id}] $(printf '%-18s' "$_name") ${_sc}${_st}${C_RST}" )
            _any_guest=1
        done < <(qm list 2>/dev/null | awk 'NR>1 { print $1, $2, $3 }')
    fi

    [ $_any_guest -eq 0 ] && R+=( "  (none)" )
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
RW=40   # visible content width — right

_ROWS=$(( ${#L[@]} > ${#R[@]} ? ${#L[@]} : ${#R[@]} ))

# top border
printf "${C_DIM}┌$(_hline $((LW+2)))┬$(_hline $((RW+2)))┐${C_RST}\n"

for (( _i=0; _i<_ROWS; _i++ )); do
    _lc="${L[$_i]-}"
    _rc="${R[$_i]-}"
    printf "${C_DIM}│${C_RST} $(_pad "$_lc" $LW) ${C_DIM}│${C_RST} $(_pad "$_rc" $RW) ${C_DIM}│${C_RST}\n"
done

# bottom border
printf "${C_DIM}└$(_hline $((LW+2)))┴$(_hline $((RW+2)))┘${C_RST}\n"
