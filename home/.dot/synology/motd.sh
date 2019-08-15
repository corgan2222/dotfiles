#!/bin/sh
# dynamische MOTD
# Aufruf in .bashrc

echo -e "\033[31m"
cat << "EOF" 
                                   _____
   _____ ___   _____ _   __ ____ _|__  /
  / ___// _ \ / ___/| | / // __ `/ /_ < 
 (__  )/  __// /    | |/ // /_/ /___/ / 
/____/ \___//_/     |___/ \__,_//____/  
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

# CPU Temperaturen
#cnt=0; TEMP=0
#for FILE in `ls /sys/devices/platform/coretemp.0/hwmon/hwmon0/temp?_input`; do
#    TEMP=$[TEMP + $(cat "${FILE}")]
#    cnt=$[cnt+1]
#done
#TEMP=$[TEMP/cnt/1000]

#find /sys/devices/platform -name temp?_input
#CPU Temperaturen
for (( c=1; c<=10; c++))
do
    if [ -e /sys/devices/platform/coretemp.0/'temp'$c'_input' ]
        then
        loop=$[loop+1]
        sens[$loop]=$[c]
        #echo -n 'temp'${sens[$loop]}' ' 
    fi
done
    # Disk/Rack-Station Thermal-Status
    T_CPU=`snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.1.2.0`" "

    # Disk Temperature
    #echo `snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6` > T_HD[]
    #cat $T_HD


input=($(find /sys/devices/platform -name temp?_input))
for (( m=0; m<${#input[@]}; m++ )); do
   TEMP=$[TEMP + $(cat "${input[m]}")]
done
TEMP=$[TEMP/1000/m]

# HDD Temperaturen
#sdatemp=$(smartctl -d ata -a /dev/sda | grep "194 Temperature" | cut -c 129-130)
#sdbtemp=$(smartctl -d ata -a /dev/sdb | grep "194 Temperature" | cut -c 129-130)

sdatemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.0)
sdbtemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.1)
sdctemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.2)
sddtemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.3)
sdetemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.4)
sdftemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.5)
sdgtemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.6)
sdhtemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.7)
#sditemp=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 1.3.6.1.4.1.6574.2.1.1.6.8)

#"Volume 1" "Storage Pool 1" 13 13 11331124744192 268435456 65253266329600 67972433444864
raid=$(snmpwalk -v 2c  -c syno -O qv 127.0.0.1 .1.3.6.1.4.1.6574.3)
raid_name=`echo $raid | awk '{print $1 $2}'`
raid_stat_number=`echo $raid | awk '{print $6}'` 

RStat[1]="\033[32m RAID is functioning normally"
RStat[2]="\e[5m\e[31m Migrating"
RStat[3]="\e[5m\e[31m Expanding"
RStat[4]="\e[5m\e[31m Deleting"
RStat[5]="\e[5m\e[31m Creating"
RStat[6]="\e[5m\e[31m RaidSyncing"
RStat[7]="\e[5m\e[31m RaidParityChecking"
RStat[8]="\e[5m\e[31m RaidAssembling"
RStat[9]="\e[5m\e[31m Canceling"
RStat[10]="\e[5m\e[31m These statuses are shown when RAID is created or deleted"
RStat[11]="\e[5m\e[31m Degrade is shown when a tolerable failure of diskRStat[s]= occursCrashed"
RStat[12]="\e[5m\e[31m RAID has crashed and is now read-onlyDataScrubbing "
RStat[13]="\e[5m\e[31m RAID is DataScrubbingRaidDeploying - Repairing! \e[25m "
RStat[14]="\e[5m\e[31m RAID is deploying Single volume on poolRaidUnDeploying "
RStat[15]="\e[5m\e[31m RAID is not deploying Single volume on poolRaidMountCache "
RStat[16]="\e[5m\e[31m RAID is mounting SSD cacheRaidUnmountCache "
RStat[17]="\e[5m\e[31m RAID is not mounting SSD cacheRaidExpandingUnfinishedSHR "
RStat[18]="\e[5m\e[31m RAID continue expanding SHR if interruptedRaidConvertSHRToPool "
RStat[19]="\e[5m\e[31m RAID is converting Single volume on SHR to multiple volume on SHRRaidMigrateSHR1ToSHR2 "
RStat[20]="\e[5m\e[31m RAID is migrating SHR1 to SHR2RaidUnknownStatus "
RStat[21]="\e[5m\e[31m RaidUnknownStatus (21)"

