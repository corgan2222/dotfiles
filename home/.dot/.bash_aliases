#!/bin/bash
# https://github.com/voku/dotfiles


# ------------------------------------------------------------------------------
# | Defaults                                                                   |
# ------------------------------------------------------------------------------
alias scriptinfo="grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)'"

# short names only where no program of that name exists: an alias hides the program in the shell (28.10.26)
if ! type -P c >/dev/null; then
  alias c="cheat "
fi
alias cl="cheat -l"
alias a="alias | grep "
alias f="scriptInfoPerl | grep "
alias s="saveHome"
alias l="loadHome"
# menu of all installers that fit this system
alias installer="bash ~/.dot/installer/installer.sh"
alias keyboardDE="setxkbmap -layout de"

# reload the shell (i.e. invoke as a login shell)
alias reload='exec "$SHELL" -l'
#alias load='source ~/.bashrc && source ~/.dot/.bash_aliases && source ~/.dot/.bash_functions.sh'
alias load='source "$HOME"/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh && homeshick link'

alias logs_multi_all="multitail --mergeall /var/log/*log --no-mergeall"
alias logs_lnav_all="lnav /var/log"
alias logsTelegraf="logs telegraf"
alias logsGrafana="logs grafana"
alias logsInflux="logs influxdb"
# Debian family: apache2 and mysql, Fedora and the RHEL family: httpd and mariadb
if [ -d /var/log/httpd ]; then alias logsApache="logs httpd"; else alias logsApache="logs apache2"; fi
if [ -d /var/log/mariadb ]; then alias logsMysql="logs mariadb"; else alias logsMysql="logs mysql"; fi
alias logsMongodb="logs mongodb"
alias logsNeo4j="logs neo4j"
alias logsNginx="logs nginx"

# service specific aliases are only defined when the service is installed
if command -v plesk >/dev/null 2>&1; then
  alias logsPlesk-php73-fpm="logs plesk-php73-fpm"
  alias pleskReadPhpHandler="plesk bin php_handler --reread"
  alias peclPhp70Install="/opt/plesk/php/7.0/bin/pecl install "
  alias peclPhp71Install="/opt/plesk/php/7.1/bin/pecl install "
  alias peclPhp72Install="/opt/plesk/php/7.2/bin/pecl install "
  alias peclPhp73Install="/opt/plesk/php/7.3/bin/pecl install "
  alias pleskRestart="service sw-engine restart && service sw-cp-server restart"
  alias pleskCertsList="la -la /usr/local/psa/var/modules/letsencrypt/etc/live/"
fi

if command -v zabbix_server >/dev/null 2>&1; then
  alias zabbix_server_reload="zabbix_server -R config_cache_reload"
fi
# ------------------------------------------------------------------------------
# | sudo                                                                       |
# ------------------------------------------------------------------------------

