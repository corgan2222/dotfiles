alias rc="raspi-config"
alias wifi="ifconfig" 
#: To check the status of the wireless connection you are using  (to see if wlan0 has acquired an IP address).
alias wifi_net="iwconfig" 
#: To check which network the wireless adapter is using.
alias wifi_list="iwlist wlan0 scan" 
#: Prints a list of the currently available wireless networks.
alias wifigr="iwlist wlan0 scan | grep "
# ESSID: Use grep along with the name of a field to list only the fields you need 

alias swapInfo="sudo service dphys-swapfile status"
alias swapOFF="sudo swapoff -a"
alias swapON="sudo swapon -a"
alias swapEdit="sudo joe /etc/dphys-swapfile"
alias swapSTOP="sudo service dphys-swapfile stop"
alias swapSTART="sudo systemctl start dphys-swapfile"
alias swapDISABLE="sudo systemctl disable dphys-swapfile"
alias swapINSTALL="sudo apt-get install dphys-swapfile"

alias dp="sudo blkid"
#nmap: Scans your network and lists connected devices, port number, protocol, state (open or closed) operating system, MAC addresses, and other information.

alias pi_info_boardversion='sudo cat /proc/cpuinfo | grep Hardware | tr -d " " | cut -d ":" -f 2' # get the Hardware Version                
alias pi_info_boardserialnumber="sudo cat /proc/cpuinfo | grep Serial | tr -d " " | cut -d ":" -f 2" # get the Board unique Serial Number                
alias pi_info_cpuvoltage='sudo /opt/vc/bin/vcgencmd measure_volts | tr -d "volt=" | tr -d "V"'
alias pi_info_cpuclock='sudo /opt/vc/bin/vcgencmd measure_clock arm | cut -d'='  -f 2-' # CPU Clock Speed in Hz                
alias pi_info_cpumem='sudo vcgencmd get_mem arm | tr -d "arm=" | tr -d "M"' # CPU Memory in MByte                
alias pi_info_firmwareversion='sudo vcgencmd version | grep version | cut -d " " -f 2' # Just the naked String of the firmware Version                
alias pi_info_gpumem='sudo vcgencmd get_mem gpu | tr -d "gpu=" | tr -d "M"' # Graphics memeory in MByte                
alias pi_info_sdcardtotalsize='sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 2' # Size of SD-Card in KByte                
alias pi_info_sdcardused='sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 3' # Used Diskspace in KByte                
alias pi_info_sdcardusedpercent='sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 5' # Used Diskspace in Percent                
alias pi_info_sdcardfree='sudo df -P | grep /dev/root | tr -s " " " " | cut -d " " -f 4' # free Diskspace in KByte                
alias pi_info_temperature='sudo cat /sys/class/thermal/thermal_zone*/temp' # Temperature in 1/1000 centigrade
                
                