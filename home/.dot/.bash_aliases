# https://github.com/voku/dotfiles

# reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"
alias load="source $HOME/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh"


# ------------------------------------------------------------------------------
# | Defaults                                                                   |
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
alias p3='py3'
alias p='py3'
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

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias dir='ls -la'
alias d='ls -l'
alias da='ls -la'

# ls replacement with exa
if command -v exa >/dev/null; then
  alias d='exa --long --header --git -g'
  alias da='exa --long --header --git -g -all'
  alias dd='exa --long --header --git -T -g'
fi

alias userls='cat /etc/passwd'

# Print each PATH entry on a separate line
alias path="echo -e ${PATH//:/\\n}"

aliascd_Aptlist='cd /etc/apt/'
alias cd_git="cd $HOME/git"
alias cd_Scripts="cd $HOME/git/scripts"

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

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias dir='ls -la'
alias d='ls -l'
alias da='ls -la'

# ls replacement with exa
if command -v exa >/dev/null; then
  alias d='exa --long --header --git -g'
  alias da='exa --long --header --git -g -all'
  alias dd='exa --long --header --git -T -g'
fi

# ------------------------------------------------------------------------------
# | Search and Find                                                            |
# ------------------------------------------------------------------------------

# super-grep ;)
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# search in files (with fallback)
if which ack-grep >/dev/null 2>&1; then
  alias ack=ack-grep

  alias afind="ack-grep -iH"
else
  alias afind="ack -iH"
fi

# ------------------------------------------------------------------------------
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias listLoadedPhpInis73="php73 --ini"

# ------------------------------------------------------------------------------
# | Docker                                                                     |
# ------------------------------------------------------------------------------

alias dl='docker ps'
alias dr='docker restart'


# ------------------------------------------------------------------------------
# | git                                                                        |
# ------------------------------------------------------------------------------
alias gitp='git push origin master'
alias gitsub='git submodule add'
alias gitsubadd='git submodule add'
alias gitsubget='git submodule init && git submodule update'
alias gitadd="git add * && git commit -m "
alias gc="git clone "


# replace top with htop
if command -v htop >/dev/null; then
alias top_orig="/usr/bin/top"
fi




# ------------------------------------------------------------------------------
# | Network                                                                    |
# ------------------------------------------------------------------------------

alias checkport='lsof -i '
alias ports="netstat -lnpt4e | grep -w 'LISTEN'"
alias portsu="netstat -lnp"

# external ip address
alias myip_dns="dig +short myip.opendns.com @resolver1.opendns.com"
alias myip_http="GET http://ipecho.net/plain && echo"


# Gzip-enabled `curl`
alias gurl="curl --compressed"

# displays the ports that use the applications
alias lsport='sudo lsof -i -T -n'

# shows more about the ports on which the applications use
alias llport='netstat -nape --inet --inet6'

# show only active network listeners
alias netlisteners='sudo lsof -i -P | grep LISTEN'


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

# stopwatch
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'


# ------------------------------------------------------------------------------
# | Hard- & Software Infos                                                     |
# ------------------------------------------------------------------------------

# pass options to free
alias meminfo="free -m -l -t"

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

#kill all process with name
alias psKillAll="pkill -f "

# shows the process structure to clearly
alias pst="pstree -Alpha"

# shows all your processes
alias psmy="ps -ef | grep $USER"

# the load-avg
alias loadavg="cat /proc/loadavg"

# show all partitions
alias partitions="cat /proc/partitions"

# shows the disk usage of a directory legibly
alias du="du -kh"
alias du5="du -kh | tail -5"
alias du10="du -kh | tail -10"

# show the biggest files in a folder first
alias du_overview="du -h | grep "^[0-9,]*[MG]" | sort -hr | less"

# shows the complete disk usage to legibly
alias df="df -kTh"

# ------------------------------------------------------------------------------
# | System Utilities                                                           |
# ------------------------------------------------------------------------------

# becoming root + executing last command
alias sulast="su -c !-1 root"


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