# root without sudo (Proxmox, Debian LXC, Alpine): the aliases and functions here call sudo, so run the command
# directly (28.10.26: apuu said "sudo: command not found" as root on Debian 12). "function sudo" keeps the name
# from alias expansion on a reload; -u <user> goes through runuser, options without meaning for root are dropped.
if [ "${EUID:-}" = 0 ] && ! type -P sudo >/dev/null; then
  function sudo {
    local u=
    while [ $# -gt 0 ]; do
      case $1 in
        --) shift; break ;;
        -u) [ $# -ge 2 ] || { echo "sudo: -u needs a user" >&2; return 1; }; u=$2; shift 2 ;;
        --user=*) u=${1#*=}; shift ;;
        --preserve-env*|--non-interactive) shift ;;
        -*)
          [[ $1 =~ ^-[EHnSkPA]+$ ]] || { echo "sudo: $1: not supported without sudo" >&2; return 1; }
          shift ;;
        *) break ;;
      esac
    done
    # sudo FOO=1 cmd: leading assignments go through env
    local vars=()
    while [[ ${1:-} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do vars+=("$1"); shift; done
    [ $# -gt 0 ] || { echo "usage: sudo [-u user] command" >&2; return 1; }
    [ ${#vars[@]} -eq 0 ] || set -- env "${vars[@]}" "$@"
    case $u in
      ''|root|0|'#0') "$@" ;;
      *)
        type -P runuser >/dev/null || { echo "sudo: no runuser here for -u $u" >&2; return 1; }
        runuser -u "$u" -- "$@" ;;
    esac
  }
fi
# Enable simple aliases to be sudo'ed. ("sudone"?)
alias sudo='sudo '
alias joe='joe -nodeadjoe -nobackups -noexmsg '
# vi -> joe only with joe installed, else "vi" and "sudo vi" (alias sudo='sudo ') found no editor (28.10.26)
if type -P joe >/dev/null; then
  alias vi='joe'
fi
alias hmm='apropos '

# ------------------------------------------------------------------------------

alias mkdir="mkdir -p"
alias md="mkdir"
alias rmd='rm -r'
alias rd="rmdir"
# create a dir with date from today
alias mkdd='mkdir $(date +%Y%m%d)'
# lsb_release is missing on Fedora, Arch, Alpine and minimal images; os-release is everywhere
alias linuxversion='lsb_release -a 2>/dev/null || cat /etc/os-release'


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
# plain "python" is gone on current distros unless python-is-python3 is installed
if command -v python >/dev/null 2>&1; then alias p=python; else alias p=python3; fi

alias cx="chmod +x "
alias bd=". bd -s"
alias eachdir='. "$HOME"/.dot/eachdir'

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
# list only directories (named lsdir, an alias dd would hide the dd command)
alias lsdir='ls -d */'

# ls replacement: eza, or its unmaintained predecessor exa on older systems
_ls_tool=; if command -v eza >/dev/null 2>&1; then _ls_tool=eza; elif command -v exa >/dev/null 2>&1; then _ls_tool=exa; fi
if [ -n "$_ls_tool" ]; then

  alias d="$_ls_tool --long --header --git -g"
  alias da="$_ls_tool --long --header --git -g -all"
  alias dt="$_ls_tool --long --header --git -T -g"
  alias lsdir="$_ls_tool --long --header --git -d */"
fi
unset _ls_tool
# lsd next to it, ls and the aliases above stay with eza
if command -v lsd >/dev/null 2>&1; then
  alias lsdl='lsd -l'
fi
# glow renders Markdown; md is mkdir already
if command -v glow >/dev/null 2>&1 && ! command -v mdv >/dev/null 2>&1; then
  alias mdv='glow'
fi

alias user-ls='cat /etc/passwd'
alias groups-ls="getent group"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

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
if command -v ack-grep >/dev/null 2>&1; then
  alias ack="ack-grep"
  alias afind="ack-grep -iH"
else
  alias afind="ack -iH"
fi

alias findLastFile="find . -type f -printf \"%T@ %p\n\" | sort -n | cut -d' ' -f 2- | tail -n 1 | xargs -d'\n' ls -la"

# ------------------------------------------------------------------------------
# | services                                                                   |
# ------------------------------------------------------------------------------


# "service" (sysvinit-utils) is missing on Arch and Fedora; systemd lists the same
if PATH=$PATH:/usr/sbin:/sbin command -v service >/dev/null 2>&1; then
  alias list_services="sudo service --status-all"
elif command -v rc-status >/dev/null 2>&1; then
  alias list_services="rc-status --all" # OpenRC: Alpine
elif command -v systemctl >/dev/null 2>&1; then
  alias list_services="systemctl list-units --type service --all"
else
  alias list_services="ls /etc/init.d" # no service manager running (containers, busybox)
fi
alias list_services_startup="systemctl list-units --type service"
alias list_services_all="systemctl list-units --type service --all"
alias list_services_tree="systemctl list-dependencies --type service"
alias list_services_locate="locate "
alias list_PortsLocalhostNmap="sudo nmap -T4 -v 127.0.0.1"
alias list_PortsLocalhostLsof="sudo lsof -Pnl +M -i4"

if command -v systemctl >/dev/null 2>&1; then
  alias check_servic_isActive="systemctl is-active "
  alias check_servic_isActive_onBoot="systemctl is-enabled "
  alias disable_mask_service="systemctl mask "
  alias disable_service="systemctl disable "
  alias enable_service="systemctl enable "
fi


# ------------------------------------------------------------------------------
# | Packages: the same names on every system, mapped to its package manager    |
# ------------------------------------------------------------------------------
# DOT_PKG comes from lib/detect.sh (core.sh). Commands a package manager does not have stay undefined there.

case $DOT_PKG in
  apt)
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
    alias apSearch='apt-cache search '
    alias apuu='sudo apt-get update && sudo apt-get -y upgrade'
    alias aptGetVersion="dpkg -l | grep -i "
    alias aptList="dpkg -l"
    alias aptReconf="sudo dpkg-reconfigure "
    alias aptListAll_names="dpkg-query -W -f '\${Package}\n'"
    alias aptListAll_Path="apt list --installed"
    alias aptListSources="apt-cache policy | grep http | awk '{print \$2, \$3}' | sort -u"
    command -v aptitude >/dev/null 2>&1 && alias aptChangelog="aptitude changelog " &&
      alias aptSourcesSize="aptitude -O installsize -F'%p %I' search '~i'"
    # Debian 12+ and Ubuntu 24.04+ keep their sources as deb822 files in sources.list.d, sources.list may be gone
    alias aptListSourcesList="cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null"
    alias aptEditSourcesList='sudo "${EDITOR:-nano}" $(ls /etc/apt/sources.list /etc/apt/sources.list.d/{debian,ubuntu}.sources 2>/dev/null | head -n 1)'
    alias aptListSourcesD="ls -la /etc/apt/sources.list.d/"
    alias aptgetAppInfos_fromthis="apt-cache policy "
    alias cd_Aptlist='cd /etc/apt/'
    ;;
  dnf|yum)
    alias ap="sudo $DOT_PKG install"
    alias apr="sudo $DOT_PKG remove"
    alias apAutoremove="sudo $DOT_PKG autoremove"
    alias apPurge="sudo $DOT_PKG remove"
    alias apRemovePurge="sudo $DOT_PKG remove"
    alias apClean="sudo $DOT_PKG clean all"
    alias apAutoclean="sudo $DOT_PKG clean packages"
    alias apDownload="$DOT_PKG download "
    alias apChangelog="$DOT_PKG changelog "
    alias apBuildDep="sudo $DOT_PKG builddep "
    alias apCheck="$DOT_PKG check"
    alias apSearch="$DOT_PKG search "
    alias apuu="sudo $DOT_PKG -y upgrade --refresh"
    alias aptGetVersion="rpm -qa | grep -i "
    alias aptList="rpm -qa | sort"
    alias aptListAll_names="rpm -qa --qf '%{NAME}\n' | sort"
    alias aptListAll_Path="$DOT_PKG list --installed"
    alias aptListSources="$DOT_PKG repolist"
    alias aptListSourcesD="ls -la /etc/yum.repos.d/"
    alias aptgetAppInfos_fromthis="$DOT_PKG info "
    ;;
  pacman)
    alias ap='sudo pacman -S --needed'
    alias apr='sudo pacman -R'
    alias apAutoremove='pacman -Qdtq | sudo pacman -Rns -'
    alias apPurge='sudo pacman -Rns'
    alias apRemovePurge='sudo pacman -Rns'
    alias apClean='sudo pacman -Scc'
    alias apAutoclean='sudo pacman -Sc'
    alias apCheck='pacman -Qk'
    alias apSearch='pacman -Ss '
    alias apuu='sudo pacman -Syu'
    alias aptGetVersion="pacman -Q | grep -i "
    alias aptList="pacman -Q"
    alias aptListAll_names="pacman -Qq"
    alias aptListAll_Path="pacman -Q"
    alias aptListSources="grep -E '^\s*Server' /etc/pacman.d/mirrorlist"
    alias aptgetAppInfos_fromthis="pacman -Si "
    ;;
  zypper)
    alias ap='sudo zypper install'
    alias apr='sudo zypper remove'
    alias apAutoremove='sudo zypper remove --clean-deps'
    alias apPurge='sudo zypper remove --clean-deps'
    alias apRemovePurge='sudo zypper remove --clean-deps'
    alias apClean='sudo zypper clean --all'
    alias apSourceCompile='sudo zypper source-install '
    alias apBuildDep='sudo zypper source-install --build-deps-only '
    alias apCheck='sudo zypper verify'
    alias apSearch='zypper search '
    # Tumbleweed is a rolling release: only "dup" upgrades it as a whole
    case $DOT_OS in
      opensuse-tumbleweed) alias apuu='sudo zypper refresh && sudo zypper dist-upgrade' ;;
      *) alias apuu='sudo zypper refresh && sudo zypper update' ;;
    esac
    alias aptGetVersion="rpm -qa | grep -i "
    alias aptList="rpm -qa | sort"
    alias aptListAll_names="rpm -qa --qf '%{NAME}\n' | sort"
    alias aptListAll_Path="zypper search --installed-only"
    alias aptListSources="zypper repos --uri"
    alias aptListSourcesD="ls -la /etc/zypp/repos.d/"
    alias aptgetAppInfos_fromthis="zypper info "
    ;;
  apk)
    alias ap='sudo apk add'
    alias apr='sudo apk del'
    alias apPurge='sudo apk del --purge'
    alias apRemovePurge='sudo apk del --purge'
    alias apClean='sudo apk cache clean'
    alias apCheck='sudo apk audit'
    alias apSearch='apk search '
    alias apuu='sudo apk update && sudo apk upgrade'
    alias aptGetVersion="apk info -vv | grep -i "
    alias aptList="apk info -vv"
    alias aptListAll_names="apk info"
    alias aptListAll_Path="apk info -vv"
    alias aptListSources="cat /etc/apk/repositories"
    alias aptgetAppInfos_fromthis="apk info -a "
    ;;
  opkg)
    alias ap='opkg install'
    alias apr='opkg remove'
    alias apSearch='opkg find '
    alias apuu='opkg update && opkg upgrade'
    alias aptGetVersion="opkg list-installed | grep -i "
    alias aptList="opkg list-installed"
    alias aptListAll_names="opkg list-installed | cut -d' ' -f1"
    alias aptgetAppInfos_fromthis="opkg info "
    ;;
  cyg)
    # apt-cyg installs and removes; upgrades only come from the Cygwin setup program
    alias ap='apt-cyg install'
    alias apr='apt-cyg remove'
    alias apSearch='apt-cyg search'
    alias aptList='cygcheck -c'
    alias apuu='echo "Cygwin upgrades: run setup-x86_64.exe again (https://cygwin.com/install.html)"'
    ;;
