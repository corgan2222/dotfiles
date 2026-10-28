#!/bin/bash
# Menu for the installers in this folder: offers the ones that fit this system and runs the chosen ones in turn.
#   installer.sh                dialog checklist, grouped by category, with the ways to install and what is installed
#   installer.sh --list         installers that fit this system (name, description, systems, modes)
#   installer.sh --list-all     every installer, also those for other systems
#   installer.sh --list-status  the rows of the menu as text: category, ways to install, installed state
#   installer.sh <name…>        run these installers without the menu (name with or without .sh)
# Every dialog is skipped when its answer is in the environment: INSTALL_CHOICES="alloy grafana" (the checklist),
# INSTALL_MODE (the ways to install, for all), BIND_ADDR (where services listen), the variables of "# ask:".
# Without a terminal a missing answer ends the menu with an error that names its variable.
#
# An installer describes itself in the comment block at its top, directly after the shebang:
#   # installer: one line shown in the menu
#   # systems: all | os and arch tokens, plus "desktop"
# Tokens: an os (ubuntu debian arch fedora rhel kali proxmox raspi alpine …) or a family: "debian" also matches Ubuntu,
# Linux Mint, Kali, Raspberry Pi OS and Proxmox, "arch" Manjaro, "rhel" Rocky and AlmaLinux (DOT_OS_BASE and ID_LIKE);
# and/or an arch (amd64 arm64 armv7 armv6); "desktop" needs a graphical desktop. The installer fits
# when one of its os tokens and one of its arch tokens match (a missing kind matches everything) and, with "desktop",
# a desktop is installed.
#   # modes: native compose portainer      (optional, default native) the ways the installer can install, shown as
#   [B|D|P] in the menu: B native (bare metal), D Docker compose under /opt/<stack>, P a stack in the local Portainer.
#   The menu asks per chosen installer and passes INSTALL_MODE; without the menu: INSTALL_MODE=compose or
#   --docker/--portainer. D and P are offered only while "docker info" answers, P only with a Portainer API token
#   (portainer.sh) or when portainer is chosen in the same run.
#   # category: base|sysop|dev|desktop|docker|db|monitoring|logs|network|raspberry|server    the section of the menu.
#   Preselected are the base installers that are not installed yet, and only on the first run (basics not installed).
#   Checking a section line and OK switches the whole section: all on, or all off when all were on.
#   # check: <token…>    how the menu sees that it is installed; every token must match, "a|b" matches either:
#   a command (also in ~/.local/bin), a systemd unit "<name>.service", a path "/…" or "~/…", and "stack:<name>" for
#   the compose project or Portainer stack (default: the installer's name when its modes have compose or portainer),
#   seen as a container of that project, also a stopped one; /opt/<stack>/compose.yaml counts only while Docker does
#   not answer (a first run cut short leaves the file without a container). Without a check line no state is shown.
#   # ask: [modes] VAR[=default] "question with an example"    a value the installer cannot do without; the menu asks
#   for it after the choice unless VAR is set and passes it on as environment variable. Several lines for several values.
#   With modes (native,compose,portainer, comma-separated) only when the installer runs in one of them. VAR names
#   ending in TOKEN, PASSWORD or SECRET get a password box. Without a default an empty answer skips the installer.
#     # ask: APP_PORT=8080 "Port of the web UI, e.g. 8080"     the box shows 8080, Enter takes it
#     # ask: APP_VERSION=2|1 "Major version"                    a list of 2 and 1, the first one is the default
#     # ask: APP_VERSION=@ "Version"                            a list the installer prints itself, see below
#   The default holds only in the menu: the installer applies the same default itself when VAR is unset.
#   "=@": the menu runs "INSTALL_MODE=<mode> bash <installer> --choices VAR" as the calling user. It prints one value
#   per line, the first is the default, a description may follow after a tab; no root, no change to the system, fast
#   (it runs while the menu waits). When it fails or prints nothing, the menu shows an empty input box instead, and an
#   empty answer leaves VAR unset: the installer then takes its default (the newest).
#   # ports: VAR=port … | port …    the ports the installer listens on: VAR=port when VAR moves it, a bare port when
#   it is fixed; TCP, or UDP with /udp after the port (WG_PORT=51820/udp, 3478/udp; VAR then gets the number only);
#   COND=a,b:<port spec> counts only while the variable COND is a or b (INFLUX_LINE=3:INFLUX3_PORT=8183); several
#   in a row must all hold, and INSTALL_MODE is the way the installer runs (INSTALL_MODE=compose,portainer:3000 for a
#   port only its Docker variant takes). <spec>@<installer>: the port of that installer's service, which this one
#   reuses or runs (NODE_EXPORTER_PORT=9100@node_exporter in prometheus.sh): no conflict while that installer is
#   installed or chosen in the same run, it checks the port itself.
#   Before the run the menu checks the ports of every chosen installer that is not installed yet: taken by a running
#   service or by an installer chosen above it, the menu says by whom and offers the next free port (VAR=port
#   only), another port, to skip the installer, or to try anyway.
# Docker runs on any os: an installer whose modes have "compose" is also offered when only its os tokens do not match
# (arch and desktop still count), marked "(Docker only here)" in --list. Such an installer never runs natively here:
# the menu (and installer.sh <name>) runs it with INSTALL_MODE=compose, or portainer when chosen.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dir=$(dirname "$(readlink -f "$0")")
cats='base sysop dev desktop docker db monitoring logs network raspberry server'
declare -A cat_title=([base]=Base [sysop]=Sysop [dev]=Dev [desktop]=Desktop [docker]=Docker [db]=Databases [monitoring]=Monitoring
  [logs]=Logs [network]="Network/VPN" [raspberry]="Raspberry Pi" [server]=Server [other]=Other)
