




alias rc="raspi-config"

alias wifi="ifconfig" #: To check the status of the wireless connection you are using  (to see if wlan0 has acquired an IP address).
alias wifi_net="iwconfig" #: To check which network the wireless adapter is using.
alias wifi_list="iwlist wlan0 scan" #: Prints a list of the currently available wireless networks.
alias wifigr="iwlist wlan0 scan | grep "# ESSID: Use grep along with the name of a field to list only the fields you need (for example to just list the ESSIDs).
#nmap: Scans your network and lists connected devices, port number, protocol, state (open or closed) operating system, MAC addresses, and other information.