echo -e "Raid: \033[1;33m$raid_name\033[0;37m Status: $raid_stat_number ${RStat[$raid_stat_number]}"

# Speicherbelegung
DISK1=`df -h | grep '/volume1/photo' | awk '{print $2}'`    # Gesamtspeicher
DISK2=`df -h | grep '/volume1/photo' | awk '{print $3}'`    # Belegt
DISK3=`df -h | grep '/volume1/photo' | awk '{print $4}'`    # Frei

# Arbeitsspeicher
RAM1=`free -h | grep 'Mem' | awk '{print $2}'`    # Total
RAM2=`free -h | grep 'Mem' | awk '{print $3}'`    # Used
RAM3=`free -h | grep 'Mem' | awk '{print $4}'`    # Free
RAM4=`free -h | grep 'Mem' | awk '{print $6}'`    # Cache
RAM5=`free -h | grep 'Swap' | awk '{print $2}'`    # Swap Total
RAM6=`free -h | grep 'Swap' | awk '{print $3}'`    # Swap used
RAM7=`free -h | grep 'Swap' | awk '{print $4}'`    # Swap free

# IP-Adressen ermitteln
if ( ifconfig | grep -q "ovs_eth4" ) ; then IP_LAN=`ifconfig ovs_eth4 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_LAN="---" ; fi ;
if ( ifconfig | grep -q "eth50" ) ; then IP_WLAN=`ifconfig eth50 | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1` ; else IP_WLAN="---" ; fi ;

# Ausgabe
echo -e "\033[0;37m
\033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
\033[0;37m |  \033[32m1\033[0;37m   \033[32m2\033[0;37m  \033[32m3\033[0;37m   \033[32m4\033[0;37m   \033[32m5\033[0;37m   \033[32m6\033[0;37m   \033[32m7\033[0;37m   \033[32m8\033[0;37m |  Datum.........: \033[1;32m\033[1;36m$DATUM\033[0;37m
\033[0;37m | \033[1;33m$sdatemp\033[0;37m  \033[1;33m$sdbtemp\033[0;37m  \033[1;33m$sdctemp\033[0;37m \033[1;33m$sddtemp\033[0;37m  \033[1;33m$sdetemp\033[0;37m  \033[1;33m$sdftemp\033[0;37m  \033[1;33m$sdhtemp\033[0;37m  \033[1;33m$sditemp\033[0;37m \033[32m°C\033[0;37m|  Hostname......: \033[1;33m$HOSTNAME\033[0;37m
\033[0;37m |                              \033[32m-\033[0;37m|  Uptime........: $UP1 Tage, $UP2:$UP3 Stunden
\033[0;37m |                              \033[32m-\033[0;37m|  Ø Auslastung..: \033[1;33m$LOAD1\033[0;37m (1 Min.) | \033[1;33m$LOAD2\033[0;37m (5 Min.) | \033[1;33m$LOAD3\033[0;37m (5 Min.) (15 Min.)
\033[0;37m |                               |  Temperaturen..: CPU: \033[1;33m$T_CPU\033[0;37m °C 
\033[0;37m |                            \033[34m[]\033[0;37m |  Speicher......: Gesamt: \033[1;32m\033[1;36m$DISK1\033[0;37m | Belegt: $DISK2 | Frei: \033[32m$DISK3\033[0;37m
\033[0;37m |                            \033[0;32m(c)\033[0;37m|  RAM...........: Gesamt: \033[1;32m\033[1;36m$RAM1\033[0;37m | Belegt: $RAM2 | Frei: \033[32m$RAM3\033[0;37m | Cache: $RAM4
\033[0;37m |                            \033[34m(\033[31m'\033[34m)\033[0;37m|  Swap..........: Gesamt: \033[1;32m\033[1;36m$RAM5\033[0;37m | Belegt: $RAM6 | Frei: \033[32m$RAM7\033[0;37m
\033[0;37m | $MODELL_TYPE                       |  IP-Adressen...: LAN: \033[1;35m$IP_LAN\033[0;37m | Zerotier: \033[1;35m$IP_WLAN\033[0;37m
\033[0;37m  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
\033[m"

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