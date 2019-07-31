
updateHome ()
{
  if [ $# -eq 0 ]; then
      echo "add commit message"
      return 1
    else
      homeshick cd dotfiles
      gitadd "${1}"
      gitp
      cd -
    fi

}

mkcdir ()
{
    mkdir -p -- "$1" &&
      cd -P -- "$1"
}

# Convert video to gif file.
# Usage: video2gif video_file (scale) (fps)
video2gif() {
  ffmpeg -y -i "${1}" -vf fps=${3:-10},scale=${2:-320}:-1:flags=lanczos,palettegen "${1}.png"
  ffmpeg -i "${1}" -i "${1}.png" -filter_complex "fps=${3:-10},scale=${2:-320}:-1:flags=lanczos[x];[x][1:v]paletteuse" "${1}".gif
  rm "${1}.png"
}

function _man()
{
        env \
        LESS_TERMCAP_mb=$(printf "\e[1;31m") \
        LESS_TERMCAP_md=$(printf "\e[1;31m") \
        LESS_TERMCAP_me=$(printf "\e[0m") \
        LESS_TERMCAP_se=$(printf "\e[0m") \
        LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
        LESS_TERMCAP_ue=$(printf "\e[0m") \
        LESS_TERMCAP_us=$(printf "\e[1;32m") \
        man "$@"
}

# extract: unified archive extractor
# usage: extract <file>
    extract ()
    {
      if [ -f $1 ] ; then
        case $1 in
          *.tar.bz2)   tar xjf $1   ;;
          *.tar.gz)    tar xzf $1   ;;
          *.bz2)       bunzip2 $1   ;;
          *.rar)       rar x $1     ;;
          *.gz)        gunzip $1    ;;
          *.tar)       tar xf $1    ;;
          *.tbz2)      tar xjf $1   ;;
          *.tgz)       tar xzf $1   ;;
          *.zip)       unzip $1     ;;
          *.Z)         uncompress $1;;
          *.7z)        7z x $1      ;;
          *.exe)       cabextract $1;;
          *)           echo "'$1' cannot be extracted via extract"; false ;;
        esac
      else
          'echo' -e "'$1' is not a valid file\nusage: extract <file>\n"
          false
      fi
    }

function mkdatedir {
    mkdir "$(date +%Y-%m-%d_${1})"
}

function gifify() {
  [ -z "$1" ] && echo 'Usage: gifify <file_path>' && return 1
  [ ! -f "$1" ] && echo "File $1 does not exist" && return 1
  ffmpeg -i "$1" -r 10 -vcodec png out-static-%05d.png
  time convert -verbose +dither -layers Optimize -resize 1600x1600\> out-static*.png  GIF:- | gifsicle --colors 128 --delay=5 --loop --optimize=3 --multifile - > "$1.gif"
  rm out-static*.png
}

# get current branch in git repo
function parse_git_branch() {
	BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
	if [ ! "${BRANCH}" == "" ]
	then
		STAT=`parse_git_dirty`
		echo "[${BRANCH}${STAT}]"
	else
		echo ""
	fi
}

# get current status of git repo
function parse_git_dirty {
	status=`git status 2>&1 | tee`
	dirty=`echo -n "${status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?"`
	untracked=`echo -n "${status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?"`
	ahead=`echo -n "${status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?"`
	newfile=`echo -n "${status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?"`
	renamed=`echo -n "${status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?"`
	deleted=`echo -n "${status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?"`
	bits=''
	if [ "${renamed}" == "0" ]; then
		bits=">${bits}"
	fi
	if [ "${ahead}" == "0" ]; then
		bits="*${bits}"
	fi
	if [ "${newfile}" == "0" ]; then
		bits="+${bits}"
	fi
	if [ "${untracked}" == "0" ]; then
		bits="?${bits}"
	fi
	if [ "${deleted}" == "0" ]; then
		bits="x${bits}"
	fi
	if [ "${dirty}" == "0" ]; then
		bits="!${bits}"
	fi
	if [ ! "${bits}" == "" ]; then
		echo " ${bits}"
	else
		echo ""
	fi
}

