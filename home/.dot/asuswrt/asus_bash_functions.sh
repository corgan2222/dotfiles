norefresh=1

function wifiClients()
{
    #! /bin/ash
    for x in `wl assoclist | awk '{print $2}'`
    do
    echo "------------------------------------------------------"
    wl sta_info $x
    echo -e "\t ---"
    grep $x /proc/net/arp | awk '{print "\t IP: "$1" (from ARP table)"}'
    grep -i $x /var/lib/misc/dnsmasq.leases | awk '{print "\t IP: "$3" (from DHCP Lease)\n\t NAME: "$4" (from DHCP Lease)"}'
    done
    echo "------------------------------------------------------"
}