declare -A mode_of=()

# prints "<name>|<description>|<systems>|<modes>|<category>|<check>" per installer file from the leading comment block;
# defaults "(no description)", "all", "native", "other", ""
inst_meta() {
  awk 'function out() { if (n != "") print n "|" (d == "" ? "(no description)" : d) "|" (s == "" ? "all" : s) "|" \
         (m == "" ? "native" : m) "|" (c == "" ? "other" : c) "|" k }
       FNR == 1 { out(); n = FILENAME; sub(/.*\//, "", n); sub(/\.sh$/, "", n); d = s = m = c = k = ""; hdr = 1 }
       FNR > 1 && !/^#/ { hdr = 0 }
       !hdr { next }
       /^# installer:/ { sub(/^# installer: */, ""); d = $0 }
       /^# systems:/   { sub(/^# systems: */, ""); s = $0 }
       /^# modes:/     { sub(/^# modes: */, ""); m = $0 }
       /^# category:/  { sub(/^# category: */, ""); c = $0 }
       /^# check:/     { sub(/^# check: */, ""); k = $0 }
       END { out() }' "$@"
}

# prints "<modes> VAR[=default] question" for every "# ask:" line of installer file $1; modes "all" when the line names none
inst_asks() {
  awk 'FNR > 1 && !/^#/ { exit }
       /^# ask:/ { sub(/^# ask: */, ""); m = "all"
                   if ($1 ~ /^[a-z,]+$/) { m = $1; sub(/^[^ ]+ */, "") }
                   v = $1; sub(/^[^ ]+ */, ""); gsub(/^"|"$/, ""); print m, v, $0 }' "$1"
}

# prints "VAR=port" or "port", with /udp for UDP and @<installer> for another one's service, for every port of
# installer file $1 that counts now ("# ports:", COND=a,b: prefixes; INSTALL_MODE set to the way it runs)
inst_ports() {
  local t c v
  for t in $(awk 'FNR > 1 && !/^#/ { exit } /^# ports:/ { sub(/^# ports: */, ""); print }' "$1"); do
    while [[ $t =~ ^([A-Z0-9_]+)=([^:@]+):(.+)$ ]]; do
      c=${BASH_REMATCH[1]} v=${!c:-} t=${BASH_REMATCH[3]}
      [[ ,${BASH_REMATCH[2]}, == *,"$v",* ]] && [ -n "$v" ] || continue 2
    done
    echo "$t"
  done
}

# sets mode to the way installer $1 runs: chosen in the menu, else INSTALL_MODE, else native; compose when it has no
# native way here (as inst_run and the installer decide it). Sets how (inst_how) as well.
run_mode() {
  local s m
  IFS='|' read -r _ _ s m _ < <(inst_meta "$dir/$1.sh")
  inst_how "$s" "$m"
  mode=${mode_of[$1]:-${INSTALL_MODE:-native}}; [ "$mode" = docker ] && mode=compose
  { [ "$how" = docker ] || [[ " $m " != *" native "* ]]; } && [ "$mode" != portainer ] && mode=compose
}

# prints who listens on port $1 (TCP, or UDP with /udp: 51820/udp): a container that publishes it, else the
# process, else nothing
port_owner() {
  local c t=t
  [ "${1#*/}" = udp ] && t=u
  # docker reads "51820/udp" itself, a bare port is TCP there as well
  c=$(_root docker ps --filter "publish=$1" --format '{{.Names}}' 2>/dev/null | head -n 1)
  [ -n "$c" ] && { echo "container $c"; return; }
  _root ss -Hl${t}np "sport = :${1%/*}" 2>/dev/null | grep -o '(("[^"]*"' | head -n 1 | tr -d '("'
}

# true when installer $1 is installed (inst_state, sets st)
inst_installed() {
  local m k
  [ -f "$dir/$1.sh" ] || return 1
  IFS='|' read -r _ _ _ m _ k < <(inst_meta "$dir/$1.sh")
  inst_state "$1" "$m" "$k"
  [ -n "$st" ]
}

# Checks the ports of the chosen installers in the order they run (see the header): planned[port] = the installer
# that gets it in this run. A taken port asks: next free port (exports VAR), another port, skip, or try anyway.
# Sets ports_ok to the installers that stay (no $( ): the exported variables have to reach inst_run). check_ports <name…>
declare -A planned=()
check_ports() {
  local name spec var p u o who free a keep mode how
  ports_ok=()
  while [ $# -gt 0 ]; do
    name=$1 keep=1; shift
    # installed: it keeps the ports it has
    if ! inst_installed "$name"; then
      run_mode "$name"
      while read -r spec; do
        [ -n "$spec" ] || continue
        # o: the installer whose service this is (@); u: /udp, or empty for TCP. planned[] and dot_port_busy take
        # the port with u, VAR gets the number only
        o=; [[ $spec == *@* ]] && { o=${spec#*@}; spec=${spec%@*}; }
        u=; [[ $spec == */udp ]] && u=/udp
        spec=${spec%/udp} spec=${spec%/tcp}
        var= p=$spec
        [[ $spec == *=* ]] && { var=${spec%%=*}; p=${!var:-${spec#*=}}; }
        # a reused port of another installer's service (28.10.26: otel natively on the 3000 of grafana.sh, prometheus
        # on the 9100 of node_exporter.sh): that one checks it when it runs later, got it earlier, or has it
        if [ -n "$o" ]; then
          [[ " $* " == *" $o "* ]] || [ "${planned[$p$u]:-}" = "$o" ] || inst_installed "$o" && continue
        fi
        if [ -n "${planned[$p$u]:-}" ]; then who="${planned[$p$u]} (chosen in this run)"
        elif dot_port_busy "$p$u"; then who=$(port_owner "$p$u"); who=${who:-another service}
        else planned[$p$u]=$name; continue; fi
        free=$p
        while dot_port_busy "$free$u" || [ -n "${planned[$free$u]:-}" ]; do free=$((free + 1)); done
        if [ -n "$var" ]; then
          a=$(dlg --title "Port $p$u is taken" --menu "$name wants port $p$u, but $who has it." 0 0 0 \
            free "port $free$u instead (next free one)" other "another port" skip "skip $name" anyway "try anyway") ||
            a=skip
        else
          a=$(dlg --title "Port $p$u is taken" --menu "$name needs port $p$u, but $who has it. Its port is fixed." \
            0 0 0 skip "skip $name" anyway "try anyway (it will most likely fail)") || a=skip
        fi
        clear
        case $a in
          free) export "$var=$free"; p=$free ;;
          other) a=$(dlg --title "$name" --inputbox "Port for $name ($var${u:+, UDP})" 0 50 "$free") || a=; clear
                 [[ $a =~ ^[0-9]+$ ]] || { keep=; break; }
                 export "$var=$a"; p=$a ;;
          skip) keep=; break ;;
        esac
        planned[$p$u]=$name
      done < <(INSTALL_MODE=$mode inst_ports "$dir/$name.sh")
    fi
    if [ -n "$keep" ]; then ports_ok+=("$name"); else echo "skipping $name: port taken" >&2; fi
  done
}

# prints the local addresses listening on TCP port $1, one per line: 0.0.0.0, 127.0.0.1, [::] and so on. Without ss
# (minimal images, Alpine) from /proc/net/tcp: IPv4 as hex in host byte order (little endian), state 0A = LISTEN
listen_on() {
  local l a st h
  if command -v ss >/dev/null 2>&1; then
    # the address without the port and without the %<interface> ss adds to some
    ss -Hltn "sport = :$1" 2>/dev/null | while read -r _ _ _ l _; do l=${l%:*}; echo "${l%%\%*}"; done
    return
  fi
  h=$(printf '%04X' "$1")
  while read -r _ l _ st _; do
    [ "$st" = 0A ] && [ "${l#*:}" = "$h" ] || continue
    a=${l%:*}
    case $a in
      00000000) echo 0.0.0.0 ;;
      ????????) echo "$((16#${a:6:2})).$((16#${a:4:2})).$((16#${a:2:2})).$((16#${a:0:2}))" ;;
      00000000000000000000000000000000) echo '[::]' ;;
      *) echo '[v6]' ;;
    esac
  done < <(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null)
}

