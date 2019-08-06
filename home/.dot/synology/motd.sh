#!/bin/sh
# dynamische MOTD
# Aufruf in .bashrc

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

# CPU Temperaturen
#cnt=0; TEMP=0
#for FILE in `ls /sys/devices/platform/coretemp.0/hwmon/hwmon0/temp?_input`; do
#    TEMP=$[TEMP + $(cat "${FILE}")]
#    cnt=$[cnt+1]
#done
#TEMP=$[TEMP/cnt/1000]

#find /sys/devices/platform -name temp?_input
# CPU Temperaturen
#input=($(find /sys/devices/platform -name temp?_input))
#for (( m=0; m<${#input[@]}; m++ )); do
#    TEMP=$[TEMP + $(cat "${input[m]}")]
#done
#TEMP=$[TEMP/1000/m]

# HDD Temperaturen
#sdatemp=$(smartctl -d ata -a /dev/sda | grep "194 Temperature" | cut -c 129-130)
#sdbtemp=$(smartctl -d ata -a /dev/sdb | grep "194 Temperature" | cut -c 129-130)
sdatemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.0)
sdbtemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.1)


# Speicherbelegung
DISK1=`df -h | grep 'dev/vg1000/lv' | awk '{print $2}'`    # Gesamtspeicher
DISK2=`df -h | grep 'dev/vg1000/lv' | awk '{print $3}'`    # Belegt
DISK3=`df -h | grep 'dev/vg1000/lv' | awk '{print $4}'`    # Frei

# Arbeitsspeicher
RAM1=`free -h | grep 'Mem' | awk '{print $2}'`    # Total
RAM2=`free -h | grep 'Mem' | awk '{print $3}'`    # Used
RAM3=`free -h | grep 'Mem' | awk '{print $4}'`    # Free
RAM4=`free -h | grep 'Mem' | awk '{print $6}'`    # Cache
RAM5=`free -h | grep 'Swap' | awk '{print $2}'`    # Swap Total
RAM6=`free -h | grep 'Swap' | awk '{print $3}'`    # Swap used
RAM7=`free -h | grep 'Swap' | awk '{print $4}'`    # Swap free

# IP-Adressen ermitteln
if ( ifconfig | grep -q "eth0" ) ; then IP_LAN=`ifconfig eth0 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_LAN="---" ; fi ;
if ( ifconfig | grep -q "wlan0" ) ; then IP_WLAN=`ifconfig wlan0 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_WLAN="---" ; fi ;

# Ausgabe
echo -e "\033[0;37m
\033[0;37m  ~~~~~~~~~~~~
\033[0;37m |           \033[32m-\033[0;37m|  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
\033[0;37m |           \033[32m-\033[0;37m|  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
\033[0;37m |           \033[32m-\033[0;37m|  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
\033[0;37m |           \033[32m-\033[0;37m|  Ø Auslastung..: $LOAD1 (1 Min.) | $LOAD2 (5 Min.) | $LOAD3 (15 Min.)
\033[0;37m |            |  Temperaturen..: CPU: $TEMP °C | HDD1: $sdatemp °C | HDD2: $sdbtemp °C
\033[0;37m |         \033[34m[]\033[0;37m |  Speicher......: Gesamt: $DISK1 | Belegt: $DISK2 | Frei: $DISK3
\033[0;37m |         \033[0;32m(c)\033[0;37m|  RAM...........: Gesamt: $RAM1 | Belegt: $RAM2 | Frei: $RAM3 | Cache: $RAM4
\033[0;37m |         \033[34m(\033[31m'\033[34m)\033[0;37m|  Swap..........: Gesamt: $RAM5 | Belegt: $RAM6 | Frei: $RAM7
\033[0;37m | DS218+     |  IP-Adressen...: LAN: \033[1;35m$IP_LAN\033[0;37m | WiFi: \033[1;35m$IP_WLAN\033[0;37m
\033[0;37m  ~~~~~~~~~~~~
\033[m"