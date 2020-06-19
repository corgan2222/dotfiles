#!/usr/bin/env bash

function f_userHome_save()
{
    FROM = "$HOME/"
    TO = "/mnt/user/source/user-sync/$USER"

    echo "sync from  $FROM to $TO"
    mkdir -p $TO
    mkdir -p /mnt/user/source/user-sync/$USER
    rsync -a $FROM $TO
    rsync -a $HOME/ /mnt/user/source/user-sync/$USER
}

function f_userHome_restore()
{

}

function help_(){
echo -e "
\e[0;32m h \e[0m \e[0;34m#search a+c+f\e[0m
\e[0;32m a \e[0m \e[0;34m#search aliases\e[0m
\e[0;32m c \e[0m \e[0;34m#search cheats\e[0m
\e[0;32m f \e[0m \e[0;34m#search functions\e[0m
\e[0;32m s \e[0m \e[0;34m#savehome\e[0m
\e[0;32m l \e[0m \e[0;34m#loadhome\e[0m
\e[0;32m eg \e[0m \e[0;34m#search eg cheats\e[0m
plesk bin <utility name> [parameters] [options]
"
    }

W="\e[0;39m"
G="\e[1;32m"

function help_unraid(){
echo -e "
    $G cat /proc/meminfo $W \t Shows details about your memory.
    $G cat /proc/partitions $W \t Shows the size and number of partitions on your SD card or hard drive.
    $G cat /proc/version $W \t Shows you which version of the Raspberry Pi you are using.
    $G df -h $W \t Shows information about the available disk space.
    $G df / $W \t Shows how much free disk space is available.
    $G free $W \t Shows how much free memory is available.
    $G hostname -I $W \t Shows the IP address
    $G lsusb $W \t Lists USB hardware connected

    Nerdpack System:
    $G fd $W \t find $W
    $G atop $W \t systemInfo $W
    $G bashtop $W \t systemInfo $W
    $G dstat $W \t systemInfo  $W
    Nerdpack Docker:
    $G ctop $W \t container metrics (needs root) $W
    Nerdpack Network:
    $G iftop $W \t Network Traffic (needs root) $W
    $G nload $W \t Network Traffic $W
    $G bwm-ng $W \t Bandwidth Monitor per Interface$W
    $G iperf $W \t Traffic Benchmark $W
    $G nvstat $W \t Network Traffic monitor  $W
    Nerdpack Filesystem:
    $G iotop $W \t I/O usage information $W
    $G ncdu $W \t Disk Usage Analyze $W

"

    }