function nonzero_return() {
	RETVAL=$?
	[ $RETVAL -ne 0 ] && echo "$RETVAL"
}

# -------------------------------------------------------------------
# lc: Convert the parameters or STDIN to lowercase.
lc()
{
  if [ $# -eq 0 ]; then
    python -c 'import sys; print sys.stdin.read().decode("utf-8").lower()'
  else
    for i in "$@"; do
        echo $i | python -c 'import sys; print sys.stdin.read().decode("utf-8").lower()'
    done
  fi
}

# -------------------------------------------------------------------
# uc: Convert the parameters or STDIN to uppercase.
uc()
{
  if [ $# -eq 0 ]; then
    python -c 'import sys; print sys.stdin.read().decode("utf-8").upper()'
  else
    for i in "$@"; do
        echo $i | python -c 'import sys; print sys.stdin.read().decode("utf-8").upper()'
    done
  fi
}

# -------------------------------------------------------------------
# wtfis: Show what a given command really is. It is a combination of "type", "file"
# and "ls". Unlike "which", it does not only take $PATH into account. This
# means it works for aliases and hashes, too. (The name "whatis" was taken,
# and I did not want to overwrite "which", hence "wtfis".)
# The return value is the result of "type" for the last command specified.
#
# usage:
#
#   wtfis man
#   wtfis vi
#
# source: https://raw.githubusercontent.com/janmoesen/tilde/master/.bash/commands
wtfis()
{
  local cmd=""
  local type_tmp=""
  local type_command=""
  local i=1
  local ret=0

  if [ -n "$BASH_VERSION" ]; then
    type_command="type -p"
  else
    type_command=( whence -p ) # changes variable type as well
  fi

  if [ $# -eq 0 ]; then
    # Use "fc" to get the last command, and use that when no command
    # was given as a parameter to "wtfis".
    set -- $(fc -nl -1)

    while [ $# -gt 0 -a '(' "sudo" = "$1" -o "-" = "${1:0:1}" ')' ]; do
      # Ignore "sudo" and options ("-x" or "--bla").
      shift
    done

    # Replace the positional parameter array with the last command name.
    set -- "$1"
  fi

  for cmd; do
    type_tmp="$(type "$cmd")"
    ret=$?

    if [ $ret -eq 0 ]; then
      # Try to get the physical path. This works for hashes and
      # "normal" binaries.
      local path_tmp=$(${type_command} "$cmd" 2>/dev/null)

      if [ $? -ne 0 ] || ! test -x "$path_tmp"; then
        # Show the output from "type" without ANSI escapes.
        echo "${type_tmp//$'\e'/\\033}"

        case "$(command -v "$cmd")" in
          'alias')
            local alias_="$(alias "$cmd")"

            # The output looks like "alias foo='bar'" so
            # strip everything except the body.
            alias_="${alias_#*\'}"
            alias_="${alias_%\'}"

            # Use "read" to process escapes. E.g. 'test\ it'
            # will # be read as 'test it'. This allows for
            # spaces inside command names.
            read -d ' ' alias_ <<< "$alias_"

            # Recurse and indent the output.
            # TODO: prevent infinite recursion
            wtfis "$alias_" 2>&2 | sed 's/^/  /'

            ;;
          'keyword' | 'builtin')

            # Get the one-line description from the built-in
            # help, if available. Note that this does not
            # guarantee anything useful, though. Look at the
            # output for "help set", for instance.
            help "$cmd" 2>/dev/null | {
              local buf line
              read -r line
              while read -r line; do
                buf="$buf${line/.  */.} "
                if [[ "$buf" =~ \.\ $ ]]; then
                  echo "$buf"
                  break
                fi
              done
            }

            ;;
        esac
      else
        # For physical paths, get some more info.
        # First, get the one-line description from the man page.
        # ("col -b" gets rid of the backspaces used by OS X's man
        # to get a "bold" font.)
        (COLUMNS=10000 man "$(basename "$path_tmp")" 2>/dev/null) | col -b | \
        awk '/^NAME$/,/^$/' | {
          local buf=""
          local line=""

          read -r line
          while read -r line; do
            buf="$buf${line/.  */.} "
            if [[ "$buf" =~ \.\ $ ]]; then
              echo "$buf"
              buf=''
              break
            fi
          done

          [ -n "$buf" ] && echo "$buf"
        }

        # Get the absolute path for the binary.
        local full_path_tmp="$(
          cd "$(dirname "$path_tmp")" \
            && echo "$PWD/$(basename "$path_tmp")" \
            || echo "$path_tmp"
        )"

        # Then, combine the output of "type" and "file".
        local fileinfo="$(file "$full_path_tmp")"
        echo "${type_tmp%$path_tmp}${fileinfo}"

        # Finally, show it using "ls" and highlight the path.
        # If the path is a symlink, keep going until we find the
        # final destination. (This assumes there are no circular
        # references.)
        local paths_tmp=("$path_tmp")
        local target_path_tmp="$path_tmp"

        while [ -L "$target_path_tmp" ]; do
          target_path_tmp="$(readlink "$target_path_tmp")"
          paths_tmp+=("$(
            # Do some relative path resolving for systems
            # without readlink --canonicalize.
            cd "$(dirname "$path_tmp")"
            cd "$(dirname "$target_path_tmp")"
            echo "$PWD/$(basename "$target_path_tmp")"
          )")
        done

        local ls="$(command ls -fdalF "${paths_tmp[@]}")"
        echo "${ls/$path_tmp/$'\e[7m'${path_tmp}$'\e[27m'}"
      fi
    fi

    # Separate the output for all but the last command with blank lines.
    [ $i -lt $# ] && echo
    let i++
  done

  return $ret
}

# -------------------------------------------------------------------
# whenis: Try to make sense of the date. It supports everything GNU date knows how to
# parse, as well as UNIX timestamps. It formats the given date using the
# default GNU date format, which you can override using "--format='%x %y %z'.
#
# usage:
#
#   $ whenis 1234567890            # UNIX timestamps
#   Sat Feb 14 00:31:30 CET 2009
#
#   $ whenis +1 year -3 months     # relative dates
#   Fri Jul 20 21:51:27 CEST 2012
#
#   $ whenis 2011-10-09 08:07:06   # MySQL DATETIME strings
#   Sun Oct  9 08:07:06 CEST 2011
#
#   $ whenis 1979-10-14T12:00:00.001-04:00 # HTML5 global date and time
#   Sun Oct 14 17:00:00 CET 1979
#
#   $ TZ=America/Vancouver whenis # Current time in Vancouver
#   Thu Oct 20 13:04:20 PDT 2011
#
# For more info, check out http://kak.be/gnudateformats.
whenis()
{
  # Default GNU date format as seen in date.c from GNU coreutils.
  local format='%a %b %e %H:%M:%S %Z %Y'
  if [[ "$1" =~ ^--format= ]]; then
    format="${1#--format=}"
    shift
  fi

  # Concatenate all arguments as one string specifying the date.
  local date="$*"
  if [[ "$date"  =~ ^[[:space:]]*$ ]]; then
    date='now'
  elif [[ "$date"  =~ ^[0-9]{13}$ ]]; then
    # Cut the microseconds part.
    date="${date:0:10}"
  fi

  # Use GNU date in all other situations.
  [[ "$date" =~ ^[0-9]+$ ]] && date="@$date"
  date -d "$date" +"$format"
}

# -------------------------------------------------------------------
# box: a function to create a box of '=' characters around a given string
#
# usage: box 'testing'
box()
{
  local t="$1xxxx"
  local c=${2:-"#"}

  echo ${t//?/$c}
  echo "$c $1 $c"
  echo ${t//?/$c}
}

# -------------------------------------------------------------------
# htmlEntityToUTF8: convert html-entity to UTF-8
htmlEntityToUTF8()
{
  if [ $# -eq 0 ]; then
    echo "Usage: htmlEntityToUTF8 \"&#9661;\""
    return 1
  else
    echo $1 | recode html..UTF8
  fi
}

# -------------------------------------------------------------------
# UTF8toHtmlEntity: convert UTF-8 to html-entity
UTF8toHtmlEntity()
{
  if [ $# -eq 0 ]; then
    echo "Usage: UTF8toHtmlEntity \"♥\""
    return 1
  else
    echo $1 | recode UTF8..html
  fi
}

# -------------------------------------------------------------------
# optiImages: optimized images (png/jpg) in the current dir + sub-dirs
#
# INFO: use "grunt-contrib-imagemin" for websites!
optiImages()
{
  find . -iname '*.png' -exec optipng -o7 {} \;
  find . -iname '*.jpg' -exec jpegoptim --force {} \;
}

# -------------------------------------------------------------------
# lman: Open the manual page for the last command you executed.
lman()
{
  local cmd

  set -- $(fc -nl -1)
  while [ $# -gt 0 -a '(' "sudo" = "$1" -o "-" = "${1:0:1}" ')' ]; do
    shift
  done

  cmd="$(basename "$1")"
  man "$cmd" || help "$cmd"
}

# -------------------------------------------------------------------
# testConnection: check if connection to google.com is possible
#
# usage:
#   testConnection 1  # will echo 1 || 0
#   testConnection    # will return 1 || 0
testConnection()
{
  local tmpReturn=1
  $(wget --tries=2 --timeout=2 www.google.com -qO- &>/dev/null 2>&1)

  if [ $? -eq 0 ]; then
    tmpReturn=0
  else
    tmpReturn=1
  fi

  if [ "$1" ] && [ $1 -eq 1 ]; then
    echo $tmpReturn
  else
    return $tmpReturn
  fi
}

# -------------------------------------------------------------------
# netstat_used_local_ports: get used tcp-ports
netstat_used_local_ports()
{
  netstat -atn \
    | awk '{printf "%s\n", $4}' \
    | grep -oE '[0-9]*$' \
    | sort -n \
    | uniq
}

# -------------------------------------------------------------------
# netstat_free_local_port: get one free tcp-port
netstat_free_local_port()
{
  # didn't work with zsh / bash is ok
  #read lowerPort upperPort < /proc/sys/net/ipv4/ip_local_port_range

  for port in $(seq 32768 61000); do
    for i in $(netstat_used_local_ports); do
      if [[ $used_port -eq $port ]]; then
        continue
      else
        echo $port
        return 0
      fi
    done
  done

  return 1
}

# -------------------------------------------------------------------
# connection_overview: get stats-overview about your connections
netstat_connection_overview()
{
  netstat -nat \
    | awk '{print $6}' \
    | sort \
    | uniq -c \
    | sort -n
}

# -------------------------------------------------------------------
# nice mount (http://catonmat.net/blog/another-ten-one-liners-from-commandlingfu-explained)
#
# displays mounted drive information in a nicely formatted manner
mount_info()
{
  (echo "DEVICE PATH TYPE FLAGS" && mount | awk '$2="";1') \
    | column -t;
}

# -------------------------------------------------------------------
# sniff: view HTTP traffic
#
# usage: sniff [eth0]
sniff()
{
  if [ $1 ]; then
    local device=$1
  else
    local device='eth0'
  fi

  sudo ngrep -d ${device} -t '^(GET|POST) ' 'tcp and port 80'
}

# -------------------------------------------------------------------
# httpdump: view HTTP traffic
#
# usage: httpdump [eth1]
httpdump()
{
  if [ $1 ]; then
    local device=$1
  else
    local device='eth0'
  fi

  sudo tcpdump -i ${device} -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\"
}

# -------------------------------------------------------------------
# iptablesBlockIP: block a IP via "iptables"
#
# usage: iptablesBlockIP 8.8.8.8
iptablesBlockIP()
{
  if [ $# -eq 0 ]; then
    echo "Usage: iptablesBlockIP 123.123.123.123"
    return 1
  else
    sudo iptables -A INPUT -s $1 -j DROP
  fi
}

# -------------------------------------------------------------------
# ips: get the local IP's
ips()
{
  ifconfig | grep "inet " | awk '{ print $2 }' | cut -d ":" -f 2
}

# -------------------------------------------------------------------
# os-info: show some info about your system
os-info()
{
  lsb_release -a
  uname -a

  if [ -z /etc/lsb-release ]; then
    cat /etc/lsb-release;
  fi;

  if [ -z /etc/issue ]; then
    cat /etc/issue;
  fi;

  if [ -z /proc/version ]; then
    cat /proc/version;
  fi;
}

# -------------------------------------------------------------------
# command_exists: check if a command exists
command_exists()
{
    return type "$1" &> /dev/null ;
}

# -------------------------------------------------------------------
# stripspace: strip unnecessary whitespace from file
stripspace()
{
  if [ $# -eq 0 ]; then
    echo "Usage: stripspace FILE"
    exit 1
  else
    local tempfile=mktemp
    git stripspace < "$1" > tempfile
    mv tempfile "$1"
  fi
}

# -------------------------------------------------------------------
# logssh: establish ssh connection + write a logfile
logssh()
{
  ssh $1 | tee sshlog
}

# -------------------------------------------------------------------
# lsssh: pretty print all established SSH connections
lsssh ()
{
  local ip=""
  local domain=""
  local conn=""

  lsof -i4 -s TCP:ESTABLISHED -n | grep '^ssh' | while read conn; do
    ip=$(echo $conn | grep -oE '\->[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[^ ]+')
    ip=${ip/->/}
    domain=$(dig -x ${ip%:*} +short)
    domain=${domain%.}
    # display nonstandard port if relevant
    printf "%s (%s)\n" $domain  ${ip/:ssh}
  done | column -t
}

# -------------------------------------------------------------------
# calc: Simple calculator
# usage: e.g.: 3+3 || 6*6/2
calc()
{
  local result=""
  result="$(printf "scale=10;$*\n" | bc --mathlib | tr -d '\\\n')"
  #                       └─ default (when `--mathlib` is used) is 20
  #
  if [[ "$result" == *.* ]]; then
    # improve the output for decimal numbers
    printf "$result" |
    sed -e 's/^\./0./'        `# add "0" for cases like ".5"` \
        -e 's/^-\./-0./'      `# add "0" for cases like "-.5"`\
        -e 's/0*$//;s/\.$//'   # remove trailing zeros
  else
    printf "$result"
  fi
  printf "\n"
}

# -------------------------------------------------------------------
# mkd: Create a new directory and enter it
mkd()
{
  mkdir -p "$@" && cd "$_"
}

# -------------------------------------------------------------------
# mkf: Create a new directory, enter it and create a file
#
# usage: mkf /tmp/lall/foo.txt
mkf()
{
  mkd $(dirname "$@") && touch $@
}

# -------------------------------------------------------------------
# rand_int: use "urandom" to get random int values
#
# usage: rand_int 8 --> e.g.: 32245321
rand_int()
{
  if [ $1 ]; then
    local length=$1
  else
    local length=16
  fi

  tr -dc 0-9 < /dev/urandom  | head -c${1:-${length}}
}

# -------------------------------------------------------------------
# passwdgen: a password generator
#
# usage: passwdgen 8 --> e.g.: f4lwka_2f
passwdgen()
{
  if [ $1 ]; then
    local length=$1
  else
    local length=16
  fi

  tr -dc A-Za-z0-9_ < /dev/urandom  | head -c${1:-${length}}
}

# -------------------------------------------------------------------
# targz: Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression
targz()
{
  local tmpFile="${@%/}.tar";
  tar -cvf "${tmpFile}" --exclude=".DS_Store" "${@}" || return 1;

  local size=$(
    stat -f"%z" "${tmpFile}" 2> /dev/null; # OS X `stat`
    stat -c"%s" "${tmpFile}" 2> /dev/null;  # GNU `stat`
  );

  local cmd="";
  if (( size < 52428800 )) && hash zopfli 2> /dev/null; then
    # the .tar file is smaller than 50 MB and Zopfli is available; use it
    cmd="zopfli";
  else
    if hash pigz 2> /dev/null; then
      cmd="pigz";
    else
      cmd="gzip";
    fi;
  fi;

  echo "Compressing .tar ($((size / 1000)) kB) using \`${cmd}\`…";
  "${cmd}" -v "${tmpFile}" || return 1;
  [ -f "${tmpFile}" ] && rm "${tmpFile}";

  local zippedSize=$(
  	stat -f"%z" "${tmpFile}.gz" 2> /dev/null; # OS X `stat`
  	stat -c"%s" "${tmpFile}.gz" 2> /dev/null; # GNU `stat`
  );

  echo "${tmpFile}.gz ($((zippedSize / 1000)) kB) created successfully.";
}

# -------------------------------------------------------------------
# duh: Sort the "du"-command output and use human-readable units.
duh()
{
  local unit=""
  local size=""

  du -k "$@" | sort -n | while read size fname; do
    for unit in KiB MiB GiB TiB PiB EiB ZiB YiB; do
      if [ "$size" -lt 1024 ]; then
        echo -e "${size} ${unit}\t${fname}"
        break
      fi
      size=$((size/1024))
    done
  done
}

# -------------------------------------------------------------------
# fs: Determine size of a file or total size of a directory
fs()
{
  if du -b /dev/null > /dev/null 2>&1; then
    local arg=-sbh
  else
    local arg=-sh
  fi

  if [[ -n "$@" ]]; then
    du $arg -- "$@"
  else
    du $arg .[^.]* ./*
  fi
}

# -------------------------------------------------------------------
# ff: displays all files in the current directory (recursively)
ff()
{
  find . -type f -iname '*'$*'*' -ls
}

# -------------------------------------------------------------------
# fstr: find text in files
fstr()
{
  OPTIND=1
  local case=""
  local usage="fstr: find string in files.
  Usage: fstr [-i] \"pattern\" [\"filename pattern\"] "

  while getopts :it opt
  do
        case "$opt" in
        i) case="-i " ;;
        *) echo "$usage"; return;;
        esac
  done

  shift $(( $OPTIND - 1 ))
  if [ "$#" -lt 1 ]; then
    echo "$usage"
    return 1
  fi

  find . -type f -name "${2:-*}" -print0 \
    | xargs -0 egrep --color=auto -Hsn ${case} "$1" 2>&- \
    | more
}

# -------------------------------------------------------------------
# file_backup_compressed: create a compressed backup (with date)
# in the current dir
#
# usage: file_backup_compressed test.txt
file_backup_compressed()
{
  if [ $1 ]; then
    if [ -z $1 ]; then
      echo "$1: not found"
      return 1
    fi

    tar czvf "./$(basename $1)-$(date +%y%m%d-%H%M%S).tar.gz" "$1"
  else
    echo "Missing argument"
    return 1
  fi
}

# -------------------------------------------------------------------
# file_backup: creating a backup of a file (with date)
file_backup()
{
  for FILE ; do
    [[ -e "$1" ]] && cp "$1" "${1}_$(date +%Y-%m-%d_%H-%M-%S)" || echo "\"$1\" not found." >&2
  done
}

# -------------------------------------------------------------------
# file_information: output information to a file
file_information()
{
  if [ $1 ]; then
    if [ -z $1 ]; then
      echo "$1: not found"
      return 1
    fi

    echo $1
    ls -l $1
    file $1
    ldd $1
  else
    echo "Missing argument"
    return 1
  fi
}

# -------------------------------------------------------------------
# dataurl: create a data URL from a file
dataurl()
{
  local mimeType=$(file -b --mime-type "$1")

  if [[ $mimeType == text/* ]]; then
    mimeType="${mimeType};charset=utf-8"
  fi

  echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# -------------------------------------------------------------------
# server: Start an HTTP server from a directory, optionally specifying the port
create_server()
{
  local free_port=$(netstat_free_local_port)
  local port="${1:-${free_port}}"

  sleep 1 && o "http://localhost:${port}/" &
  # Set the default Content-Type to `text/plain` instead of `application/octet-stream`
  # And serve everything as UTF-8 (although not technically correct, this doesn’t break anything for binary files)
  python -c $'import SimpleHTTPServer;\nmap = SimpleHTTPServer.SimpleHTTPRequestHandler.extensions_map;\nmap[""] = "text/plain";\nfor key, value in map.items():\n\tmap[key] = value + ";charset=UTF-8";\nSimpleHTTPServer.test();' "$port"
}

# -------------------------------------------------------------------
# phpserver: Start a PHP server from a directory, optionally specifying 2x $_ENV and ip:port
# (Requires PHP 5.4.0+.)
#
# usage:
# phpserver [port=auto] [ip=127.0.0.1] [FOO_1=BAR_1] [FOO_2=BAR_2]
phpserver()
{
  local free_port=$(netstat_free_local_port)
  local port="${1:-${free_port}}"
  local ip="${2:-127.0.0.1}"

  if [ $3 ] && [ $4 ]; then
    export ${3}=${4}
  fi

  if [ $5 ] && [ $6 ]; then
    export ${5}=${6}
  fi

  sleep 1 && o "http://${ip}:${port}/" &
  php -d variables_order=EGPCS -S ${ip}:${port}
}

# php-parse-error-check: check for parse errors
#
# usage: php-parse-error-check /var/www/web3/
php-parse-error-check()
{
  if [ $1 ]; then
    local location=$1
  else
    local location="."
  fi

  find ${location} -name "*.php" -exec php -l {} \; | grep "Parse error"
}

# -------------------------------------------------------------------
# psgrep: grep a process
psgrep()
{
  if [ ! -z $1 ] ; then
    echo "Grepping for processes matching $1..."
    ps aux | grep -i $1 | grep -v grep
  else
    echo "!! Need a process-name to grep for"
    return 1
  fi
}

# -------------------------------------------------------------------
# cpuinfo: get info about your cpu
cpuinfo()
{
  if lscpu > /dev/null 2>&1; then
    lscpu
  else
    cat /proc/cpuinfo
  fi
}

# -------------------------------------------------------------------
# json: Syntax-highlight JSON strings or files
#
# usage: json '{"foo":42}'` or `echo '{"foo":42}' | json
jsonc()
{
  if [ -t 0 ]; then # argument
    python -mjson.tool <<< "$*" | pygmentize -l javascript
  else # pipe
    python -mjson.tool | pygmentize -l javascript
  fi
}

# -------------------------------------------------------------------
# escape: Escape UTF-8 characters into their 3-byte format
escape()
{
  printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u)
  # print a newline unless we’re piping the output to another program
  if [ -t 1 ]; then
    echo # newline
  fi
}

# -------------------------------------------------------------------
# unidecode: Decode \x{ABCD}-style Unicode escape sequences
unidecode()
{
  perl -e "binmode(STDOUT, ':utf8'); print \"$@\""
  # print a newline unless we’re piping the output to another program
  if [ -t 1 ]; then
    echo # newline
  fi
}

# -------------------------------------------------------------------
# history_top_used: show your most used commands in your history
history_top_used()
{
  history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head
}

# -------------------------------------------------------------------
# getcertnames: Show all the names (CNs and SANs) listed in the
#               SSL certificate for a given domain.
#
# usage: getcertnames moelleken.org
getcertnames()
{
  if [ -z "${1}" ]; then
    echo "ERROR: No domain specified.";
    return 1;
  fi;

  local domain="${1}";
  local newline="";

  echo "Testing ${domain}…";
  echo $newline;

  local tmp=$(echo -e "GET / HTTP/1.0\nEOT" \
    | openssl s_client -connect "${domain}:443" -servername "${domain}" 2>&1);

  if [[ "${tmp}" = *"-----BEGIN CERTIFICATE-----"* ]]; then
    local certText=$(echo "${tmp}" \
      | openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
      no_serial, no_sigdump, no_signame, no_validity, no_version");
    echo "Common Name:";
    echo $newline;
    echo "${certText}" \
      | grep "Subject:" \
      | sed -e "s/^.*CN=//" \
      | sed -e "s/\/emailAddress=.*//";
    echo $newline;
    echo "Subject Alternative Name(s):";
    echo $newline;
    echo "${certText}" \
      | grep -A 1 "Subject Alternative Name:" \
      | sed -e "2s/DNS://g" -e "s/ //g" \
      | tr "," "\n" \
      | tail -n +2;
    return 0;
  else
    echo "ERROR: Certificate not found.";
    return 1;
  fi;
}

# -------------------------------------------------------------------
# tail with search highlight
#
# usage: t /var/log/Xorg.0.log [kHz]
t()
{
  if [ $# -eq 0 ]; then
    echo "Usage: t /var/log/Xorg.0.log [kHz]"
    return 1
  else
    if [ $2 ]; then
      tail -n 50 -f $1 | perl -pe "s/$2/${COLOR_LIGHT_RED}$&${COLOR_NO_COLOUR}/g"
    else
      tail -n 50 -f $1
    fi
  fi
}

# -------------------------------------------------------------------
# httpDebug: download a web page and show info on what took time
#
# usage: httpDebug http://github.com
httpDebug()
{
  curl $@ -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\n"
}

# -------------------------------------------------------------------
# digga: show dns-settings from a domain e.g. MX, IP
#
# usage: digga moelleken.org
digga()
{
  if [ $# -eq 0 ]; then
    echo "Usage: digga moelleken.org"
    return 1
  else
    dig +nocmd "$1" ANY +multiline +noall +answer
  fi
}

# -------------------------------------------------------------------
# `tre`: is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
tre()
{
  tree -haC -I '.git|node_modules|bower_components|.Spotlight-V100|.TemporaryItems|.DocumentRevisions-V100|.fseventsd' --dirsfirst "$@" | less -FRNX;
}

# -------------------------------------------------------------------
# pidenv: show PID environment in human-readable form
#
# https://github.com/darkk/home/blob/master/bin/pidenv
pidenv()
{
  local multipid=false
  local pid=""

  if [ $# = 0 ]; then
    echo "Usage: $0: pid [pid] [pid]..."
    return 0
  fi

  if [ $# -gt 1 ]; then
    multipid=true
  fi

  while [ $# != 0 ]; do
    pid=$1
    shift

    if [ -d "/proc/$pid" ]; then
      if $multipid; then
        sed "s,\x00,\n,g" < /proc/$pid/environ | sed "s,^,$pid:,"
      else
        sed "s,\x00,\n,g" < /proc/$pid/environ
      fi
    else
      echo "$0: $pid is not a pid" 1>&2
    fi
  done
}

# -------------------------------------------------------------------
# process: show process-name environment in human-readable form
processenv()
{
  if [ $# = 0 ]; then
    echo "Usage: $0: process-name"
    return 0
  fi

  pidenv $(pidof $1)
}

# -------------------------------------------------------------------
# shorturl: Create a short URL
shorturl()
{
  if [ -z "${1}" ]; then
    echo "Usage: \`shorturl url\`"
    return 1
  fi

  curl -s https://www.googleapis.com/urlshortener/v1/url \
    -H 'Content-Type: application/json' \
    -d '{"longUrl": '\"$1\"'}' | grep id | cut -d '"' -f 4
}


#source ~/.dot/eachdir