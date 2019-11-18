# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------


alias ap='opkg install '
alias apuu="opkg list-upgradable | awk '\{ print $1; \}' | xargs opkg upgrade"
unalis aptList
alias aptList="/bin/bash /root/.dot/asuswrt/EntwareApps.sh"
unalis aptgetUpgradable
alias aptgetUpgradable="opkg list-upgradable"
#https://bin.entware.net/mipselsf-k3.4/Packages.html

alias wifi_sta_info='( [ -z "$WL" ] && WL="wl"; set -- `$WL assoclist` ; while [ _$1 = _assoclist ] ; do wl sta_info $2 ; shift 2 ; done )'
alias wifi_sta_info7='( [ -z "$WL" ] && WL="wl"; set -- `$WL -i eth7 assoclist` ; while [ _$1 = _assoclist ] ; do wl sta_info $2 ; shift 2 ; done )'
alias pktq_stats='( [ -z "$WL" ] && WL="wl"; STAS="C:" ; set -- `$WL assoclist` ; while [ _$1 = _assoclist ] ; do STAS="$STAS A:$2" ; shift 2 ; done ; $WL pktq_stats $STAS )'
alias wlver='$WL ver; $WL cap; $WL revinfo; $WL status; $WL assoclist'

alias asus_temp1=$(wl -i eth6 phy_tempsense | awk '{ print $1 * .5 + 20 }')
alias asus_temp2=$(wl -i eth7 phy_tempsense | awk '{ print $1 * .5 + 20 }')
alias ipLeases="cat /var/lib/misc/dnsmasq.leases"

alias tcp_dump_port_53="tcpdump -i eth0 -p port 853 or 53 -n"

function help(){
echo '        
Folders:
/jffs/,
/mnt/
/jffs/scripts/ 

Openvpn
  /jffs/configs/openvpn/ccd1/
  /jffs/configs/openvpn/ccd2/

  Configs
  /jffs/configs/dnsmasq.conf.add
  
  https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts

    adisk.service
    afpd.service
    avahi-daemon.conf
    dhcp6s.conf
    dnsmasq.conf
    exports (only exports.add supported)
    fstab (only fstab supported, remember to create mount point through init-start first if it doesnt exist!)
    group, gshadow, passwd, shadow (only .add versions supported)
    hosts (for /etc/hosts)
    igmpproxy.conf
    inadyn.conf
    minidlna.conf
    mt-daap.service
    nanorc (no .add support) - as documented here (External page). 384.3 or newer.
    pptpd.conf
    profile (shell profile, only profile.add supported)
    smb.conf
    snmpd.conf
    stubby.yml (only stubby.yml.add supported)
    torrc
    vsftpd.conf
    upnp (for miniupnpd)

'
    }