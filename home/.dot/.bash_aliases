# https://github.com/voku/dotfiles

# reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"
alias load="source $HOME/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh"

alias makescript="fc -rnl | head -1 >" #Easily make a script out of the last command you ran: makescript [script.sh]

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

alias py3='python3'
alias py='py3'
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

alias cd_Aptlist='cd /etc/apt/'
alias cd_git="cd $HOME/git"
alias cd_Scripts="cd $HOME/git/scripts"



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
# | services                                                                   |
# ------------------------------------------------------------------------------


alias list_services_startup="systemctl list-units --type service"
alias list_services_all="systemctl list-units --type service --all"
alias list_services_tree="systemctl list-dependencies --type service"
alias list_services_locate="locate "

alias check_servic_isActive="systemctl is-active "
alias check_servic_isActive_onBoot="systemctl is-enabled "
alias disable_mask_service="systemctl mask "
alias disable_service="systemctl enable "
alias enable_service="systemctl enable "


# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------

alias ap='apt-get install'
alias apuu='sudo apt-get update && sudo apt-get -y upgrade'
alias load='source ~/.bashrc && source ~/.dot/.bash_aliases && source ~/.dot/.bash_functions.sh'
alias aptGetVersion="dpkg -l | grep -i "
alias aptList="dpkg -l"

# ------------------------------------------------------------------------------
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias listLoadedPhpInis73="php73 --ini"
alias phplint='find . -name "*.php" -exec php -l {} \; | grep "Parse error"'

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

alias prettyGitLog="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# git config --global alias.lg "log --color --graph --pretty=format:'%C(#dc322f)%h%C(#b58900)%d %C(#eee8d5)%s %C(#dc322f)| %C(#586f75)%cr %C(#dc322f)| %C(#586e75)%an%Creset' --abbrev-commit"
alias prettyGitLog_clean=" --format='%Cred%h%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset%C(yellow)%d%Creset' --no-merges"

#git clone -b <branch> <remote_repo>
#Example:
#git clone -b develop git@github.com:user/myproject.git

alias createGitChangelog="git log v2.1.0...v2.1.1 --pretty=format:'<li> <a href=\"https://github.com/corgan2222/dotfiles/commit/%H\">view commit &bull;</a> %s</li> ' --reverse | grep \"#changelog\""
#https://jerel.co/blog/2011/07/generating-a-project-changelog-using-git-log


git-search () {
    git log --all -S"$@" --pretty=format:%H | map git show 
}


alias map="xargs -n1"
#find * -name models.py | map dirname
#core

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
alias listen="lsof -P -i -n" 

# shows more about the ports on which the applications use
alias llport='netstat -nape --inet --inet6'

# show only active network listeners
alias netlisteners='sudo lsof -i -P | grep LISTEN'

getlocation() { lynx -dump http://www.ip-adress.com/ip_tracer/?QRY=$1|grep address|egrep 'city|state|country'|awk '{print $3,$4,$5,$6,$7,$8}'|sed 's\ip address flag \\'|sed 's\My\\';}  #Get your public IP address and host.


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

alias ps?="ps aux | grep" #Easily find the PID of any process: ps? [name]

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


#### Validators
alias xxyamlcheck='yamllint '
alias xxjsoncheck='jq "." >/dev/null <'
alias xxxmlcheck='xmlstarlet val '

#### Characters
alias xxascii='man ascii | grep -m 1 -A 63 --color=never Oct'
alias xxalphabet='echo a b c d e f g h i j k l m n o p q r s t u v w x y z'
alias xxunicode='echo ✓ ™  ♪ ♫ ☃ ° Ɵ ∫'
alias xxnumalphabet='xxalphabet; echo 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6'

#### Regular Expressions
alias xxregxmac='echo [0-9a-f]{2}:[0-9a-f]'
alias xxregxip="echo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'"
alias xxregxemail='echo "[^[:space:]]+@[^[:space:]]+"'

alias histg="history | grep" #To quickly search through your command history: histg [keyword]

# tree (with fallback)
if which tree >/dev/null 2>&1; then
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




# ------------------------------------------------------------------------------
# | auto-completion (for bash)                                                 |
# ------------------------------------------------------------------------------

# Automatically add completion for all aliases to commands having completion functions
# source: http://superuser.com/questions/436314/how-can-i-get-bash-to-perform-tab-completion-for-my-aliases
alias_completion()
{
  local namespace="alias_completion"

  # parse function based completion definitions, where capture group 2 => function and 3 => trigger
  local compl_regex='complete( +[^ ]+)* -F ([^ ]+) ("[^"]+"|[^ ]+)'
  # parse alias definitions, where capture group 1 => trigger, 2 => command, 3 => command arguments
  local alias_regex="alias ([^=]+)='(\"[^\"]+\"|[^ ]+)(( +[^ ]+)*)'"

  # create array of function completion triggers, keeping multi-word triggers together
  eval "local completions=($(complete -p | sed -rne "/$compl_regex/s//'\3'/p"))"
  (( ${#completions[@]} == 0 )) && return 0

  # create temporary file for wrapper functions and completions
  rm -f "/tmp/${namespace}-*.XXXXXXXXXX" # preliminary cleanup
  local tmp_file="$(mktemp "/tmp/${namespace}-${RANDOM}.XXXXXXXXXX")" || return 1

  # read in "<alias> '<aliased command>' '<command args>'" lines from defined aliases
  local line; while read line; do
    eval "local alias_tokens=($line)" 2>/dev/null || continue # some alias arg patterns cause an eval parse error
    local alias_name="${alias_tokens[0]}" alias_cmd="${alias_tokens[1]}" alias_args="${alias_tokens[2]# }"

    # skip aliases to pipes, boolan control structures and other command lists
    # (leveraging that eval errs out if $alias_args contains unquoted shell metacharacters)
    eval "local alias_arg_words=($alias_args)" 2>/dev/null || continue

    # skip alias if there is no completion function triggered by the aliased command
    [[ " ${completions[*]} " =~ " $alias_cmd " ]] || continue
    local new_completion="$(complete -p "$alias_cmd")"

    # create a wrapper inserting the alias arguments if any
    if [[ -n $alias_args ]]; then
     local compl_func="${new_completion/#* -F /}"; compl_func="${compl_func%% *}"
     # avoid recursive call loops by ignoring our own functions
     if [[ "${compl_func#_$namespace::}" == $compl_func ]]; then
       local compl_wrapper="_${namespace}::${alias_name}"
         echo "function $compl_wrapper {
           (( COMP_CWORD += ${#alias_arg_words[@]} ))
           COMP_WORDS=($alias_cmd $alias_args \${COMP_WORDS[@]:1})
           $compl_func
         }" >> "$tmp_file"
         new_completion="${new_completion/ -F $compl_func / -F $compl_wrapper }"
     fi
    fi

    # replace completion trigger by alias
    new_completion="${new_completion% *} $alias_name"
    echo "$new_completion" >> "$tmp_file"
  done < <(alias -p | sed -rne "s/$alias_regex/\1 '\2' '\3'/p")
  source "$tmp_file" && rm -f "$tmp_file"
}
if [ -n "$BASH_VERSION" ]; then
  alias_completion
fi
unset -f alias_completion

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

  alias pretty=" python -m json.tool"