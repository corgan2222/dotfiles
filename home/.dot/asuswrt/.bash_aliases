# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------


alias ap='opkg install '
alias apuu='opkg update'
alias aptList="opkg list"


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