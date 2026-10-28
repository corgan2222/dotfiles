#!/bin/sh
# dynamische MOTD
# Aufruf in .bashrc

echo -e "\033[31m"
# banner: the host name, as figlet art when figlet is there
if command -v figlet >/dev/null 2>&1; then figlet "$(hostname -s)"; else hostname -s; fi
echo -e "\033[34m"
echo -e "\033[34m$CPU_CORES x $CPU_TYPE\033[0;37m " 

# SNMP of the DiskStation itself, empty when snmpwalk is missing or the agent does not answer. Ten snmpwalk calls took
# 666 ms of each login on a DS1817+ (28.10.26), so a background job writes the values to a cache every 5 minutes and
# the login only reads it. The first probe has one second and no retry; without an agent the cache stays empty
_syno_snmp() { snmpwalk -v 2c -c syno -O qv -t 1 -r 0 127.0.0.1 "$1" 2>/dev/null; }
_syno_values() {
  local v l i=0
  v=$(_syno_snmp 1.3.6.1.4.1.6574.1.2.0) || return 0
  printf 'T_CPU=%q\n' "$v"
  for l in a b c d e f g h; do
    printf 'sd%stemp=%q\n' "$l" "$(_syno_snmp 1.3.6.1.4.1.6574.2.1.1.6.$i)"; i=$((i + 1))
  done
  # raidName and raidStatus, one line per volume or pool
  printf 'raid=%q\n' "$(_syno_snmp 1.3.6.1.4.1.6574.3.1.1.2 | tr -d '"')"
  printf 'raid_state=%q\n' "$(_syno_snmp 1.3.6.1.4.1.6574.3.1.1.3)"
}
T_CPU= raid= raid_state=
if command -v snmpwalk >/dev/null 2>&1; then
  _syno_cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/motd-synology
  mkdir -p "${_syno_cache%/*}"
  if [ -z "$(find "$_syno_cache" -mmin -5 2>/dev/null)" ]; then
    # double fork and exec 255>&- as in motd_proxmox.sh: no job notice, the login shell does not wait for the job
    ( ( exec 255>&-; _syno_values > "$_syno_cache.$$" 2>/dev/null && mv -f "$_syno_cache.$$" "$_syno_cache" ) \
        </dev/null >/dev/null 2>&1 & )
  fi
  # %q quoted by _syno_values
  [ -s "$_syno_cache" ] && . "$_syno_cache"
fi

# Datum & Uhrzeit
DATUM=`date +"%a, %e. %B %Y"`

# Hostname

# Uptime
UP0=`cut -d. -f1 /proc/uptime`
UP1=$(($UP0/86400))        # Tage
UP2=$(($UP0/3600%24))        # Stunden
UP3=$(($UP0/60%60))        # Minuten
UP4=$(($UP0%60))        # Sekunden

# Durchschnittliche Auslasung
LOAD1=`cat /proc/loadavg | awk '{print $1}'`    # Letzte Minute
LOAD2=`cat /proc/loadavg | awk '{print $2}'`    # Letzte 5 Minuten
LOAD3=`cat /proc/loadavg | awk '{print $3}'`    # Letzte 15 Minuten

# CPU Temperaturen
#cnt=0; TEMP=0
#for FILE in `ls /sys/devices/platform/coretemp.0/hwmon/hwmon0/temp?_input`; do
#    TEMP=$[TEMP + $(cat "${FILE}")]
#    cnt=$[cnt+1]
#done
#TEMP=$[TEMP/cnt/1000]


# HDD Temperaturen
#sdatemp=$(smartctl -d ata -a /dev/sda | grep "194 Temperature" | cut -c 129-130)
#sdbtemp=$(smartctl -d ata -a /dev/sdb | grep "194 Temperature" | cut -c 129-130)


