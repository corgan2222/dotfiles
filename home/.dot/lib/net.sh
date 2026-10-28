#!/bin/bash
# Network helpers for the MOTD scripts: no interface names in the scripts, they differ on every system (eth0, enp2s0,
# br0, vmbr0, ovs_eth4, wlan0, wlp3s0, zt…). Functions only, safe to source from a login shell.

# Prints "<interface> <IPv4 address>" for every address of this host, whatever the interfaces are called. Interfaces
# that only connect containers and VMs (Docker, Podman, LXC, libvirt, Kubernetes, Proxmox firewall bridges and taps,
# Home Assistant's hassio) are not listed one by one: a host with many containers would flood the MOTD. They end up in
# one last line "+ <n> container networks". At most <max> lines (default 6), more real ones end in "+ <n> more".
# Link-local addresses (169.254.x.x) are left out.
#   dot_ips [max]
dot_ips() {
  local max=${1:-6} n=0 more=0 virt=0 ifc ip
  while read -r ifc ip; do
    # link-local addresses (169.254.x.x) sit on ports without a DHCP server, e.g. unplugged NAS ports
    case $ip in 169.254.*) continue ;; esac
    case $ifc in
      lo|lo:*) ;;
      docker*|br-*|veth*|virbr*|lxcbr*|lxdbr*|podman*|cni*|flannel*|cali*|vxlan*|fwbr*|fwpr*|fwln*|tap*|hassio) virt=$((virt + 1)) ;;
      *)
        if [ $n -lt "$max" ]; then printf '%s %s\n' "$ifc" "$ip"; n=$((n + 1)); else more=$((more + 1)); fi ;;
    esac
  done < <(_dot_ip_pairs)
  [ $more -gt 0 ] && printf '+ %d more\n' "$more"
  [ $virt -gt 0 ] && printf '+ %d container networks\n' "$virt"
  return 0
}

# "<interface> <address>" from ip, else from ifconfig (busybox and old net-tools print "inet addr:", new ones "inet")
_dot_ip_pairs() {
  if command -v ip >/dev/null 2>&1 && ip -4 -o addr show >/dev/null 2>&1; then
    ip -4 -o addr show 2>/dev/null | awk '{ sub(/\/.*/, "", $4); print $2, $4 }'
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig 2>/dev/null | awk '
      /^[^ \t]/ { i = $1; sub(/:$/, "", i) }
      /inet / { a = $2; sub(/^addr:/, "", a); if (a != "") print i, a }'
  elif [ -r /proc/net/fib_trie ] && [ -r /proc/net/route ]; then
    # neither ip nor ifconfig (minimal images and containers): the local addresses from the kernel's tables, the
    # interface from the route whose network holds the address (plain awk, also busybox and mawk)
    awk '
      function hex(h,   i, v) { v = 0; h = toupper(h); for (i = 1; i <= length(h); i++) v = v * 16 + index("0123456789ABCDEF", substr(h, i, 1)) - 1; return v }
      function band(a, b,   r, p) { r = 0; p = 1; while (a > 0 && b > 0) { if (a % 2 && b % 2) r += p; a = int(a / 2); b = int(b / 2); p *= 2 }; return r }
      FNR == 1 { f++; next }
      f == 1 && $8 != "00000000" { n++; ifc[n] = $1; for (i = 0; i < 4; i++) { d[n, i] = hex(substr($2, 7 - 2 * i, 2)); m[n, i] = hex(substr($8, 7 - 2 * i, 2)) } }
      f == 2 && /\/32 host LOCAL/ && prev !~ /^127\./ && !(prev in seen) {
        seen[prev] = 1; split(prev, o, ".")
        for (r = 1; r <= n; r++) {
          ok = 1; for (i = 0; i < 4; i++) if (band(o[i + 1], m[r, i]) != d[r, i]) ok = 0
          if (ok) { print ifc[r], prev; break }
        }
      }
      f == 2 { prev = $NF }
    ' /proc/net/route /proc/net/fib_trie 2>/dev/null
  fi
}

# first address of the interface the default route uses (the LAN address of a host), empty without a default route
dot_main_ip() {
  local dev
  # the default route has destination 00000000 in /proc/net/route, the same as "ip route show default"
  dev=$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route 2>/dev/null)
  [ -n "$dev" ] && _dot_ip_pairs | awk -v d="$dev" '$1 == d { print $2; exit }'
}