esac


# ------------------------------------------------------------------------------
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias phplint='find . -name "*.php" -exec php -l {} \; | grep "Parse error"'

# ------------------------------------------------------------------------------
# | git                                                                        |
# ------------------------------------------------------------------------------
# pushes the current branch; until 28.10.26 always master, also from another branch
alias gitp='git push origin HEAD'
alias gitsub='git submodule add'
alias gitsubadd='git submodule add'
alias gitsubget='git submodule init && git submodule update'
# only tracked files, like saveHome: git add * took every stray file and failed on ignored ones (28.10.26)
alias gitadd="git add -u && git commit -m "
# gc is also graphviz's graph counter: then git clone stays the long way (28.10.26)
if ! type -P gc >/dev/null; then
  alias gc="git clone "
fi

alias prettyGitLog="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# git config --global alias.lg "log --color --graph --pretty=format:'%C(#dc322f)%h%C(#b58900)%d %C(#eee8d5)%s %C(#dc322f)| %C(#586f75)%cr %C(#dc322f)| %C(#586e75)%an%Creset' --abbrev-commit"
alias prettyGitLog_clean=" --format='%Cred%h%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset%C(yellow)%d%Creset' --no-merges"

# lazygit, unless lg is taken by a command already (git lg above is a git alias, not this one)
if command -v lazygit >/dev/null 2>&1 && ! command -v lg >/dev/null 2>&1; then
  alias lg='lazygit'
