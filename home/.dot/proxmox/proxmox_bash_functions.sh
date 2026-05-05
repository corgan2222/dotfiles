#!/bin/bash
# ------------------------------------------------------------------------------
# | Proxmox VE helper functions                                                |
# ------------------------------------------------------------------------------

# enter the first matching CT by name fragment
ctenter_by_name() {
    local needle="$1"
    [ -z "$needle" ] && { echo "usage: ctenter_by_name <name|fragment>"; return 1; }
    local id
    id=$(pct list | awk -v n="$needle" 'NR>1 && tolower($0) ~ tolower(n) { print $1; exit }')
    [ -z "$id" ] && { echo "no CT matching '$needle'"; return 1; }
    echo "entering CT $id"
    pct enter "$id"
}

# start/stop a VM by name fragment
vm_by_name() {
    local action="$1" needle="$2"
    [ -z "$action" ] || [ -z "$needle" ] && { echo "usage: vm_by_name <start|stop|shutdown|status> <name>"; return 1; }
    local id
    id=$(qm list | awk -v n="$needle" 'NR>1 && tolower($0) ~ tolower(n) { print $1; exit }')
    [ -z "$id" ] && { echo "no VM matching '$needle'"; return 1; }
    qm "$action" "$id"
}

# show all running CTs and VMs at a glance
pveps() {
    echo "=== LXC ==="
    pct list 2>/dev/null
    echo
    echo "=== KVM ==="
    qm list 2>/dev/null
}

# rough resource summary across nodes
pvesummary() {
    local cpu mem
    cpu=$(awk '/^cpu / { usage = ($2+$4)*100/($2+$4+$5); printf "%.1f%%", usage }' /proc/stat 2>/dev/null)
    mem=$(free -h | awk '/^Mem:/ { printf "%s / %s used", $3, $2 }')
    echo "Host: $(hostname)"
    echo "Kernel: $(uname -r)"
    [ -n "$cpu" ] && echo "CPU: $cpu"
    [ -n "$mem" ] && echo "MEM: $mem"
    if command -v pveversion >/dev/null 2>&1; then
        echo "PVE: $(pveversion | head -1)"
    fi
    if [ -d /etc/pve ]; then
        echo "CTs: $(ls /etc/pve/lxc 2>/dev/null | wc -l)  VMs: $(ls /etc/pve/qemu-server 2>/dev/null | wc -l)"
    fi
}

# tail current cluster task log
pvetail() {
    local latest
    latest=$(ls -t /var/log/pve/tasks/active 2>/dev/null | head -1)
    [ -z "$latest" ] && { echo "no active task log"; return 1; }
    tail -f "/var/log/pve/tasks/active/$latest"
}

# snapshot helpers
ctsnap()  { pct snapshot "$1" "${2:-snap-$(date +%Y%m%d-%H%M%S)}"; }
vmsnap()  { qm  snapshot "$1" "${2:-snap-$(date +%Y%m%d-%H%M%S)}"; }
ctsnaps() { pct listsnapshot "$1"; }
vmsnaps() { qm  listsnapshot "$1"; }