# raidStatus of the Synology MIB, 1-based
RStat=( "" Normal Repairing Migrating Expanding Deleting Creating RaidSyncing RaidParityChecking RaidAssembling
  Canceling Degrade Crashed DataScrubbing RaidDeploying RaidUnDeploying RaidMountCache RaidUnmountCache
  RaidExpandingUnfinishedSHR RaidConvertSHRToPool RaidMigrateSHR1ToSHR2 RaidUnknownStatus )
# the whole table came column by column into one line before and showed "01" and "Pool" (28.10.26)
while IFS= read -r raid_name && IFS= read -r raid_stat_number <&3; do
  [ -n "$raid_name" ] || continue
  c='\033[5m\033[31m'; [ "$raid_stat_number" = 1 ] && c='\033[32m'
  echo -e "Raid: \033[1;33m$raid_name\033[0;37m Status: $c${RStat[$raid_stat_number]:-$raid_stat_number}\033[0m"
done < <(printf '%s\n' "$raid") 3< <(printf '%s\n' "$raid_state")

# Speicherbelegung
DISK1=`df -h /volume1 2>/dev/null | awk 'NR==2 {print $2}'`    # Gesamtspeicher
DISK2=`df -h /volume1 2>/dev/null | awk 'NR==2 {print $3}'`    # Belegt
DISK3=`df -h /volume1 2>/dev/null | awk 'NR==2 {print $4}'`    # Frei

# Arbeitsspeicher
RAM1=`free -h | grep 'Mem' | awk '{print $2}'`    # Total
RAM2=`free -h | grep 'Mem' | awk '{print $3}'`    # Used
RAM3=`free -h | grep 'Mem' | awk '{print $4}'`    # Free
RAM4=`free -h | grep 'Mem' | awk '{print $6}'`    # Cache
RAM5=`free -h | grep 'Swap' | awk '{print $2}'`    # Swap Total
RAM6=`free -h | grep 'Swap' | awk '{print $3}'`    # Swap used
RAM7=`free -h | grep 'Swap' | awk '{print $4}'`    # Swap free