fi

#git clone -b <branch> <remote_repo>
#Example:
#git clone -b develop git@github.com:user/myproject.git

alias map="xargs -n1"
#find * -name models.py | map dirname
#core

alias makescript="fc -rnl | head -1 >" #Easily make a script out of the last command you ran: makescript [script.sh]

# ------------------------------------------------------------------------------
# | Network                                                                    |
# ------------------------------------------------------------------------------
# no wget -c: with a file of the same name it appended to the old version instead of a new download (28.10.26)
alias checkport_lsof='lsof -i '


# netstat (net-tools) is no longer installed by default on current distros; ss (iproute2) is
if command -v netstat >/dev/null 2>&1; then
  alias ports="netstat -lnpt4e | grep -w 'LISTEN'"
  alias portsu="netstat -lnp"
  alias llport='netstat -nape --inet --inet6'
else
  alias ports='ss -lntp4e'
  alias portsu='ss -lnptux'
  alias llport='ss -napetu'
fi

# external ip address
alias myip_dns="dig +short myip.opendns.com @resolver1.opendns.com"
alias myip_http="curl -fsS https://ipecho.net/plain && echo"

alias ping='ping -c 5'
# Do not wait interval 1 second, go fast #
alias fastping='command ping -c 100 -s.2'

# Gzip-enabled `curl`
alias gurl="curl --compressed"

