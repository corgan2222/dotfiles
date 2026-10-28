#!/bin/bash
# dynamische MOTD
# Aufruf in .bashrc

echo -e "\033[31m"
cat << "EOF"
    ___    _____  __  __ _____    ____  ______      ___    _  __ ____   ____   __  __
   /   |  / ___/ / / / // ___/   / __ \/_  __/     /   |  | |/ /( __ ) ( __ ) / / / /
  / /| |  \__ \ / / / / \__ \   / /_/ / / /______ / /| |  |   // __  |/ __  |/ / / /
 / ___ | ___/ // /_/ / ___/ /  / _, _/ / //_____// ___ | /   |/ /_/ // /_/ // /_/ /
/_/  |_|/____/ \____/ /____/  /_/ |_| /_/       /_/  |_|/_/|_|\____/ \____/ \____/
EOF
echo -e "\033[34m"
echo -e "\033[34m$CPU_CORES x $CPU_TYPE\033[0;37m "

# Datum & Uhrzeit
DATUM=`date +"%a, %e. %B %Y"`

# Hostname
# sourced by .bashrc: an own name, HOSTNAME would change for the whole login shell
_motd_host=$(hostname -f 2>/dev/null || hostname)

# Uptime
UP0=`cut -d. -f1 /proc/uptime`
UP1=$(($UP0/86400))        # Tage
UP2=$(($UP0/3600%24))        # Stunden
UP3=$(printf %02d $(($UP0/60%60)))        # Minuten, zweistellig

# Durchschnittliche Auslasung
LOAD1=`cat /proc/loadavg | awk '{print $1}'`    # Letzte Minute
LOAD2=`cat /proc/loadavg | awk '{print $2}'`    # Letzte 5 Minuten
LOAD3=`cat /proc/loadavg | awk '{print $3}'`    # Letzte 15 Minuten

# the radios have different names per model (eth6/eth7 on the RT-AX88U, eth1/eth2 on others): nvram knows them
TEMP1=$(wl -i "$(nvram get wl0_ifname)" phy_tempsense | awk '{ print $1 * .5 + 20 }')
TEMP2=$(wl -i "$(nvram get wl1_ifname)" phy_tempsense | awk '{ print $1 * .5 + 20 }')

# Speicherbelegung
DISK1=`df -h | grep '/data' | awk '{print $2}'`    # Gesamtspeicher
DISK2=`df -h | grep '/data' | awk '{print $3}'`    # Belegt
DISK3=`df -h | grep '/data' | awk '{print $4}'`    # Frei

# Arbeitsspeicher
# busybox free has no -h: kB from /proc/meminfo, shown in MB
_mb() { awk -v k="$1" '$1 == k":" { printf "%dM", $2 / 1024 }' /proc/meminfo; }
RAM1=$(_mb MemTotal)    # Total
RAM3=$(_mb MemFree)     # Free
RAM4=$(_mb Cached)      # Cache
RAM2=$(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { printf "%dM", (t - a) / 1024 }' /proc/meminfo)    # Used
RAM5=$(_mb SwapTotal)   # Swap Total
RAM7=$(_mb SwapFree)    # Swap free
RAM6=$(awk '/^SwapTotal:/ { t = $2 } /^SwapFree:/ { f = $2 } END { printf "%dM", (t - f) / 1024 }' /proc/meminfo)    # Swap used
unset -f _mb

# IP-Adressen ermitteln
# alle Schnittstellen, egal wie sie heißen (lib/net.sh), höchstens drei in der Zeile
. "${BASH_SOURCE[0]%/*}/../lib/net.sh"
_dot_ip_line() { dot_ips "${3:-3}" | awk -v c="$1" -v r="$2" '{ printf "%s", (n++ ? " | " : "") }
  $1 == "+" { printf "%s", $0; next } { printf "%s: %s%s%s", $1, c, $2, r }'; }
IP_LIST=$(_dot_ip_line $'\033[1;35m' $'\033[0;37m')

# Ausgabe
echo -e "\033[0;37m
\033[0;37m  ~~~~~~~~~~~~~~~~
\033[0;37m |                |  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
\033[0;37m |                |  Hostname......: \033[1;33m$_motd_host\033[0;37m
\033[0;37m |                |  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
\033[0;37m |                |  Ø Auslastung..: \033[1;33m$LOAD1\033[0;37m (1 Min.) | \033[1;33m$LOAD2\033[0;37m (5 Min.) | \033[1;33m$LOAD3\033[0;37m (15 Min.)
\033[0;37m |                |  Temperaturen..: 2.4ghz: \033[1;33m$TEMP1\033[0;37m °C 5ghz: \033[1;33m$TEMP2\033[0;37m °C
\033[0;37m |                |  Speicher......: Gesamt: \033[1;32m\033[1;36m$DISK1\033[0;37m | Belegt: $DISK2 | Frei: \033[32m$DISK3\033[0;37m
\033[0;37m |                |  RAM...........: Gesamt: \033[1;32m\033[1;36m$RAM1\033[0;37m | Belegt: $RAM2 | Frei: \033[32m$RAM3\033[0;37m | Cache: $RAM4
\033[0;37m |                |  Swap..........: Gesamt: \033[1;32m\033[1;36m$RAM5\033[0;37m | Belegt: $RAM6 | Frei: \033[32m$RAM7\033[0;37m
\033[0;37m | $MODELL_TYPE |  IP-Adressen...: ${IP_LIST:----}
\033[0;37m  ~~~~~~~~~~~~~~~~
\033[m"