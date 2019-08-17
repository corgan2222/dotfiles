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
HOSTNAME=`hostname -f`

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

TEMP1=$(wl -i eth6 phy_tempsense | awk '{ print $1 * .5 + 20 }')
TEMP2=$(wl -i eth7 phy_tempsense | awk '{ print $1 * .5 + 20 }')

# Speicherbelegung
DISK1=`df -h | grep '/data' | awk '{print $2}'`    # Gesamtspeicher
DISK2=`df -h | grep '/data' | awk '{print $3}'`    # Belegt
DISK3=`df -h | grep '/data' | awk '{print $4}'`    # Frei

# Arbeitsspeicher
RAM1=`free -h | grep 'Mem' | awk '{print $2}'`    # Total
RAM2=`free -h | grep 'Mem' | awk '{print $3}'`    # Used
RAM3=`free -h | grep 'Mem' | awk '{print $4}'`    # Free
RAM4=`free -h | grep 'Mem' | awk '{print $6}'`    # Cache
RAM5=`free -h | grep 'Swap' | awk '{print $2}'`    # Swap Total
RAM6=`free -h | grep 'Swap' | awk '{print $3}'`    # Swap used
RAM7=`free -h | grep 'Swap' | awk '{print $4}'`    # Swap free

# IP-Adressen ermitteln
if ( ifconfig | grep -q "br0" ) ; then IP_LAN=`ifconfig br0 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_LAN="---" ; fi ;
if ( ifconfig | grep -q "eth0" ) ; then IP_WLAN=`ifconfig eth0 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_WLAN="---" ; fi ;
if ( ifconfig | grep -q "ztr2qtgtyt" ) ; then IP_ZLAN=`ifconfig ztr2qtgtyt | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_WLAN="

# Ausgabe
echo -e "\033[0;37m
\033[0;37m  ~~~~~~~~~~~~~~~~
\033[0;37m |                |  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
\033[0;37m |                |  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
\033[0;37m |                |  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
\033[0;37m |                |  Ø Auslastung..: \033[1;33m$LOAD1\033[0;37m (1 Min.) | \033[1;33m$LOAD2\033[0;37m (5 Min.) | \033[1;33m$LOAD3\033[0;3
\033[0;37m |                |  Temperaturen..: 2.4ghz: \033[1;33m$TEMP1\033[0;37m °C 5ghz: \033[1;33m$TEMP2\033[0;37m °C
\033[0;37m |                |  Speicher......: Gesamt: \033[1;32m\033[1;36m$DISK1\033[0;37m | Belegt: $DISK2 | Frei: \033[32m$DISK3\033[0;37m
\033[0;37m |                |  RAM...........: Gesamt: \033[1;32m\033[1;36m$RAM1\033[0;37m | Belegt: $RAM2 | Frei: \033[32m$RAM3\033[0;37m | Cache:
\033[0;37m |                |  Swap..........: Gesamt: \033[1;32m\033[1;36m$RAM5\033[0;37m | Belegt: $RAM6 | Frei: \033[32m$RAM7\033[0;37m
\033[0;37m | $MODELL_TYPE |  IP-Adressen...: LAN: \033[1;35m$IP_LAN\033[0;37m | Vodafone: \033[1;35m$IP_WLAN\033[0;37m | Zerotier: \033[1;35m$IP_ZL
\033[0;37m  ~~~~~~~~~~~~~~~~
\033[m