# displays the ports that use the applications
alias lsport='sudo lsof -i -T -n'
alias listen="lsof -P -i -n" 


# show only active network listeners
alias netlisteners='sudo lsof -i -P | grep LISTEN'

#also pass it via sudo so whoever is admin can reload it without calling yo
if [ -x /usr/local/nginx/sbin/nginx ]; then
  alias nginxreload='sudo /usr/local/nginx/sbin/nginx -s reload'
  alias nginxtest='sudo /usr/local/nginx/sbin/nginx -t'
fi
if [ -x /usr/sbin/lighttpd ]; then
  alias lightyload='sudo /etc/init.d/lighttpd reload'
  alias lightytest='sudo /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -t'
fi
if [ -x /usr/sbin/apachectl ]; then
  alias httpdreload='sudo /usr/sbin/apachectl -k graceful'
  alias httpdtest='sudo /usr/sbin/apachectl -t && /usr/sbin/apachectl -t -D DUMP_VHOSTS'
fi

alias interfaces_IP="ip -4 -o addr show scope global | awk '{print \$2, \$4}'"
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
if command -v timedatectl >/dev/null 2>&1; then
  alias setTimeZone='sudo timedatectl set-timezone' # setTimeZone Europe/Berlin; list: timedatectl list-timezones
elif command -v setup-timezone >/dev/null 2>&1; then
  alias setTimeZone='sudo setup-timezone' # Alpine
else
  alias setTimeZone='sudo dpkg-reconfigure tzdata'
fi

# stopwatch
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'


# ------------------------------------------------------------------------------
# | Hard- & Software Infos                                                     |
# ------------------------------------------------------------------------------

# pass options to free
alias meminfo="free -m -l -t"

# find the PID of any process: psg [name] (named psg, an alias ps broke every later ps call)
alias psg="ps aux | grep"

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


## get GPU ram on desktop / laptop##
alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log'

# kill all processes with this name, after a question (kill_all_of_process); "pkill -f" matched the whole command
# line and also hit the own SSH session (28.10.26)
alias psKillAll="kill_all_of_process"

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

# becoming root + executing last command: type  su -c "!!"  (the alias sulast never worked: history expansion
# does not happen inside an alias, su ran the text "!-1"; removed 28.10.26)
alias mountc='mount |column -t'
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

# decimal to hexadecimal value: dec2hex 255
alias dec2hex='printf "%x\n"'

# Canonical hex dump; some systems have this symlinked
command -v hd > /dev/null || alias hd="hexdump -C"

# urldecode - url http network decode: urldecode 'a%20b'
alias urldecode="python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))'"

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
# "command -v": "command tree" ran tree, a recursive walk of the current folder at every login (28.10.26)
if command -v tree >/dev/null 2>&1; then
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
  if command -v grc >/dev/null 2>&1; then
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

  if command -v python3 >/dev/null 2>&1; then alias pretty='python3 -m json.tool'; else alias pretty='jq .'; fi


# ------------------------------------------------------------------------------
# | Memcache                                                                   |
# ------------------------------------------------------------------------------

if [ -x /usr/bin/memcached-tool ]; then
  ## Memcached server status  ##
  alias mcdstats='/usr/bin/memcached-tool 127.0.0.1:11211 stats'
  alias mcdshow='/usr/bin/memcached-tool 127.0.0.1:11211 display'

  ## quickly flush out memcached server ##
  alias flushmcd='echo "flush_all" | nc 127.0.0.1 11211'
