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

#nmap: Scans your network and lists connected devices, port number, protocol, state (open or closed) operating system, MAC addresses, and other information.