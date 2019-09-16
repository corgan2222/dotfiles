#!/usr/bin/env bash

function help(){
echo '        
    cat /proc/meminfo: Shows details about your memory.
    cat /proc/partitions: Shows the size and number of partitions on your SD card or hard drive.
    cat /proc/version: Shows you which version of the Raspberry Pi you are using.
    df -h: Shows information about the available disk space.
    df /: Shows how much free disk space is available.
    dpkg – –get–selections | grep XXX: Shows all of the installed packages that are related to XXX.
    dpkg – –get–selections: Shows all of your installed packages.
    free: Shows how much free memory is available.
    hostname -I: Shows the IP address of your Raspberry Pi.
    lsusb: Lists USB hardware connected to your Raspberry Pi.
    UP key: Pressing the UP key will print the last command entered into the command prompt. This is a quick way to repeat previous commands or make corrections to commands.
    vcgencmd measure_temp: Shows the temperature of the CPU.
    vcgencmd get_mem arm && vcgencmd get_mem gpu: Shows the memory split between the CPU and GPU.
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    600000
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    1500000 (bisher 1400000)
    vcgencmd get_config sdram_freq # RAM
    sdram_freq=0 (bisher 500)
    vcgencmd get_config core_freq # Video Core
    core_freq=500 (bisher 400)
    vcgencmd get_config gpu_freq # 3D-Core
    gpu_freq=500 (bisher 300)    
'
    }
    
function install_extFileSystems()
{
    sudo apt-get update
    sudo apt-get install exfat-fuse ntfs-3g lsof
}   