# Prints the address the service of installer $1 listens on now, from the first of its ports ("# ports:") something
# listens on: 0.0.0.0 for all interfaces, else the first IPv4 address; nothing when none listens
listen_addr() {
  local spec var p l a
  while read -r spec; do
    # its own TCP ports only: listen_on reads the listen state, UDP has none; @ is another installer's service
    [[ $spec == */udp || $spec == *@* ]] && continue
    spec=${spec%/tcp} p=$spec
    [[ $spec == *=* ]] && { var=${spec%%=*}; p=${!var:-${spec#*=}}; }
    a=
    while read -r l; do
      case $l in
        0.0.0.0|\*|\[::\]) echo 0.0.0.0; return ;;
        \[*) ;;
        *) [ -n "$a" ] || a=$l ;;
      esac
    done < <(listen_on "$p")
    [ -z "$a" ] || { echo "$a"; return; }
  done < <(inst_ports "$dir/$1.sh")
}

# true when a graphical desktop is installed, also when we are logged in over ssh;
# not "systemctl get-default": Arch reports graphical.target on every server
has_desktop() {
  [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && return 0
  compgen -G '/usr/share/xsessions/*.desktop' >/dev/null || compgen -G '/usr/share/wayland-sessions/*.desktop' >/dev/null
}

_ids=" $DOT_OS $DOT_OS_BASE $(_dot_osr ID) $DOT_OS_LIKE "
# Rocky and AlmaLinux name fedora in ID_LIKE: the token "fedora" means Fedora itself, the RHEL family is "rhel"
# (28.10.26: firefoxdev and wifi-wavemon, which have no RHEL path, were offered there and failed)
[ "$DOT_OS_BASE" = rhel ] && _ids=${_ids// fedora / }
# true when the systems tokens of an installer fit this system (rules in the header of this file);
# with $2 = docker the os tokens are left out (Docker runs on any os), arch and desktop still count
inst_fits() {
  local tok os_want= os_ok= arch_want= arch_ok=
  for tok in $1; do
    case $tok in
      all) ;;
      desktop) has_desktop || return 1 ;;
      amd64|arm64|armv7|armv6) arch_want=1; [ "$tok" = "$DOT_ARCH" ] && arch_ok=1 ;;
      *) [ "${2:-}" = docker ] && continue; os_want=1; [[ $_ids == *" $tok "* ]] && os_ok=1 ;;
    esac
  done
  [ -z "$os_want" -o -n "$os_ok" ] && [ -z "$arch_want" -o -n "$arch_ok" ]
}