fi

# ------------------------------------------------------------------------------
# | apache                                                                     |
# ------------------------------------------------------------------------------

if [ -d /etc/apache2 ]; then
  alias apacheModsAvailable="ls -l /etc/apache2/mods-available/"
  alias apacheModsEnabled="ls -l /etc/apache2/mods-enabled/"
  alias restartApachePhp="service apache2 restart"
fi
if command -v plesk >/dev/null 2>&1; then
  alias restartPhp73fpm="service plesk-php73-fpm restart"
fi


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
  if command -v grc >/dev/null 2>&1; then
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

  if command -v wizzy >/dev/null 2>&1; then
    alias grafanaListDashboards="cd $HOME/wizzy/grafana-entities && wizzy list dashboards"
    alias grafanaImportDashbaord="$HOME/wizzy/grafana-entities && wizzy import dashboards"
  fi

# ------------------------------------------------------------------------------
# | #apache Ubuntu 16                                                          |
# ------------------------------------------------------------------------------

  alias convert_CR2_to_JPG='for i in *.CR2; do ufraw-batch $i --out-type=jpeg --output JPG/$i.jpg; done;'
  
   
###################
# Docker shortcuts
###################

# docker and docker compose aliases, only where docker is installed (fi after dcp)
if command -v docker >/dev/null 2>&1; then

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
# docker-compose v1 is end of life since 2023; Docker's v2 plugin is "docker compose"
_dc='docker compose'; command -v docker-compose >/dev/null 2>&1 && _dc=docker-compose
# dc is also the desk calculator (busybox has one): then only the long names below (28.10.26)
if ! type -P dc >/dev/null; then
  alias dc="$_dc "
fi
 
# start docker stack defined by docker-compose.yml as deamon
alias dcupd="$_dc up -d"

# start docker stack defined by docker-compose.yml
alias dcup="$_dc up "
 
# stop docker stack defined by docker-compose.yml
alias dcdn="$_dc down"
 
# rebuild docker stack
alias dcb="$_dc up -d --build"
 
# watch logs in docker stack
alias dcl="$_dc logs -f --tail 50"

# watch logs in docker stack
alias dcp="$_dc pull"
unset _dc

fi

###########################
# VNC shortcuts
###########################

if command -v vncserver >/dev/null 2>&1; then
  alias vncServerStop="vncserver -kill :1"
  alias vncServerStart="vncserver -geometry 1920x1080 -depth 16 :1"
  alias vncServerStatus="sudo ps -ef | grep vnc"
  alias vncServerPW="vncpasswd"
fi

# ZeroTier: installer/zerotier.sh (the alias install_zerotiert piped curl into sudo bash, removed 28.10.26)
alias ListShellandEnvironmentVariables="printenv "

alias fx="fx ." #npm install -g fx print json
# pip install howdoi. A function: the alias put in the $* of loading time (28.10.26). "function name" keeps an
# old alias of that name from expanding on a reload.
function how { howdoi "$@" -c -n 5; }

#wifi
alias wifi_ls_controller="lspci"
# iwconfig (wireless-tools) is deprecated and often missing, iw replaces it; the interface is the first wireless one
if command -v iwconfig >/dev/null 2>&1; then
  alias wifi_show_infos='iwconfig 2>/dev/null | grep -A7 IEEE'
  alias wifi_show_quality='iwconfig 2>/dev/null | grep -i --color quality'
else
  alias wifi_show_infos='iw dev "$(iw dev | awk "/Interface/ {print \$2; exit}")" link'
  alias wifi_show_quality='iw dev "$(iw dev | awk "/Interface/ {print \$2; exit}")" link | grep -i signal'
fi
alias wifi_show_quality2="cat /proc/net/wireless"
alias wifi_show_quality_continuosly="watch -n 1 cat /proc/net/wireless"
alias wifi_show_quality_continuosly_wavemon="sudo wavemon"

#journalctl 
alias journal_show_errors="journalctl -p err -b "
alias journal_show_thisunit="journalctl -u  "
alias journal_show_live_from="journalctl -f -u "
alias journal_show_live="journalctl -f"

