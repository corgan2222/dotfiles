# ------------------------------------------------------------------------------
# | Proxmox VE                                                                 |
# ------------------------------------------------------------------------------

# version / cluster
alias pvever='pveversion -v'
alias pvestat='pvecm status'
alias pvenodes='pvecm nodes'
alias pvereport='pvereport'

# storage
alias pvestor='pvesm status'
alias pvepools='pvesh get /pools'

# container (LXC) shortcuts
alias ctl='pct list'
alias ctstart='pct start'
alias ctstop='pct stop'
alias ctshut='pct shutdown'
alias ctenter='pct enter'
alias ctcfg='pct config'

# vm (KVM) shortcuts
alias vml='qm list'
alias vmstart='qm start'
alias vmstop='qm stop'
alias vmshut='qm shutdown'
alias vmcfg='qm config'
alias vmmon='qm monitor'

# backups
alias pvebackup='vzdump --mode snapshot --compress zstd'
alias pvebackuplist='ls -lah /var/lib/vz/dump/ 2>/dev/null'

# logs
alias logsPve='lnav /var/log/pve/'
alias logsPveTasks='ls -lt /var/log/pve/tasks | head'
alias logsCluster='journalctl -u pve-cluster -f'
alias logsFirewall='journalctl -u pve-firewall -f'

# services
alias pverestart='systemctl restart pveproxy pvedaemon pvestatd'
alias pvereload='systemctl reload-or-restart pveproxy'
alias pvestatus='systemctl status pveproxy pvedaemon pvestatd pve-cluster'

# navigation
alias cd_pve='cd /etc/pve'
alias cd_pveqemu='cd /etc/pve/qemu-server'
alias cd_pvelxc='cd /etc/pve/lxc'
alias cd_pvenodes='cd /etc/pve/nodes'
alias cd_pveha='cd /etc/pve/ha'
alias cd_pvebackup='cd /var/lib/vz/dump'
alias cd_pveiso='cd /var/lib/vz/template/iso'
alias cd_pvect='cd /var/lib/vz/template/cache'

# ceph (only meaningful when ceph is installed)
alias cephs='ceph -s'
alias cephw='ceph -w'
alias cephdf='ceph df'
alias cephosd='ceph osd tree'

# python / common
alias py3='python3'
alias py='py3'
alias p3='py3'
alias p='py3'

alias bd=". bd -s"
alias eachdir=". eachdir"

alias grep='grep --color=auto'

function help_(){
echo -e "
\e[0;32m h \e[0m \e[0;34m#search a+c+f\e[0m
\e[0;32m a \e[0m \e[0;34m#search aliases\e[0m
\e[0;32m c \e[0m \e[0;34m#search cheats\e[0m
\e[0;32m f \e[0m \e[0;34m#search functions\e[0m
\e[0;32m s \e[0m \e[0;34m#savehome\e[0m
\e[0;32m l \e[0m \e[0;34m#loadhome\e[0m
\e[0;32m ctl \e[0m \e[0;34m#list LXC containers\e[0m
\e[0;32m vml \e[0m \e[0;34m#list KVM VMs\e[0m
\e[0;32m pvever \e[0m \e[0;34m#pve version verbose\e[0m
\e[0;32m pvestat \e[0m \e[0;34m#cluster status\e[0m
"
}