# sets how to the way an installer with systems $1 and modes $2 fits this system: fit, docker (only its Docker
# variant: modes with compose, os tokens do not match, arch and desktop do) or none.
# inst_how, inst_ways and inst_state set a variable instead of printing: the menu calls them per installer, and a
# subshell each would slow its start on a Raspberry Pi.
inst_how() {
  if inst_fits "$1"; then how=fit
  elif [[ " $2 " == *" compose "* ]] && inst_fits "$1" docker; then how=docker
  else how=none; fi
}

# prints "<name>|<description>|<systems>|<modes>|<category>|<how>|<check>" for every installer (how: see inst_how),
# only the ones that fit (also docker) unless $1 = all. The check comes last: its "a|b" holds the field separator.
inst_list() {
  local name desc s m c k how
  while IFS='|' read -r name desc s m c k; do
    [ "$name" = installer ] && continue
    inst_how "$s" "$m"
    [ "$1" = all ] || [ "$how" != none ] || continue
    echo "$name|$desc|$s|$m|$c|$how|$k"
  done < <(inst_meta "$dir"/*.sh)
}

# runs a command as root without asking for a password: directly as root, else sudo -n
_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@" 2>/dev/null; fi; }

# what Docker and Portainer allow here, read once: docker_up (the daemon answers), proj[<compose project>]=<working
# dir> of every container, portainer_up (an API token for dot_portainer_stack)
docker_up= portainer_up=
declare -A proj=()
docker_probe() {
  local dk=docker p w
  docker_up= portainer_up= proj=()
  command -v docker >/dev/null 2>&1 || return 0
  docker info >/dev/null 2>&1 || { _root docker info >/dev/null 2>&1 && dk="_root docker"; } || return 0
  docker_up=1
  while read -r p w; do [ -n "$p" ] && proj[$p]=$w; done < <($dk ps -a --format \
    '{{.Label "com.docker.compose.project"}} {{.Label "com.docker.compose.project.working_dir"}}' 2>/dev/null)
  if [ -n "${PORTAINER_TOKEN:-}" ] || _root test -s /etc/portainer/api-token; then portainer_up=1; fi
}

# true when a check token is there: command, unit, path (see the header)
_have() {
  case $1 in
    \~/*) [ -e "$HOME/${1#\~/}" ] ;;
    /*) [ -e "$1" ] ;;
    *.service) [ -e "/etc/systemd/system/$1" ] || [ -e "/usr/lib/systemd/system/$1" ] ||
               [ -e "/lib/systemd/system/$1" ] || [ -e "$HOME/.config/systemd/user/$1" ] ;;
    *) command -v "$1" >/dev/null 2>&1 || [ -x "$HOME/.local/bin/$1" ] ;;
  esac
}

# sets st to how installer $1 (modes $2, check $3) is installed: B, D, P, combined like B+D, or empty.
# File tests and the one "docker ps" of docker_probe only, so the menu starts without a noticeable wait.
inst_state() {
  local name=$1 tok alt ok native= missing= s stacks=() w l
  st=
  for tok in $3; do
    case $tok in stack:*) stacks+=("${tok#stack:}"); continue ;; esac
    native=1 ok=
    for alt in ${tok//|/ }; do _have "$alt" && { ok=1; break; }; done
    [ -n "$ok" ] || missing=1
  done
  [ -n "$native" ] && [ -z "$missing" ] && st=B
  [ ${#stacks[@]} -gt 0 ] || [[ " $2 " != *" compose "* && " $2 " != *" portainer "* ]] || stacks=("$name")
  for s in "${stacks[@]}"; do
    w=${proj[$s]-} l=
    # Portainer runs a stack from its own data folder, compose from /opt/<stack>. While Docker answers, the compose
    # file alone is no install: a first run cut short leaves it without a container, and the menu then skipped its
    # port check and offered it as installed (28.10.26, review)
    if [ -n "$w" ]; then [ "$w" = "/opt/$s" ] && l=D || l=P
    elif [ -z "$docker_up" ] && [ -e "/opt/$s/compose.yaml" ]; then l=D; fi
    # one letter per way, also with several stacks (influxdb1 and influxdb2)
    [ -z "$l" ] || [[ "+$st+" == *"+$l+"* ]] || st=${st:+$st+}$l
  done
}

# sets ways to the ways an installer can install here as letters, "B D P"; $1 modes, $2 how, $3 = all: what it can,
# without looking at Docker and Portainer
inst_ways() {
  local m
  ways=
  for m in $1; do
    case $m in
      native) [ "$2" = docker ] || ways+=" B" ;;
      compose) { [ "$3" = all ] || [ -n "$docker_up" ]; } && ways+=" D" ;;
      portainer) { [ "$3" = all ] || { [ -n "$docker_up" ] && [ -n "$portainer_up$want_portainer" ]; }; } && ways+=" P" ;;
    esac
  done
  ways=${ways# }
}

# prints the menu rows in menu order, tab-separated (the ways contain "|"): category, name, item text, on or off,
# description; installers that only run in Docker while Docker does not answer are left out and counted in the file
# $hidden. Preselected: base installers not installed yet, as long as basics is not installed (the first run).
menu_rows() {
  local name desc s m c k how ways st on first= n=0
  IFS='|' read -r _ _ _ m _ k < <(inst_meta "$dir/basics.sh")
  inst_state basics "$m" "$k"; [ -n "$st" ] || first=1
  {
    while IFS='|' read -r name desc s m c how k; do
      inst_ways "$m" "$how" all
      if [ -z "$docker_up" ] && [[ " $ways " != *" B "* || "$how" = docker ]]; then n=$((n + 1)); continue; fi
      [[ " $cats " == *" $c "* ]] || c=other
      inst_state "$name" "$m" "$k"
      on=off; [ "$c" = base ] && [ -n "$first" ] && [ -z "$st" ] && on=on
      printf '%s\t%s\t%-7s %-8s %s\t%s\t%s\n' "$c" "$name" "[${ways// /|}]" "${st:+inst:$st}" "$desc" "$on" "$desc"
    done < <(inst_list fit)
    echo "$n" > "$hidden"
  } | awk -F'\t' -v order="$cats other" \
    'BEGIN { n = split(order, o, " "); for (i = 1; i <= n; i++) r[o[i]] = i } { print r[$1] "\t" $0 }' |
    sort -t "$(printf '\t')" -k1,1n -k3,3 | cut -f2-
}

# runs the installers given by name in turn and prints a summary; returns 1 when one failed.
# The mode is mode_of[<name>] (menu), else INSTALL_MODE; an installer that fits only with Docker runs with
# INSTALL_MODE=compose (portainer when that was chosen), never native.
# The "=== <name> is ready ===" blocks of dot_summary collect in $sum across all calls, inst_recap repeats them.
sum= ran=0
# useless without the network: these never get BIND_ADDR, dot_bind takes their own default (BIND_ADDR=own)
# servers others connect to: VPN, ssh, samba, the Zabbix agent, reverse proxies and API gateways, MQTT brokers,
# node_exporter, otel
bind_own=" wireguard wg_easy openvpn headscale ssh samba zabbix_agent caddy traefik nginx nginx_proxy_manager"
bind_own+=" krakend mosquitto emqx node_exporter otel "
inst_run() {
  local name mode note s m k how bind a ok=() failed=()
  [ -n "$sum" ] || sum=$(mktemp)
  for name in "$@"; do
    name=${name%.sh} ran=$((ran + 1))
    [ -f "$dir/$name.sh" ] || { echo "no installer '$name' in $dir" >&2; failed+=("$name"); continue; }
    mode=${mode_of[$name]:-${INSTALL_MODE:-}} note=
    IFS='|' read -r _ _ s m _ k < <(inst_meta "$dir/$name.sh")
    inst_how "$s" "$m"
    if [ "$how" = docker ]; then
      [ "$mode" = portainer ] || mode=compose
      note=" (Docker only here: $mode)"
    fi
    [ -n "$note" ] || [ "$m" = native ] || note=${mode:+ ($mode)}
    printf '\n\033[92m==== %s%s ====\033[0m\n' "$name" "$note"
    bind=${BIND_ADDR:-}
    [ -z "$bind" ] || [[ $bind_own != *" $name "* ]] || bind=own
    # An installed service keeps the address it listens on, the menu's answer is for new ones (28.10.26: an update
    # from the menu moved VictoriaMetrics from 0.0.0.0 to 127.0.0.1). Installers that read their earlier address do
    # so also while the service is stopped (dot_bind); this covers the others while it runs.
    if [ -n "$bind" ]; then
      inst_state "$name" "$m" "$k"
      [ -z "$st" ] || { a=$(INSTALL_MODE=$mode listen_addr "$name"); [ -z "$a" ] || bind=$a; }
    fi
    if BIND_ADDR=$bind INSTALL_MODE=$mode DOT_SUMMARY_FILE=$sum bash "$dir/$name.sh"; then ok+=("$name")
    else failed+=("$name"); fi
  done
  printf '\n\033[92mdone:\033[0m %s\n' "${ok[*]:-–}"
  [ ${#ok[@]} -eq 0 ] || printf 'New aliases and PATH entries work in a new shell: reload   (or: exec bash -l)\n'
  [ ${#failed[@]} -eq 0 ] || { printf '\033[91mfailed:\033[0m %s\n' "${failed[*]}"; return 1; }
}

# repeats the summaries once at the end when more than one installer ran: Docker and Portainer run before the
# checklist, which clears the screen, so their logins would be lost otherwise
inst_recap() {
  [ -n "$sum" ] || return 0
  [ "$ran" -gt 1 ] && [ -s "$sum" ] && { printf '\n\033[92m==== how to reach what was installed ====\033[0m'; cat "$sum"; }
  rm -f "$sum"
}

case ${1:-} in
  -h|--help) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
  --list|--list-all)
    [ "$1" = --list ] && which=fit || which=all
    inst_list "$which" | awk -F'|' '{ printf "%-22s %-60s %-24s %s\n", $1, $2 ($6 == "docker" ? " (Docker only here)" : ""), $3,
      ($4 == "native" ? "" : $4) }'
    exit 0 ;;
  --list-status)
    docker_probe
    hidden=$(mktemp); trap 'rm -f "$hidden"' EXIT
    echo "$DOT_OS $DOT_OS_VERSION ($DOT_ARCH), Docker: $([ -n "$docker_up" ] && echo running || echo "not running"), Portainer: $([ -n "$portainer_up" ] && echo yes || echo no)"
    last=
    while IFS=$'\t' read -r c name item on _; do
      [ "$c" = "$last" ] || { printf '\n== %s ==\n' "${cat_title[$c]}"; last=$c; }
      printf '%s   %-20s %s\n' "$([ "$on" = on ] && echo '[*]' || echo '[ ]')" "$name" "$item"
    done < <(menu_rows)
    read -r nh < "$hidden"
    [ "$nh" = 0 ] || printf '\nDocker is not running: %s installers that run only in Docker are hidden\n' "$nh"
    exit 0 ;;
  "") ;;
  *) inst_run "$@"; rc=$?; inst_recap; exit $rc ;;
esac

# --- the menu ---
# Without a terminal every dialog fails like Cancel, and the menu ended with 0 as if all was done (28.10.26, review):
# need_tty <VAR> ends it with an error instead when the answer of VAR is not in the environment
need_tty() { { : </dev/tty; } 2>/dev/null || dot_die "no terminal to ask for $1: set $1 in the environment"; }
[ -n "${INSTALL_CHOICES:-}" ] || need_tty INSTALL_CHOICES
# sudo once up front: the menu reads Docker and Portainer as root (sudo -n), the installers need it anyway
[ "$(id -u)" -eq 0 ] || sudo -v || dot_die "the installers need sudo"
docker_probe
# the recap also comes when the checklist or a later dialog is cancelled after Docker and Portainer were installed
hidden=$(mktemp); trap 'inst_recap; rm -f "$hidden"' EXIT
# dialog draws on the terminal and writes the answer to stderr; installed on the first question only
dlg() { command -v dialog >/dev/null 2>&1 || dot_need dialog >/dev/tty; dialog "$@" 2>&1 >/dev/tty </dev/tty; }
# minimal images (fedora) come without clear (ncurses)
command -v clear >/dev/null 2>&1 || clear() { printf '\033[H\033[2J'; }

# asks once for all chosen services: reachable from the network or only from this host (unless BIND_ADDR is set).
# This host only is the default: a database or admin UI open to the network by accident is worse than one that has
# to be opened later (28.10.26). Servers others connect to keep their own default (bind_own, inst_run).
ask_bind() {
  [ -z "${BIND_ADDR:-}" ] || return 0
  need_tty BIND_ADDR
  BIND_ADDR=$(dlg --title "Where should the services listen" --radiolist \
    "Applies to every chosen service with a network port.

This host only: other machines reach the service through a reverse proxy or an SSH tunnel. All interfaces: anyone \
in your network can reach it, choose it only when that is wanted. VPN, ssh, samba and the Zabbix agent always keep \
their own setting, installed services the address they listen on." 0 0 0 \
    127.0.0.1 "this host only (reverse proxy, SSH tunnel)" on \
    0.0.0.0 "all interfaces, reachable from the network" off) || { clear; exit 0; }
  clear
  export BIND_ADDR
}

# asks for the values installer $1 cannot do without ("# ask:") unless they are in the environment and exports them;
# false when one is left empty, the installer is skipped then
ask_values() {
  local name=$1 how mode modes tok var def q box val v d tags opts descs
  [ -f "$dir/$name.sh" ] || return 0
  # the mode it will run in, as inst_run and the installer decide it
  run_mode "$name"
  while read -r modes tok q; do
    var=${tok%%=*} def=; [ "$tok" = "$var" ] || def=${tok#*=}
    [ -n "${!var:-}" ] && continue
    [ "$modes" = all ] || [[ ",$modes," == *",$mode,"* ]] || continue
    need_tty "$var"
    tags=() opts=() descs=
    if [ "$def" = @ ]; then
      # the installer lists the values itself (see the header)
      echo "reading the choices for $name ($var) …"
      while IFS=$'\t' read -r v d; do [ -z "$v" ] || { tags+=("$v"); opts+=("$v" "$d"); descs+=$d; }; done < <(
        INSTALL_MODE=$mode timeout 60 bash "$dir/$name.sh" --choices "$var" </dev/null 2>/dev/null)
    fi
    if [ -n "$descs" ]; then
      val=$(dlg --title "$name" --menu "$q" 0 72 0 "${opts[@]}") || { clear; exit 0; }
    elif [ ${#tags[@]} -gt 0 ]; then
      val=$(dlg --title "$name" --no-items --menu "$q" 0 72 0 "${tags[@]}") || { clear; exit 0; }
    elif [ "$def" = @ ]; then
      val=$(dlg --title "$name" --inputbox "$q (empty: the newest)" 0 72 "") || { clear; exit 0; }
      clear
      [ -z "$val" ] || export "$var=$val"
      continue
    elif [[ $def == *"|"* ]]; then
      val=$(dlg --title "$name" --no-items --menu "$q" 0 72 0 ${def//|/ }) || { clear; exit 0; }
    else
      box=--inputbox; case $var in *TOKEN|*PASSWORD|*SECRET) box="--insecure --passwordbox" ;; esac
      val=$(dlg --title "$name" $box "$q" 0 72 "$def") || { clear; exit 0; }
    fi
    clear
    [ -n "$val" ] || { echo "skipping $name: no $var given" >&2; return 1; }
    export "$var=$val"
  done < <(inst_asks "$dir/$name.sh")
}

# Bitwarden before anything that makes passwords: with an unlocked vault every login also goes there (lib/bw.sh).
# Unlocked once, the session holds until the reboot or "bw lock" and later runs ask nothing; "No" to unlocking holds
# as long. "No" before setting it up is noted for good (DOT_SKIP_BW in ~/.extra), bw.sh sets it up later.
# BW_SERVER from ~/.extra names the own server.
. "$dir/../lib/bw.sh"
[ -n "${BW_SERVER:-}" ] || BW_SERVER=$(sed -n "s/^export BW_SERVER=//p" ~/.extra 2>/dev/null | tr -d "'\"")
if [ -z "${BW_SESSION:-}" ] && dot_bw_resume; then
  dot_info "Bitwarden is unlocked (this boot): the logins go to your vault, folder dotfiles"
elif [ -z "${INSTALL_CHOICES:-}" ] && [ -z "${BW_SESSION:-}" ] && ! grep -qs '^export DOT_SKIP_BW=' ~/.extra &&
     ! dot_bw_declined; then
  case $(dot_bw_status) in
    locked)
      if dlg --title "Bitwarden" --yesno "Unlock your Bitwarden vault?
The installers then store their logins there (folder dotfiles, one login per service). It stays unlocked until the next reboot or bw lock. No: not asked again until the reboot." 0 0
      then clear; dot_bw_setup || dot_info "going on without Bitwarden (later: bash ~/.dot/installer/bw.sh)"
      else clear; dot_bw_decline; fi ;;
    *)
      if dlg --title "Bitwarden" --yesno "Store the logins of the installers in Bitwarden?
Grafana, Portainer, databases and others create passwords and tokens. With Bitwarden each one also goes to your vault as a login: address, user, password, tokens as hidden fields, folder dotfiles, named <host>_<service>.
Next: install the Bitwarden CLI (bw), choose the server (bitwarden.com, .eu or your own URL), log in, unlock.
No: not asked again; set it up later with: bash ~/.dot/installer/bw.sh" 0 0
      then clear; dot_bw_setup || dot_info "going on without Bitwarden (later: bash ~/.dot/installer/bw.sh)"
      else clear; ( umask 077; echo 'export DOT_SKIP_BW=1' >> ~/.extra ); fi ;;
  esac
fi
# Not in the environment of the installers: they run foreign code (rustup, 1Panel, npm) that has no business with the
# vault (28.10.26, review). dot_summary reads the session from the file of this boot (lib/bw.sh).
if [ -n "${BW_SESSION:-}" ]; then
  dot_bw_keep || echo "warning: no private folder for the Bitwarden session, the logins are not stored" >&2
  export -n BW_SESSION
fi

# Docker first: without it D and P are off and the installers that run only in Docker are hidden
if [ -z "${INSTALL_CHOICES:-}" ] && [ -z "$docker_up" ] && [ -f "$dir/docker.sh" ] &&
   dlg --title "Docker" --yesno "Docker is not installed or not running here.

Install Docker and Portainer first? Then many services can also be installed with D (Docker compose) or P (a stack in Portainer)." 0 0; then
  clear
  ask_values portainer && ask_bind && with_portainer=1
  inst_run docker
  docker_probe
  [ -z "$docker_up" ] || [ -z "${with_portainer:-}" ] || { inst_run portainer; docker_probe; }
  read -r -p "Enter: on to the list of installers " _ </dev/tty
  [ -n "$docker_up" ] || dlg --title "Docker is not running" --msgbox "Docker is installed, but its daemon does not run (no systemd here?).

Start it, e.g. with: sudo systemctl start docker  or  sudo dockerd &  and open this menu again. Until then the list offers B (native) only." 0 0
fi

if [ -n "${INSTALL_CHOICES:-}" ]; then
  choices=$INSTALL_CHOICES
else
  # sel[<name>] on|off: the state of every row across the rounds of the checklist; sec_cat[<section line>] its category
  declare -A sel=() sec_cat=()
  mapfile -t rows < <(menu_rows)
  [ ${#rows[@]} -gt 0 ] || dot_die "no installer fits $DOT_OS on $DOT_ARCH"
  for r in "${rows[@]}"; do IFS=$'\t' read -r _ name _ on _ <<<"$r"; sel[$name]=$on; done
  text="Space selects, Enter installs. A section line (== Dev ==) with OK selects its whole section, or clears it when all were on.
[B|D|P]: ways to install, B native, D Docker compose, P Portainer stack; inst:B = installed that way."
  read -r nh < "$hidden"
  [ -n "$docker_up" ] || text+="
Docker is not running: only B is offered until it runs"
  [ -n "$docker_up" ] || [ "$nh" = 0 ] || text+=", $nh installers that run only in Docker are hidden"
  [ -n "$docker_up" ] || text+="."
  [ -z "$docker_up" ] || [ -n "$portainer_up" ] || text+="
No Portainer here (portainer.sh), P is off unless portainer is chosen too."
  # dialog cannot act on a single row: after OK with section lines checked, switch their sections and show it again
  at=()
  while :; do
    items=() last=
    for r in "${rows[@]}"; do
      IFS=$'\t' read -r c name item _ desc <<<"$r"
      if [ "$c" != "$last" ]; then
        s="== ${cat_title[$c]} =="; sec_cat[$s]=$c; last=$c
        items+=("$s" "" off "selects all of ${cat_title[$c]}, or clears them when all are on")
      fi
      items+=("  $name" "$item" "${sel[$name]}" "$desc")
    done
    out=$(dlg --separate-output --item-help "${at[@]}" --title "Installers for $DOT_OS $DOT_OS_VERSION ($DOT_ARCH)" \
      --checklist "$text" 0 0 0 "${items[@]}") || { clear; exit 0; }
    for name in "${!sel[@]}"; do sel[$name]=off; done
    secs=()
    while read -r l; do case $l in "== "*) secs+=("$l") ;; ?*) sel[$l]=on ;; esac; done <<<"$out"
    [ ${#secs[@]} -gt 0 ] || break
    for s in "${secs[@]}"; do
      all=on
      for r in "${rows[@]}"; do
        IFS=$'\t' read -r c name _ <<<"$r"
        [ "$c" = "${sec_cat[$s]}" ] && [ "${sel[$name]}" = off ] && all=off
      done
      for r in "${rows[@]}"; do
        IFS=$'\t' read -r c name _ <<<"$r"
        [ "$c" = "${sec_cat[$s]}" ] && { [ "$all" = on ] && sel[$name]=off || sel[$name]=on; }
      done
    done
    at=(--default-item "${secs[-1]}")
  done
  clear
  choices=
  for r in "${rows[@]}"; do IFS=$'\t' read -r _ name _ <<<"$r"; [ "${sel[$name]}" = on ] && choices+="$name "; done
fi
[ -n "$choices" ] || exit 0

# what others build on first, in this order: docker and portainer, then the backends that chronograf (InfluxDB),
# alloy (Loki) and grafana-plugins (Grafana) look for; the rest keeps the order of the list. Grafana before
# Prometheus: prometheus.sh (and victoriametrics.sh later) adds its datasource to a Grafana that is there already.
choices=$(printf '%s\n' $choices | awk -v first="docker portainer influxdb loki grafana prometheus" \
  'BEGIN { n = split(first, f, " "); for (i = 1; i <= n; i++) p[f[i]] = i } { print (p[$0] ? p[$0] : 99), NR, $0 }' |
  sort -k1,1n -k2,2n | cut -d' ' -f3)
want_portainer=; grep -qx portainer <<<"$choices" && want_portainer=1

# the way to install, per chosen installer that has more than one here; INSTALL_MODE answers for all
if [ -z "${INSTALL_MODE:-}" ]; then
  # the way chosen last, also in an earlier run (28.10.26: all in Portainer meant three steps down per installer)
  last_file=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-install-way
  last=$(cat "$last_file" 2>/dev/null)
  for name in $choices; do
    [ -f "$dir/$name.sh" ] || continue
    IFS='|' read -r _ _ s m _ k < <(inst_meta "$dir/$name.sh")
    inst_how "$s" "$m"; inst_ways "$m" "$how"
    case $ways in
      "") continue ;;
      B) mode_of[$name]=native; continue ;;
      D) mode_of[$name]=compose; continue ;;
    esac
    inst_state "$name" "$m" "$k"
    # preselected, with the cursor on it: the way it is installed now, else the one chosen last, else the first one
    def=${st%%+*}
    [[ -n $def && " $ways " == *" $def "* ]] || def=$last
    [[ -n $def && " $ways " == *" $def "* ]] || def=${ways%% *}
    opts=()
    for w in $ways; do
      case $w in
        B) opts+=(B "native packages and services on this system") ;;
        D) opts+=(D "Docker compose under /opt") ;;
        P) opts+=(P "stack in the local Portainer") ;;
      esac
      [ "$w" = "$def" ] && opts+=(on) || opts+=(off)
    done
    note=
    [[ " $m " == *" portainer "* && " $ways " != *" P "* && -n "$docker_up" ]] && note=" P needs Portainer (portainer.sh)."
    need_tty INSTALL_MODE
    w=$(dlg --default-item "$def" --title "How to install $name" \
      --radiolist "Ways $name can install here.${st:+ Installed now: $st.}$note" 0 0 0 "${opts[@]}") || { clear; exit 0; }
    clear
    case $w in B) mode_of[$name]=native ;; D) mode_of[$name]=compose ;; P) mode_of[$name]=portainer ;; esac
    last=$w
  done
  [ -z "$last" ] || { mkdir -p "${last_file%/*}" && echo "$last" > "$last_file"; } 2>/dev/null
fi

inst_list fit | awk -F'|' -v c=" $(echo $choices) " 'index(c, " " $1 " ") && $4 != "native" { f = 1 } END { exit !f }' &&
  ask_bind

# values the chosen installers cannot do without ("# ask:"), unless already in the environment
run=()
for name in $choices; do ask_values "$name" && run+=("$name"); done
# ports last: the answers above (INFLUX_LINE, ports asked for) decide which ports count; without the menu
# (INSTALL_CHOICES) the installers' own checks act
if [ -z "${INSTALL_CHOICES:-}" ] && [ ${#run[@]} -gt 0 ]; then
  check_ports "${run[@]}"
  run=("${ports_ok[@]}")
fi
[ ${#run[@]} -gt 0 ] || exit 0

inst_run "${run[@]}"; rc=$?
# the setup asks for what the installation made possible (delta as git pager, …) and stays quiet otherwise;
# not when setup.sh started this menu (DOT_FROM_SETUP), it goes on by itself
[ -n "${DOT_FROM_SETUP:-}" ] || [ ! -f "$HOME/.dot/setup.sh" ] || bash "$HOME/.dot/setup.sh" --auto
exit $rc