#logrotate
alias logrotateTest="sudo logrotate -d /etc/logrotate.conf"
alias logrotateTestThis="logrotate -d "
alias logrotateDoThis="logrotate -f "

#fail2ban
if command -v fail2ban-client >/dev/null 2>&1; then
  alias fail2ban-client-status="fail2ban-client status"
  alias fail2ban-client-getBlockedIP_all='iptables -L -n | awk '\''$1=="REJECT" && $4!="0.0.0.0/0" {print $4}'\'''
  alias fail2ban-client-status_all="fail2ban-client status | sed -n 's/,//g;s/.*Jail list://p' | xargs -n1 fail2ban-client status"
  alias fail2ban-client-status_this="fail2ban-client status"
  alias fail2ban-test_ssh="fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf && echo 'from#fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf'"
  alias fail2ban-test_postfix="fail2ban-regex --print-all-missed /var/log/mail.log /etc/fail2ban/filter.d/sendmail.conf /etc/fail2ban/filter.d/sendmail.conf | less && echo 'from#fail2ban-regex --print-all-missed /var/log/mail.log /etc/fail2ban/filter.d/sendmail.conf /etc/fail2ban/filter.d/sendmail.conf | less'"
fi

#mail
if command -v plesk >/dev/null 2>&1; then
  alias graylistCheck='	sqlite3 /var/lib/plesk/mail/greylist/settings.db "select * from remote_domains"'
  alias graylistServerinfo="/usr/local/psa/bin/grey_listing --info-server"
fi

# Debian 11+, Fedora and the RHEL family filter with nftables; iptables is often not installed there
if PATH=$PATH:/usr/sbin:/sbin command -v iptables >/dev/null 2>&1; then
  alias checkIP="sudo iptables --list -n"
else
  alias checkIP="sudo nft list ruleset"
fi
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

# lists the functions with line and file, without the internal _ ones. Until 28.10.26 an alias whose awk got $3 of
# the shell (empty), so it printed nothing usable.
function list_functions {
  local x name line file had=0 names=()
  shopt -q extdebug && had=1
  while read -r x x name; do [[ $name == _* ]] || names+=("$name"); done < <(declare -F)
  shopt -s extdebug
  declare -F "${names[@]}" | while read -r name line file; do
    printf '%-32s %6s  %s\n' "$name" "$line" "$file"
  done
  [ $had = 1 ] || shopt -u extdebug
}

#top for files
alias topFiles="watch -d -n 2 'df; ls -FlAt;'"

# Quick and dirty hardware summary where lshw is not available. Requires util-linux, procps, pciutils, usbutils and net-tools, which should be preinstalled on most systems. 
alias gethw='(printf "\nCPU\n\n"; lscpu; printf "\nMEMORY\n\n"; free -h; printf "\nDISKS\n\n"; lsblk; printf "\nPCI\n\n"; lspci; printf "\nUSB\n\n"; lsusb; printf "\nNETWORK\n\n"; ip -br addr) 2>&1 | less'

#python
alias py_createVirt="python3 -m venv env"
# pip outside a virtualenv is refused on Debian 12+, Ubuntu 23.04+ and Fedora 38+ (PEP 668, EXTERNALLY-MANAGED)
_pip() {
  if [ -z "${VIRTUAL_ENV:-}" ] && ls /usr/lib/python3*/EXTERNALLY-MANAGED >/dev/null 2>&1; then
    echo "pip outside a venv is blocked here (PEP 668): py_createVirt && . env/bin/activate, or pipx install <app>" >&2
    return 1
  fi
  python3 -m pip "$@"
}
alias pi='_pip install'
alias pf='python3 -m pip freeze'
# pir, not pr: pr is the coreutils pager and always installed (renamed 28.10.26)
alias pir='_pip install -r requirements.txt'

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
# arp (net-tools) is gone on current distros, ip neigh shows the same table
if command -v arp >/dev/null 2>&1; then alias scanNetwork_arp='arp -a'; else alias scanNetwork_arp='ip neigh'; fi

#Host-Discovery mit ARP-scan
alias scanNetwork_arpScan="arp-scan --localnet"