# IP-Adressen ermitteln
# alle Schnittstellen, egal wie sie heißen (lib/net.sh), höchstens drei in der Zeile
. "${BASH_SOURCE[0]%/*}/../lib/net.sh"
_dot_ip_line() { dot_ips "${3:-3}" | awk -v c="$1" -v r="$2" '{ printf "%s", (n++ ? " | " : "") }
  $1 == "+" { printf "%s", $0; next } { printf "%s: %s%s%s", $1, c, $2, r }'; }
IP_LIST=$(_dot_ip_line $'\033[1;35m' $'\033[0;37m')

# Ausgabe
echo -e "\033[0;37m
\033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
\033[0;37m |  \033[32m1\033[0;37m   \033[32m2\033[0;37m  \033[32m3\033[0;37m   \033[32m4\033[0;37m   \033[32m5\033[0;37m   \033[32m6\033[0;37m   \033[32m7\033[0;37m   \033[32m8\033[0;37m |  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
\033[0;37m | \033[1;33m$sdatemp\033[0;37m  \033[1;33m$sdbtemp\033[0;37m  \033[1;33m$sdctemp\033[0;37m \033[1;33m$sddtemp\033[0;37m  \033[1;33m$sdetemp\033[0;37m  \033[1;33m$sdftemp\033[0;37m  \033[1;33m$sdgtemp\033[0;37m  \033[1;33m$sdhtemp\033[0;37m \033[32m°C\033[0;37m|  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
\033[0;37m |                              \033[32m-\033[0;37m|  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
\033[0;37m |                              \033[32m-\033[0;37m|  Ø Auslastung..: \033[1;33m$LOAD1\033[0;37m (1 Min.) | \033[1;33m$LOAD2\033[0;37m (5 Min.) | \033[1;33m$LOAD3\033[0;37m (15 Min.)
\033[0;37m |                               |  Temperaturen..: CPU: \033[1;33m$T_CPU\033[0;37m °C 
\033[0;37m |                            \033[34m[]\033[0;37m |  Speicher......: Gesamt: \033[1;32m\033[1;36m$DISK1\033[0;37m | Belegt: $DISK2 | Frei: \033[32m$DISK3\033[0;37m
\033[0;37m |                            \033[0;32m(c)\033[0;37m|  RAM...........: Gesamt: \033[1;32m\033[1;36m$RAM1\033[0;37m | Belegt: $RAM2 | Frei: \033[32m$RAM3\033[0;37m | Cache: $RAM4
\033[0;37m |                            \033[34m(\033[31m'\033[34m)\033[0;37m|  Swap..........: Gesamt: \033[1;32m\033[1;36m$RAM5\033[0;37m | Belegt: $RAM6 | Frei: \033[32m$RAM7\033[0;37m
\033[0;37m | $MODELL_TYPE                       |  IP-Adressen...: ${IP_LIST:----}
\033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
\033[m"
unset -f _syno_snmp _syno_values
unset raid_name raid_stat_number c
unset _syno_cache

#\033[1;32m\033[1;36m$RAM5\033[0;37m





# # Ausgabe
# echo -e "\033[0;37m
# \033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~
# \033[0;37m |                       \033[32m-\033[0;37m|  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
# \033[0;37m |                       \033[32m-\033[0;37m|  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
# \033[0;37m |                       \033[32m-\033[0;37m|  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
# \033[0;37m |                       \033[32m-\033[0;37m|  Ø Auslastung..: \033[1;33m$LOAD1\033[0;37m (1 Min.) | \033[1;33m$LOAD2\033[0;37m (5 Min.) | \033[1;33m$LOAD3\033[0;37m (5 Min.) (15 Min.)
# \033[0;37m |                        |  Temperaturen..: CPU: $TEMP °C | HDD1: $sdatemp °C | HDD2: $sdbtemp °C
# \033[0;37m |                     \033[34m[]\033[0;37m |  Speicher......: Gesamt: $DISK1 | Belegt: $DISK2 | Frei: $DISK3
# \033[0;37m |                     \033[0;32m(c)\033[0;37m|  RAM...........: Gesamt: $RAM1 | Belegt: $RAM2 | Frei: $RAM3 | Cache: $RAM4
# \033[0;37m |                     \033[34m(\033[31m'\033[34m)\033[0;37m|  Swap..........: Gesamt: $RAM5 | Belegt: $RAM6 | Frei: $RAM7
# \033[0;37m | $MODELL_TYPE                |  IP-Adressen...: LAN: \033[1;35m$IP_LAN\033[0;37m | Zerotier: \033[1;35m$IP_WLAN\033[0;37m
# \033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~
# \033[m"

# # Ausgabe
# echo -e "\033[0;37m
# \033[0;37m  ~~~~~~~~~~~~
# \033[0;37m |           \033[32m-\033[0;37m|  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
# \033[0;37m |           \033[32m-\033[0;37m|  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
# \033[0;37m |           \033[32m-\033[0;37m|  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
# \033[0;37m |           \033[32m-\033[0;37m|  Ø Auslastung..: $LOAD1 (1 Min.) | $LOAD2 (5 Min.) | $LOAD3 (15 Min.)
# \033[0;37m |            |  Temperaturen..: CPU: $TEMP °C | HDD1: $sdatemp °C | HDD2: $sdbtemp °C
# \033[0;37m |         \033[34m[]\033[0;37m |  Speicher......: Gesamt: $DISK1 | Belegt: $DISK2 | Frei: $DISK3
# \033[0;37m |         \033[0;32m(c)\033[0;37m|  RAM...........: Gesamt: $RAM1 | Belegt: $RAM2 | Frei: $RAM3 | Cache: $RAM4
# \033[0;37m |         \033[34m(\033[31m'\033[34m)\033[0;37m|  Swap..........: Gesamt: $RAM5 | Belegt: $RAM6 | Frei: $RAM7
# \033[0;37m | DS218+     |  IP-Adressen...: LAN: \033[1;35m$IP_LAN\033[0;37m | WiFi: \033[1;35m$IP_WLAN\033[0;37m
# \033[0;37m  ~~~~~~~~~~~~
# \033[m"