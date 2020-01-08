#!/bin/bash

function prompt_yn () 
{
    while true; do
        read -p "$1 " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Read a single char from /dev/tty, prompting with "$*"
# Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
# See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.
function get_keypress {
  local REPLY IFS=
  >/dev/tty printf '%s' "$*"
  [[ $ZSH_VERSION ]] && read -rk1  # Use -u0 to read from STDIN
  # See https://unix.stackexchange.com/q/383197/143394 regarding '\n' -> ''
  [[ $BASH_VERSION ]] && </dev/tty read -rn1
  printf '%s' "$REPLY"
}

# Get a y/n from the user, return yes=0, no=1 enter=$2
# Prompt using $1.
# If set, return $2 on pressing enter, useful for cancel or defualting
function get_yes_keypress {
  local prompt="${1:-Are you sure [y/n]? }"
  local enter_return=$2
  local REPLY
  # [[ ! $prompt ]] && prompt="[y/n]? "
  while REPLY=$(get_keypress "$prompt"); do
    [[ $REPLY ]] && printf '\n' # $REPLY blank if user presses enter
    case "$REPLY" in
      Y|y)  return 0;;
      N|n)  return 1;;
      '')   [[ $enter_return ]] && return "$enter_return"
    esac
  done
}

# Credit: http://unix.stackexchange.com/a/14444/143394
# Prompt to confirm, defaulting to NO on <enter>
# Usage: confirm "Dangerous. Are you sure?" && rm *
function confirm {
  local prompt="${*:-Are you sure} [y/N]? "
  get_yes_keypress "$prompt" 1
}    

# Prompt to confirm, defaulting to YES on <enter>
function confirm_yes {
  local prompt="${*:-Are you sure} [Y/n]? "
  get_yes_keypress "$prompt" 0
}

#prints all functions from file
function scriptInfoPerl() {
  if [ -z "${1}" ]; then
    echo "Usage: scriptInfoPerl file"
    file="$HOME"/.dot/.bash_functions.sh
    #return 1
  fi

  perl -0777 -ne '
      while (/^((?:[ \t]*\#.*\n)*)               # preceding comments
              [ \t]*(?:(\w+)[ \t]*\(\)|         # foo ()
                        function[ \t]+(\w+).*)   # function foo
              ((?:\n[ \t]+\#.*)*)               # following comments
            /mgx) {
          $name = "$2$3";
          $comments = "$1$4";
          $comments =~ s/^[ \t]*#+/#/mg;
          chomp($comments);
          print "\033[31m$name\033[0;37m()\n\033[32m$comments\n";
      }' "$file"
}
#prints all functions from file
function scriptInfoPerl_forGithub() {
  if [ -z "${1}" ]; then
    echo "Usage: scriptInfoPerl file"
    file="$HOME"/.dot/.bash_functions.sh
    #return 1
  else
    file="${1}"  
  fi

  perl -0777 -ne '
      while (/^((?:[ \t]*\#.*\n)*)               # preceding comments
              [ \t]*(?:(\w+)[ \t]*\(\)|         # foo ()
                        function[ \t]+(\w+).*)   # function foo
              ((?:\n[ \t]+\#.*)*)               # following comments
            /mgx) {
          $name = "# $2$3";
          $comments = "$1$4";
          $comments =~ s/^[ \t]*//mg;
          chomp($comments);
          $comments =~ s/#/>*/ig;
          print "$name()\n$comments\n";
      }' "$file"
}
#prints all functions from file
function AliasInfoPerl_forGithub() {
  if [ -z "${1}" ]; then
    echo "Usage: AliasInfoPerl_forGithub file"
    file="$HOME"/.dot/.bash_aliases
    #return 1
  else
    file="${1}"  
  fi

  perl -0777 -ne '
      while (/^((?:[ \t]*\#.*\n)*)               # preceding comments
              [ \t]*(?:(\w+)[ \t]*\(\)|         # foo ()
                        alias [ \t]+(\w+).*)   # function foo
              ((?:\n[ \t]+\#.*)*)               # following comments
            /mgx) {
          $name = "# $2$3";
          $comments = "$1$4";
          $comments =~ s/^[ \t]*//mg;
          chomp($comments);
          $comments =~ s/#/>*/ig;
          print "$name\n$comments\n";
      }' "$file"
}

function create_github_docs(){
  scriptInfoPerl_forGithub "$HOME"/.dot/.bash_functions.sh > "$HOME"/.dot/docs/bash_functions.md
  scriptInfoPerl_forGithub "$HOME"/.dot/asuswrt/asus_bash_functions.sh > "$HOME"/.dot/docs/asus_bash_functions.md
  scriptInfoPerl_forGithub "$HOME"/.dot/raspi/raspi_bash_functions.sh > "$HOME"/.dot/docs/raspi_bash_functions.md

  scriptInfoPerl_forGithub "$HOME"/.dot/.bash_functions.sh > "$HOME"/git/corgan2222/dotfiles.wiki/functions.md
  scriptInfoPerl_forGithub "$HOME"/.dot/asuswrt/asus_bash_functions.sh > "$HOME"/git/corgan2222/dotfiles.wiki/asus_bash_functions.md
  scriptInfoPerl_forGithub "$HOME"/.dot/raspi/raspi_bash_functions.sh > "$HOME"/git/corgan2222/dotfiles.wiki/raspi_bash_functions.md

  AliasInfoPerl_forGithub "$HOME"/.dot/.bash_aliases > "$HOME"/.dot/docs/bash_aliases.md
  AliasInfoPerl_forGithub "$HOME"/.dot/asuswrt/.bash_aliases > "$HOME"/.dot/docs/bash_aliases_asus.md
  AliasInfoPerl_forGithub "$HOME"/.dot/raspi/.bash_aliases > "$HOME"/.dot/docs/bash_aliases_raspi.md
  AliasInfoPerl_forGithub "$HOME"/.dot/synology/.bash_aliases > "$HOME"/.dot/docs/bash_aliases_synology.md
  AliasInfoPerl_forGithub "$HOME"/.dot/ubuntu16/.bash_aliases > "$HOME"/.dot/docs/bash_aliases_ubuntu16.md

  AliasInfoPerl_forGithub "$HOME"/.dot/.bash_aliases > "$HOME"/git/corgan2222/dotfiles.wiki/bash_aliases.md
  AliasInfoPerl_forGithub "$HOME"/.dot/asuswrt/.bash_aliases > "$HOME"/git/corgan2222/dotfiles.wiki/bash_aliases_asus.md
  AliasInfoPerl_forGithub "$HOME"/.dot/raspi/.bash_aliases > "$HOME"/git/corgan2222/dotfiles.wiki/bash_aliases_raspi.md
  AliasInfoPerl_forGithub "$HOME"/.dot/synology/.bash_aliases > "$HOME"/git/corgan2222/dotfiles.wiki/bash_aliases_synology.md
  AliasInfoPerl_forGithub "$HOME"/.dot/ubuntu16/.bash_aliases > "$HOME"/git/corgan2222/dotfiles.wiki/bash_aliases_ubuntu16.md

}


#return 0 on exist and 1 if not
function_exists() {
  declare -f -F $1 >/dev/null
  return $?
}

#usage findStringInFiles /etc foo exclud
#"Usage:  findStringInFiles 'string' 'folder' ['exclude']"
function findStringInFiles() {
  if [ -z "${1}" ]; then
    echo "Usage:  findStringInFiles 'string' 'folder' ['exclude']"
    return 1
  fi

  if [ -z "${2}" ]; then
    echo "Usage:  findStringInFiles 'string' 'folder' ['exclude']"
    return 1
  fi

  if [ $# -eq 3 ]; then
    grep --exclude="$3" -rnw "$2" -e "$1"
  else
    grep -rnw "$2" -e "$1"
  fi
}

#create ssh files for new user
function createUserSSH() {

  if [ ! -d "~/.ssh" ]; then
    cd ~
    mkdir .ssh
    chmod 700 ~/.ssh
  else
    echo "Folder ~/.ssh exists"  
  fi

  if [ ! -f "~/.ssh/authorized_keys" ]; then    
    cd ~/.ssh
    touch authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    ssh-keygen
    cat id_rsa.pub >> authorized_keys

    if get_yes_keypress "Create id_rsa.ppk putty version? Will install putty-tools. Do you like this [y/n]? "
    then 
        echo "install putty-tools"
        sudo apt-get install putty-tools
        puttygen id_rsa -o id_rsa.ppk
    fi

    if get_yes_keypress "Convert PPK Files to Private and Public Keys with puttygen ? [y/n]? "
    then 
        echo "puttygen id_rsa.ppk"
        puttygen id_rsa.ppk -O private-openssh -o my_key.private
        puttygen id_rsa.ppk -O public-openssh -o my_key.public
    fi

    
  else
    echo "file ~/.ssh/authorized_keys exists"  
  fi  
  

}

function user_add_with_pass_and_folder()
{
  if [ $(id -u) -eq 0 ]; then
    read -p "Enter username : " username
    read -s -p "Enter password : " password
    egrep "^$username" /etc/passwd >/dev/null
    if [ $? -eq 0 ]; then
      echo "$username exists!"
      exit 1
    else
      pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
      useradd -m -p $pass $username
      [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"

        read -r -p "Add home folder /home/$username [Y/n]" response
        response=${response,,} # tolower
        if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
            
      
          mkdir /home/$username
          #git clone https://github.com/corgan2222/dotfiles.git /home/$username
          chown $username:root /home/$username

          [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
      fi
    fi
  else
    echo "Only root may add a user to the system"
    exit 2
  fi

}

function user_remove()
{

  if [ $(id -u) -eq 0 ]; then
    read -p "Enter username : " username
    egrep "^$username" /etc/passwd >/dev/null
    if [ $? -eq 0 ]; then
      read -r -p "shure to remove and the homefolder /home/$username [Y/n]" response
      response=${response,,} # tolower
      if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then

        userdel $username                
        sudo rm -R /home/$username -f                             

        [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
      fi
    else
      echo "$username dont exists!"
      exit 1
    fi
  else
    echo "Only root may delete a user"
    exit 2
  fi
}

#replaceStringInFile 'string' 'replace' file"
function replaceStringInFile()
{
  if [ -z "${1}" ]; then
    echo "Usage:  replaceStringInFile 'string' 'replace' file"
    return 1
  fi

  if [ -z "${2}" ]; then
    echo "Usage:  replaceStringInFile 'string' 'replace' file"
    return 1
  fi

   if [ -f "${3}" ]; then
    echo "file $3 not found"
    return 1
  fi

  sed -i 's/"$1"/"$2"/g' $3
 #sed -i 's/old-word/new-word/g' file
}

#GetFilelist_clean /home/user
function GetFilelist_clean()
{
  find "$1" -type f -printf "%f\n"
  #find ../PATH/TO/FOLDER/TO/LIST/FILES/FROM -type f -printf "%f\n"
}

#GetFilelist_prefix ../PATH/TO/FOLDER/TO/LIST/FILES/FROM -type f -printf "%f\n
function GetFilelist_prefix()
{
  #GetFilelist_prefix folder prefix
  find "$1" -type f -printf "$2%f\n"
  #find ../PATH/TO/FOLDER/TO/LIST/FILES/FROM -type f -printf "%f\n"
}

#init homeShick
function initHome() {
  /bin/bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
}

#save changes in dotfiles
function saveHome() 
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

#load newest dotfiles
function loadHome() {
  homeshick pull dotfiles  
  homeshick link
  reload
}

#check dotfiles
function checkHome() {
  homeshick check dotfiles
}

#save git infos
function gitSaveCredential() {
  git config credential.helper store
  git pull
}

#add new files or folder to dotfiles
function addToHome() {
  if [ $# -eq 0 ]; then
    echo "usage addToHome [file, file, folder]"
    return 1
  else
    homeshick track dotfiles "${1}"
  fi
}

#create folder and enter it
function mkcdir() {
  mkdir -p -- "$1" &&
    cd -P -- "$1"
}

#kill all processess
function psKillAllX() {
  if [ $# -eq 0 ]; then
    echo "usage addToHome [file, file, folder]"
    return 1
  else
    ps -ef | grep "${1}" | grep -v grep | awk '{print $2}' | xargs -r kill -9
  fi
}

# Convert video to gif file.
# Usage: video2gif video_file (scale) (fps)
function video2gif() {
  ffmpeg -y -i "${1}" -vf fps=${3:-10},scale=${2:-320}:-1:flags=lanczos,palettegen "${1}.png"
  ffmpeg -i "${1}" -i "${1}.png" -filter_complex "fps=${3:-10},scale=${2:-320}:-1:flags=lanczos[x];[x][1:v]paletteuse" "${1}".gif
  rm "${1}.png"
}

#color man
function man() {
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
extract() {
  if [ -f $1 ]; then
    case $1 in
    *.tar.bz2) tar xjf $1 ;;
    *.tar.gz) tar xzf $1 ;;
    *.bz2) bunzip2 $1 ;;
    *.rar) rar x $1 ;;
    *.gz) gunzip $1 ;;
    *.tar) tar xf $1 ;;
    *.tbz2) tar xjf $1 ;;
    *.tgz) tar xzf $1 ;;
    *.zip) unzip $1 ;;
    *.Z) uncompress $1 ;;
    *.7z) 7z x $1 ;;
    *.exe) cabextract $1 ;;
    *)
      echo "'$1' cannot be extracted via extract"
      false
      ;;
    esac
  else
    'echo' -e "'$1' is not a valid file\nusage: extract <file>\n"
    false
  fi
}

#create folder with the current date
function mkdatedir() {
  mkdir "$(date +%Y-%m-%d_${1})"
}

#create gif 
#Usage: gifify <file_path>' 
function gifify() {
  [ -z "$1" ] && echo 'Usage: gifify <file_path>' && return 1
  [ ! -f "$1" ] && echo "File $1 does not exist" && return 1
  ffmpeg -i "$1" -r 10 -vcodec png out-static-%05d.png
  time convert -verbose +dither -layers Optimize -resize 1600x1600\> out-static*.png GIF:- | gifsicle --colors 128 --delay=5 --loop --optimize=3 --multifile - >"$1.gif"
  rm out-static*.png
}

# get current branch in git repo
function parse_git_branch() {
  BRANCH=$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
  if [ ! "${BRANCH}" == "" ]; then
    STAT=$(parse_git_dirty)
    echo "[${BRANCH}${STAT}]"
  else
    echo ""
  fi
}

# get current status of git repo
function parse_git_dirty() {
  status=$(git status 2>&1 | tee)
  dirty=$(
    echo -n "${status}" 2>/dev/null | grep "modified:" &>/dev/null
    echo "$?"
  )
  untracked=$(
    echo -n "${status}" 2>/dev/null | grep "Untracked files" &>/dev/null
    echo "$?"
  )
  ahead=$(
    echo -n "${status}" 2>/dev/null | grep "Your branch is ahead of" &>/dev/null
    echo "$?"
  )
  newfile=$(
    echo -n "${status}" 2>/dev/null | grep "new file:" &>/dev/null
    echo "$?"
  )
  renamed=$(
    echo -n "${status}" 2>/dev/null | grep "renamed:" &>/dev/null
    echo "$?"
  )
  deleted=$(
    echo -n "${status}" 2>/dev/null | grep "deleted:" &>/dev/null
    echo "$?"
  )
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

function git-search() {
  git log --all -S"$@" --pretty=format:%H | map git show
}

function nonzero_return() {
  RETVAL=$?
  [ $RETVAL -ne 0 ] && echo "$RETVAL"
}

# lc: Convert the parameters or STDIN to lowercase.
function lc() {
  if [ $# -eq 0 ]; then
    python -c 'import sys; print sys.stdin.read().decode("utf-8").lower()'
  else
    for i in "$@"; do
      echo $i | python -c 'import sys; print sys.stdin.read().decode("utf-8").lower()'
    done
  fi
}

# uc: Convert the parameters or STDIN to uppercase.
function uc() {
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
function wtfis() {
  local cmd=""
  local type_tmp=""
  local type_command=""
  local i=1
  local ret=0

  if [ -n "$BASH_VERSION" ]; then
    type_command="type -p"
  else
    type_command=(whence -p) # changes variable type as well
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
          read -d ' ' alias_ <<<"$alias_"

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
        (COLUMNS=10000 man "$(basename "$path_tmp")" 2>/dev/null) | col -b |
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
          cd "$(dirname "$path_tmp")" &&
            echo "$PWD/$(basename "$path_tmp")" ||
            echo "$path_tmp"
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
function whenis() {
  # Default GNU date format as seen in date.c from GNU coreutils.
  local format='%a %b %e %H:%M:%S %Z %Y'
  if [[ "$1" =~ ^--format= ]]; then
    format="${1#--format=}"
    shift
  fi

  # Concatenate all arguments as one string specifying the date.
  local date="$*"
  if [[ "$date" =~ ^[[:space:]]*$ ]]; then
    date='now'
  elif [[ "$date" =~ ^[0-9]{13}$ ]]; then
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
function box() {
  local t="$1xxxx"
  local c=${2:-"#"}

  echo ${t//?/$c}
  echo "$c $1 $c"
  echo ${t//?/$c}
}

# -------------------------------------------------------------------
# htmlEntityToUTF8: convert html-entity to UTF-8
function htmlEntityToUTF8() {
  if [ $# -eq 0 ]; then
    echo "Usage: htmlEntityToUTF8 \"&#9661;\""
    return 1
  else
    echo $1 | recode html..UTF8
  fi
}

# -------------------------------------------------------------------
# UTF8toHtmlEntity: convert UTF-8 to html-entity
function UTF8toHtmlEntity() {
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
function optiImages() {
  find . -iname '*.png' -exec optipng -o7 {} \;
  find . -iname '*.jpg' -exec jpegoptim --force {} \;
}

# -------------------------------------------------------------------
# lman: Open the manual page for the last command you executed.
function lman() {
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
function testConnection() {
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
function netstat_used_local_ports() {
  netstat -atn |
    awk '{printf "%s\n", $4}' |
    grep -oE '[0-9]*$' |
    sort -n |
    uniq
}

# -------------------------------------------------------------------
# netstat_free_local_port: get one free tcp-port
function netstat_free_local_port() {
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
netstat_connection_overview() {
  netstat -nat |
    awk '{print $6}' |
    sort |
    uniq -c |
    sort -n
}

# -------------------------------------------------------------------
# nice mount (http://catonmat.net/blog/another-ten-one-liners-from-commandlingfu-explained)
#
# displays mounted drive information in a nicely formatted manner
mount_info() {
  (echo "DEVICE PATH TYPE FLAGS" && mount | awk '$2="";1') |
    column -t
}

function mountFile(){
 mkdir -p $1/$2
# sudo mount -o loop ~/DVDCOPY.iso /media/mount/folder/for/iso

}

# -------------------------------------------------------------------
# sniff: view HTTP traffic
#
# usage: sniff [eth0]
function sniff() {
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
function httpdump() {
  if [ $1 ]; then
    local device=$1
  else
    local device='eth0'
  fi

  sudo tcpdump -i ${device} -n -s 0 -w - | grep -a -o -E \"Host\: .* | GET \/.*\"
}

# -------------------------------------------------------------------
# iptablesBlockIP: block a IP via "iptables"
#
# usage: iptablesBlockIP 8.8.8.8
function iptablesBlockIP() {
  if [ $# -eq 0 ]; then
    echo "Usage: iptablesBlockIP 123.123.123.123"
    return 1
  else
    sudo iptables -A INPUT -s $1 -j DROP
  fi
}

# -------------------------------------------------------------------
# ips: get the local IP's
function ips() {
  ifconfig | grep "inet " | awk '{ print $2 }' | cut -d ":" -f 2
}

# -------------------------------------------------------------------
# os-info: show some info about your system
function os-info() {
  lsb_release -a
  uname -a

  if [ -z /etc/lsb-release ]; then
    cat /etc/lsb-release
  fi

  if [ -z /etc/issue ]; then
    cat /etc/issue
  fi

  if [ -z /proc/version ]; then
    cat /proc/version
  fi
}

# -------------------------------------------------------------------
# command_exists: check if a command exists
function command_exists() {
  return type "$1" &>/dev/null
}

# -------------------------------------------------------------------
# stripspace: strip unnecessary whitespace from file
function stripspace() {
  if [ $# -eq 0 ]; then
    echo "Usage: stripspace FILE"
    exit 1
  else
    local tempfile=mktemp
    git stripspace <"$1" >tempfile
    mv tempfile "$1"
  fi
}

# -------------------------------------------------------------------
# logssh: establish ssh connection + write a logfile
function logssh() {
  ssh $1 | tee sshlog
}

# -------------------------------------------------------------------
# lsssh: pretty print all established SSH connections
function lsssh() {
  local ip=""
  local domain=""
  local conn=""

  lsof -i4 -s TCP:ESTABLISHED -n | grep '^ssh' | while read conn; do
    ip=$(echo $conn | grep -oE '\->[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[^ ]+')
    ip=${ip/->/}
    domain=$(dig -x ${ip%:*} +short)
    domain=${domain%.}
    # display nonstandard port if relevant
    printf "%s (%s)\n" $domain ${ip/:ssh/}
  done | column -t
}

# -------------------------------------------------------------------
# calc: Simple calculator
# usage: e.g.: 3+3 || 6*6/2
function calc() {
  local result=""
  result="$(printf "scale=10;$*\n" | bc --mathlib | tr -d '\\\n')"
  #                       └─ default (when `--mathlib` is used) is 20
  #
  if [[ "$result" == *.* ]]; then
    # improve the output for decimal numbers
    printf "$result" |
      sed -e 's/^\./0./' $(# add "0" for cases like ".5"` \
        -e 's/^-\./-0./'
      ) # add "0" for cases like "-.5"`\
    -e 's/0*$//;s/\.$//' # remove trailing zeros
  else
    printf "$result"
  fi
  printf "\n"
}

# -------------------------------------------------------------------
# mkd: Create a new directory and enter it
function mkd() {
  mkdir -p "$@" && cd "$_"
}

# -------------------------------------------------------------------
# mkf: Create a new directory, enter it and create a file
#
# usage: mkf /tmp/lall/foo.txt
function mkf() {
  mkd $(dirname "$@") && touch $@
}

# -------------------------------------------------------------------
# rand_int: use "urandom" to get random int values
#
# usage: rand_int 8 --> e.g.: 32245321
function rand_int() {
  if [ $1 ]; then
    local length=$1
  else
    local length=16
  fi

  tr -dc 0-9 </dev/urandom | head -c${1:-${length}}
}

# -------------------------------------------------------------------
# passwdgen: a password generator
#
# usage: passwdgen 8 --> e.g.: f4lwka_2f
function passwdgen() {
  if [ $1 ]; then
    local length=$1
  else
    local length=16
  fi

  tr -dc A-Za-z0-9_ </dev/urandom | head -c${1:-${length}}
}

# -------------------------------------------------------------------
# targz: Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression
function targz() {
  local tmpFile="${@%/}.tar"
  tar -cvf "${tmpFile}" --exclude=".DS_Store" "${@}" || return 1

  local size=$(
    stat -f"%z" "${tmpFile}" 2>/dev/null # OS X `stat`
    stat -c"%s" "${tmpFile}" 2>/dev/null # GNU `stat`
  )

  local cmd=""
  if ((size < 52428800)) && hash zopfli 2>/dev/null; then
    # the .tar file is smaller than 50 MB and Zopfli is available; use it
    cmd="zopfli"
  else
    if hash pigz 2>/dev/null; then
      cmd="pigz"
    else
      cmd="gzip"
    fi
  fi

  echo "Compressing .tar ($((size / 1000)) kB) using \`${cmd}\`…"
  "${cmd}" -v "${tmpFile}" || return 1
  [ -f "${tmpFile}" ] && rm "${tmpFile}"

  local zippedSize=$(
    stat -f"%z" "${tmpFile}.gz" 2>/dev/null # OS X `stat`
    stat -c"%s" "${tmpFile}.gz" 2>/dev/null # GNU `stat`
  )

  echo "${tmpFile}.gz ($((zippedSize / 1000)) kB) created successfully."
}

# -------------------------------------------------------------------
# duh: Sort the "du"-command output and use human-readable units.
function duh() {
  local unit=""
  local size=""

  du -k "$@" | sort -n | while read size fname; do
    for unit in KiB MiB GiB TiB PiB EiB ZiB YiB; do
      if [ "$size" -lt 1024 ]; then
        echo -e "${size} ${unit}\t${fname}"
        break
      fi
      size=$((size / 1024))
    done
  done
}

# -------------------------------------------------------------------
# fs: Determine size of a file or total size of a directory
function fs() {
  if du -b /dev/null >/dev/null 2>&1; then
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
function ff() {
  find . -type f -iname '*'$*'*' -ls
}

# -------------------------------------------------------------------
# fstr: find text in files
function fstr() {
  OPTIND=1
  local case=""
  local usage="fstr: find string in files.
  Usage: fstr [-i] \"pattern\" [\"filename pattern\"] "

  while getopts :it opt; do
    case "$opt" in
    i) case="-i " ;;
    *)
      echo "$usage"
      return
      ;;
    esac
  done

  shift $(($OPTIND - 1))
  if [ "$#" -lt 1 ]; then
    echo "$usage"
    return 1
  fi

  find . -type f -name "${2:-*}" -print0 |
    xargs -0 egrep --color=auto -Hsn ${case} "$1" 2>&- |
    more
}

# -------------------------------------------------------------------
# file_backup_compressed: create a compressed backup (with date)
# in the current dir
#
# usage: file_backup_compressed test.txt
function file_backup_compressed() {
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
function file_backup() {
  for FILE; do
    [[ -e "$1" ]] && cp "$1" "${1}_$(date +%Y-%m-%d_%H-%M-%S)" || echo "\"$1\" not found." >&2
  done
}

# -------------------------------------------------------------------
# file_information: output information to a file
function file_information() {
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
function dataurl() {
  local mimeType=$(file -b --mime-type "$1")

  if [[ $mimeType == text/* ]]; then
    mimeType="${mimeType};charset=utf-8"
  fi

  echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# -------------------------------------------------------------------
# server: Start an HTTP server from a directory, optionally specifying the port
function create_server() {
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
function phpserver() {
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
function php-parse-error-check() {
  if [ $1 ]; then
    local location=$1
  else
    local location="."
  fi

  find ${location} -name "*.php" -exec php -l {} \; | grep "Parse error"
}

# -------------------------------------------------------------------
# psgrep: grep a process
function psgrep() {
  if [ ! -z $1 ]; then
    echo "Grepping for processes matching $1..."
    ps aux | grep -i $1 | grep -v grep
  else
    echo "!! Need a process-name to grep for"
    return 1
  fi
}

# -------------------------------------------------------------------
# cpuinfo: get info about your cpu
function cpuinfo() {
  if lscpu >/dev/null 2>&1; then
    lscpu
  else
    cat /proc/cpuinfo
  fi
}

# -------------------------------------------------------------------
# json: Syntax-highlight JSON strings or files
#
# usage: json '{"foo":42}'` or `echo '{"foo":42}' | json
function jsonc() {
  if [ -t 0 ]; then # argument
    python -mjson.tool <<<"$*" | pygmentize -l javascript
  else # pipe
    python -mjson.tool | pygmentize -l javascript
  fi
}

# -------------------------------------------------------------------
# escape: Escape UTF-8 characters into their 3-byte format
function escape() {
  printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u)
  # print a newline unless we’re piping the output to another program
  if [ -t 1 ]; then
    echo # newline
  fi
}

# -------------------------------------------------------------------
# unidecode: Decode \x{ABCD}-style Unicode escape sequences
function unidecode() {
  perl -e "binmode(STDOUT, ':utf8'); print \"$@\""
  # print a newline unless we’re piping the output to another program
  if [ -t 1 ]; then
    echo # newline
  fi
}

# -------------------------------------------------------------------
# history_top_used: show your most used commands in your history
function history_top_used() {
  history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head
}

# -------------------------------------------------------------------
# getcertnames: Show all the names (CNs and SANs) listed in the
#               SSL certificate for a given domain.
#
# usage: getcertnames moelleken.org
function getcertnames() {
  if [ -z "${1}" ]; then
    echo "ERROR: No domain specified."
    return 1
  fi

  local domain="${1}"
  local newline=""

  echo "Testing ${domain}…"
  echo $newline

  local tmp=$(echo -e "GET / HTTP/1.0\nEOT" |
    openssl s_client -connect "${domain}:443" -servername "${domain}" 2>&1)

  if [[ "${tmp}" == *"-----BEGIN CERTIFICATE-----"* ]]; then
    local certText=$(echo "${tmp}" |
      openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
      no_serial, no_sigdump, no_signame, no_validity, no_version")
    echo "Common Name:"
    echo $newline
    echo "${certText}" |
      grep "Subject:" |
      sed -e "s/^.*CN=//" |
      sed -e "s/\/emailAddress=.*//"
    echo $newline
    echo "Subject Alternative Name(s):"
    echo $newline
    echo "${certText}" |
      grep -A 1 "Subject Alternative Name:" |
      sed -e "2s/DNS://g" -e "s/ //g" |
      tr "," "\n" |
      tail -n +2
    return 0
  else
    echo "ERROR: Certificate not found."
    return 1
  fi
}

# -------------------------------------------------------------------
# tail with search highlight
#
# usage: t /var/log/Xorg.0.log [kHz]
function t() {
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
function httpDebug() {
  curl $@ -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\n"
}

# -------------------------------------------------------------------
# digga: show dns-settings from a domain e.g. MX, IP
#
# usage: digga moelleken.org
function digga() {
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
function tre() {
  tree -haC -I '.git|node_modules|bower_components|.Spotlight-V100|.TemporaryItems|.DocumentRevisions-V100|.fseventsd' --dirsfirst "$@" | less -FRNX
}

# -------------------------------------------------------------------
# pidenv: show PID environment in human-readable form
#
# https://github.com/darkk/home/blob/master/bin/pidenv
function pidenv() {
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
        sed "s,\x00,\n,g" </proc/$pid/environ | sed "s,^,$pid:,"
      else
        sed "s,\x00,\n,g" </proc/$pid/environ
      fi
    else
      echo "$0: $pid is not a pid" 1>&2
    fi
  done
}

# -------------------------------------------------------------------
# process: show process-name environment in human-readable form
function processenv() {
  if [ $# = 0 ]; then
    echo "Usage: $0: process-name"
    return 0
  fi

  pidenv $(pidof $1)
}

# -------------------------------------------------------------------
# shorturl: Create a short URL
function shorturl() {
  if [ -z "${1}" ]; then
    echo "Usage: \`shorturl url\`"
    return 1
  fi

  curl -s https://www.googleapis.com/urlshortener/v1/url \
    -H 'Content-Type: application/json' \
    -d '{"longUrl": '\"$1\"'}' | grep id | cut -d '"' -f 4
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Process phone photo.
function ppp() {

  # Check if ImageMagick's convert command-line tool is installed.

  if ! command -v "convert" $ >/dev/null; then
    printf "Please install ImageMagick's 'convert' command-line tool!"
    exit
  fi

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  declare option="$1"
  declare photo="${2:-*.jpg}"
  declare geometry="${3:-50%}"

  if [ "$option" != "clean" ] &&
    [ "$option" != "resize" ]; then
    option="resize"
    photo="${1:-*.jpg}"
    geometry="${2:-50%}"
  fi

  if [[ "$(echo "${photo##*.}" | tr '[:upper:]' '[:lower:]')" != "png" ]]; then
    newPhotoName="${photo%.*}.png"
  else
    newPhotoName="_${photo%.*}.png"
  fi

  if [ "$option" == "resize" ]; then
    convert "$photo" \
      -colorspace RGB \
      +sigmoidal-contrast 11.6933 \
      -define filter:filter=Sinc \
      -define filter:window=Jinc \
      -define filter:lobes=3 \
      -sigmoidal-contrast 11.6933 \
      -colorspace sRGB \
      -background transparent \
      -gravity center \
      -resize "$geometry" \
      +append \
      "$newPhotoName" &&
      printf "* %s (%s)\n" \
        "$newPhotoName" \
        "$geometry"

    return
  fi

  convert "$photo" \
    -morphology Convolve DoG:10,10,0 \
    -negate \
    -normalize \
    -blur 0x1 \
    -channel RBG \
    -level 10%,91%,0.1 \
    "$newPhotoName" &&
    printf "* %s\n" "$newPhotoName"

}


# Search history.
#           ┌─ enable colors for pipe
#           │  ("--color=auto" enables colors only if
#           │  the output is in the terminal)
#grep --color=always "$*" "$HISTFILE" | less -RX
# display ANSI color escape sequences in raw form ─┘│
#       don't clear the screen after quitting less ─┘
function qh() {
  grep --color=always "$*" "$HISTFILE" | less -RX
}

# Search for text within the current directory.
#grep -ir --color=always "$*" --exclude-dir=".git" --exclude-dir="node_modules" . | less -RX
#     │└─ search all files under each directory, recursively
#     └─ ignore case
function qt() {
  grep -ir --color=always "$*" --exclude-dir=".git" --exclude-dir="node_modules" . | less -RX
}

# Print a line of dashes or the given string across the entire screen.
function line() {
  width=$(tput cols)
  str=${1--}
  len=${#str}
  for ((i = 0; i < $width; i += $len)); do
    echo -n "${str:0:$(($width - $i))}"
  done
  echo
}
# Print the given text in the center of the screen.
function center() {
  width=$(tput cols)
  str="$@"
  len=${#str}
  [ $len -ge $width ] && echo "$str" && return
  for ((i = 0; i < $(((($width - $len)) / 2)); i++)); do
    echo -n " "
  done
  echo "$str"
}

# Open the man page for the previous command.
function lman() {
  set -- $(fc -nl -1)
  while [ "$#" -gt 0 -a '(' "sudo" = "$1" -o "-" = "${1:0:1}" ')' ]; do shift; done
  man "$1" || help "$1"
}

function xxgetmac() {
  if [ $# -eq 1 ]; then
    ip -o link show dev $1 | grep -Po 'ether \K[^ ]*'
    return 1
  fi
  echo 'Usage: xxgetmac INTERFACE'
}


##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
function to_lower() {
  local str="$@"
  local output
  output=$(tr '[A-Z]' '[a-z]' <<<"${str}")
  echo $output
}

##################################################################
# Purpose: Display an error message and die
# Arguments:
#   $1 -> Message
#   $2 -> Exit status (optional)
function die() {
  local m="$1"   # message
  local e=${2-1} # default exit status 1
  echo "$m"
  exit $e
}

##################################################################
# Purpose: Return true if script is executed by the root user
# Arguments: none
# Return: True or False
function is_root() {
  [ $(id -u) -eq 0 ] && return $TRUE || return $FALSE
}

##################################################################
# Purpose: Return true $user exits in /etc/passwd
# Arguments: $1 (username) -> Username to check in /etc/passwd
# Return: True or False
function is_user_exits() {
  local u="$1"
  grep -q "^${u}" $PASSWD_FILE && return $TRUE || return $FALSE
}

##################################################################
# Purpose: return last mod time of a given file
# Arguments: $1 (file)
# Return:  18:30:14 06-08-2019
# % stat -c '%y' foobar.txt
# 2016-07-26 12:15:16.897284828 +0600

# % stat -c '%Y' foobar.txt
# 1469513716

# % stat -c '%y : %n' foobar.txt
# 2016-07-26 12:15:16.897284828 +0600 : foobar.txt

# % stat -c '%Y : %n' foobar.txt
# 1469513716 : foobar.txt

# If you want the output like Tue Jul 26 15:20:59 BST 2016, use the Epoch time as input to date:

# % date -d "@$(stat -c '%Y' a.out)" '+%a %b %d %T %Z %Y'
# Tue Jul 26 12:15:21 BDT 2016

# % date -d "@$(stat -c '%Y' a.out)" '+%c'
# Tue 26 Jul 2016 12:15:21 PM BDT

# % date -d "@$(stat -c '%Y' a.out)"
# Tue Jul 26 12:15:21 BDT 2016
# date -r .bashrc Tue Aug  6 19:14:12 CEST 2019
##################################################################
function lastFileChange() {
  if [ -z "${1}" ]; then
    echo "Usage: lastFileChange folder"
    return 1
  fi

  date -r $1 +'%H:%M:%S %d-%m-%Y'
  #LAST=$(date -r $1 +'%H:%M:%S %d-%m-%Y ')
}

# lastmod(){
#      #echo "Last modified" $(( $(date +%s) - $(stat -f%c "$1") )) "seconds ago"
#      #t1=date -r "$1" +%s
# }

# prints colored text
# print_style "This is a green text " "success";
# print_style "This is a yellow text " "warning";
# print_style "This is a light blue with a \t tab " "info";
# print_style "This is a red text with a \n new line " "danger";
# print_style "This has no color";
function ps() {

  if [ "$2" == "info" ]; then
    COLOR="96m"
  elif [ "$2" == "success" ]; then
    COLOR="92m"
  elif [ "$2" == "warning" ]; then
    COLOR="93m"
  elif [ "$2" == "danger" ]; then
    COLOR="91m"
  else #default color
    COLOR="0m"
  fi

  STARTCOLOR="\e[$COLOR"
  ENDCOLOR="\e[0m"

  printf "$STARTCOLOR%b$ENDCOLOR" "$1"
}

#what to do after telegraf update
function telegrafAfterUpdate() {
  echo "lnav /var/log/telegraf/telegraf.log"
  echo "locate telegraf.service"
  echo "joe /etc/systemd/system/multi-user.target.wants/telegraf.service"
  echo "joe /lib/systemd/system/telegraf.service"
  echo "joe /usr/lib/telegraf/scripts/telegraf.service"
  echo "service telegraf restart"
  echo "systemctl daemon-reload2"
  echo "service telegraf restart"
  echo "/var/log/telegraf/telegraf.log"

}

#https://coderwall.com/p/xatm5a/bash-one-liner-to-read-yaml-files
function yaml_r() {
  hashdot=$(gem list hash_dot)
  if ! [ "$hashdot" != "" ]; then sudo gem install "hash_dot"; fi
  if [ -f $1 ]; then
    cmd=" Hash.use_dot_syntax = true; hash = YAML.load(File.read('$1'));"
    if [ "$2" != "" ]; then
      cmd="$cmd puts hash.$2;"
    else
      cmd="$cmd puts hash;"
    fi
    ruby -r yaml -r hash_dot <<<$cmd
  fi
}

#info about perl
function perlver() {
  lib=${1//::/\/}
  perl -e "use $1; printf(\"%s\n\tPath:   %s\n\tVersion: %s\n\", '$1', \$INC{'$lib.pm'}, \$$1::VERSION);" 2>/dev/null || echo "$1 is not installed"
}

#all about the time
function timeInfo() {
  cat <<EOD
        Format/result           |       Command             		|          Output
--------------------------------+-----------------------------------+------------------------------
YYYY-MM-DD_hh:mm:ss             | date +%F_%T               		| $(date +%F_%T)
YYYYMMDD_hhmmss                 | date +%Y%m%d_%H%M%S       		| $(date +%Y%m%d_%H%M%S)
YYYYMMDD_hhmmss (UTC version)   | date --utc +%Y%m%d_%H%M%SZ		| $(date --utc +%Y%m%d_%H%M%SZ)
YYYYMMDD_hhmmss (with local TZ) | date +%Y%m%d_%H%M%S%Z     		| $(date +%Y%m%d_%H%M%S%Z)
YYYYMMSShhmmss                  | date +%Y%m%d%H%M%S        		| $(date +%Y%m%d%H%M%S)
YYYYMMSShhmmssnnnnnnnnn         | date +%Y%m%d%H%M%S%N      		| $(date +%Y%m%d%H%M%S%N)
YYMMDD_hhmmss                   | date +%y%m%d_%H%M%S       		| $(date +%y%m%d_%H%M%S)
		
Seconds since UNIX epoch:       | date +%s                  		| $(date +%s)
Nanoseconds only:               | date +%N                  		| $(date +%N)
Nanoseconds only:               | \`date +%s\`000000000     		| $(date +%s)000000000
Nanoseconds since UNIX epoch:   | date +%s%N                		| $(date +%s%N)
Milliseconds since UNIX epoch:  | date +%s%N                		| $(date +%s%N)/1000000))
		
ISO8601 UTC timestamp           | date --utc +%FT%TZ        		| $(date --utc +%FT%TZ)
ISO8601 UTC timestamp + ms      | date --utc +%FT%T.%3NZ    		| $(date --utc +%FT%T.%3NZ)
ISO8601 Local TZ timestamp      | date +%FT%T%Z             		| $(date +%FT%T%Z)
YYYY-MM-DD (Short day)          | date +%F\(%a\)            		| $(date +%F\(%a\))
YYYY-MM-DD (Long day)           | date +%F\(%A\)            		| $(date +%F\(%A\))

YYYY_MM_DD                      | date +%Y_%m_%d                    | $(date +%Y_%m_%d)
YYYY_MM_DD -7 Days              | date +%Y_%m_%d  --date '-7 day'   | $(date +%Y_%m_%d  --date '-7 day')

Weekday                        | date +%Y_%m_%d                    | $(date +%Y_%m_%d)
date -d "1974-01-04" +"%A"     | date -d "1974-01-04" +"%A"        | $(date -d "1974-01-04" +"%A")

------
2019-10-06 18:48:04.908930495 +0200 | stat -c "%y" file  | 
Friday                              | date -d "2019-10-06 18:48:04.908930495 +0200" +"%A" 

filecreate date stat file %w
stat -c "%w %n" * | sort
 
EOD
}

#_cheat_autocomplete
function _cheat_autocomplete() {
  sheets=$(cheat -l | cut -d' ' -f1)
  COMPREPLY=()
  if [ $COMP_CWORD = 1 ]; then
    COMPREPLY=($(compgen -W "$sheets" -- $2))
  fi
}
complete -F _cheat_autocomplete cheat

#search in aliases, functions and cheats for the string
function h() {
  if [ -z "${1}" ]; then
    echo "Usage: h 'searchstring'"
    return 1
  fi

  alias | grep -i $1
  grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)' "$HOME"/.dot/.bash_functions.sh | grep -i $1
  cheat $1

}

#wrapper for cheat.sh
#cheatsh tar~list
function cheatsh() {

  topic=$1

  case $2 in
  "--color" | "-c")
    curl cheat.sh/$topic | lolcat
    ;;
  "--pager" | "-p")
    curl cheat.sh/$topic | less
    ;;
  "--help" | "-h")
    echo "-p for pager\n -c for colorized output"
    ;;
  *)
    curl cheat.sh/$topic
    ;;
  esac

}

# ------------------------------------------------------------------------------
# | auto-completion (for bash)                                                 |
# ------------------------------------------------------------------------------

# Automatically add completion for all aliases to commands having completion functions
# source: http://superuser.com/questions/436314/how-can-i-get-bash-to-perform-tab-completion-for-my-aliases
alias_completion() {
  local namespace="alias_completion"

  # parse function based completion definitions, where capture group 2 => function and 3 => trigger
  local compl_regex='complete( +[^ ]+)* -F ([^ ]+) ("[^"]+"|[^ ]+)'
  # parse alias definitions, where capture group 1 => trigger, 2 => command, 3 => command arguments
  local alias_regex="alias ([^=]+)='(\"[^\"]+\"|[^ ]+)(( +[^ ]+)*)'"

  # create array of function completion triggers, keeping multi-word triggers together
  eval "local completions=($(complete -p | sed -rne "/$compl_regex/s//'\3'/p"))"
  ((${#completions[@]} == 0)) && return 0

  # create temporary file for wrapper functions and completions
  rm -f "/tmp/${namespace}-*.XXXXXXXXXX" # preliminary cleanup
  local tmp_file="$(mktemp "/tmp/${namespace}-${RANDOM}.XXXXXXXXXX")" || return 1

  # read in "<alias> '<aliased command>' '<command args>'" lines from defined aliases
  local line
  while read line; do
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
      local compl_func="${new_completion/#* -F /}"
      compl_func="${compl_func%% *}"
      # avoid recursive call loops by ignoring our own functions
      if [[ "${compl_func#_$namespace::}" == $compl_func ]]; then
        local compl_wrapper="_${namespace}::${alias_name}"
        echo "function $compl_wrapper {
           (( COMP_CWORD += ${#alias_arg_words[@]} ))
           COMP_WORDS=($alias_cmd $alias_args \${COMP_WORDS[@]:1})
           $compl_func
         }" >>"$tmp_file"
        new_completion="${new_completion/ -F $compl_func / -F $compl_wrapper }"
      fi
    fi

    # replace completion trigger by alias
    new_completion="${new_completion% *} $alias_name"
    echo "$new_completion" >>"$tmp_file"
  done < <(alias -p | sed -rne "s/$alias_regex/\1 '\2' '\3'/p")
  source "$tmp_file" && rm -f "$tmp_file"
}
if [ -n "$BASH_VERSION" ]; then
  alias_completion
fi
unset -f alias_completion

#Get your public IP address and host.
function getlocation() {
  lynx -dump http://www.ip-adress.com/ip_tracer/?QRY=$1 | grep address | egrep 'city|state|country' | awk '{print $3,$4,$5,$6,$7,$8}' | sed 's\ip address flag \\' | sed 's\My\\'

}

# -------------------------------------------------------------------
# err: error message along with a status information
#
# example:
#
# if ! do_something; then
#   err "Unable to do_something"
#   exit "${E_DID_NOTHING}"
# fi
#
function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

#youtube-dl
function yt2mp3() 
{

  if command -v youtube-dl >/dev/null; then
    url=$1
    youtube-dl --verbose "$url" -x --audio-format mp3
   else
    echo "cant find  youtube-dl, install via"
    echo "sudo curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl"
    echo "sudo chmod a+rx /usr/local/bin/youtube-dl"      
  fi
}

#mail tester imap
function mail_test_ssl_server_imap() {
  stats=$(openssl s_client -showcerts -connect $1:993)

  return "$stats"
}

#mail tester pop3
function mail_test_ssl_server_pop3() {
  stats=$(openssl s_client -showcerts -connect $1:995)

  echo "$stats"
}

#mail tester ssl
function mail_test_ssl_server_SMTP() {
  stats=$(openssl s_client -showcerts -connect $1:465)

  echo "$stats"
}

#mail tester imap
function mail_test_ssl_server_SMTP_star() {
  stats=$(openssl s_client -starttls smtp -showcerts -connect $1:25)

  echo "$stats"
}

#Funktion um Dateien aus dem Internet zu laden. Prüft ob curl vorhanden ist , wenn nicht wird wget versucht. Wenn gar nichts von beiden gefunden wird wird das Skript beendet.
#https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
# download an file to local storage
# need 2 parameters : get_remote_file [URL_TO_FILE] [LOCAL_PATH]
function get_remote_file() {

  if [[ ! -z "${1}" || ! -z "${2}" ]]; then
    bin_dl=""
    # check Local Path
    if [ ! -d "${2}" ]; then
      mkdir "${2}"
    fi
    # check bins
    # using command instead of which to be posix comp.

    # ------ check curl
    command -v curl >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      bin_dl="curl -s -O "
    fi

    # ------ check wget
    command -v wget >/dev/null 2>&1
    if [[ ${bin_dl} == "" && $? -eq 0 ]]; then
      bin_dl="wget -q "
    fi

    # ------ if emtpy curl and wget not found
    if [ ${bin_dl} = "" ]; then
      echo "need curl or wget for work please install one of them"
      exit 98
    fi

    # download file
    if [[ "${1}" =~ http:// || "${1}" =~ https:// || "${1}" =~ ftp:// ]]; then
      # ${1} is an remote file will be downloaded to ${2}
      cd "${2}" && {
        ${bin_dl} "${1}"
        cd -
      }
    else
      # ${1} is not an remote file EXIT !
      exit 98
    fi
  else
    echo "check parameters for function #> get_remote_file"
    exit 9
  fi
}

# Problem : Man möchte über Bash nur den Inhalt einer Zip Datei vergleichen. Die Zip Datei wird aber automatisiert auf einem Server über cron erstellt, was zur Folge hatte das der Zeitstempel und somit auch die md5 Summen unterschiedlich sind.
# Lösung : Die Lösung ist mit unzip in die Datei zu schauen und diesen Output mit diff zu verleichen.
# https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
  # compare the content of two zipfiles if equal the function return 0 otherwise 1
  # need 2 parameters : check_files_in_zip [NAME_OF_OLD_ZIPFILE] [NAME_OF_NEW_ZIPFILE]
function check_files_in_zip() {
  if [[ ! -z "${1}" || ! -z "${2}" ]]; then
    diff <(unzip -v -l "${1}" | awk '! /Archiv/ && /[0-9]/ { print $1,$5,$6,$7,$8 }' | sed '$d') <(unzip -v -l "${2}" | awk '! /Archiv/ && /[0-9]/ { print $1,$5,$6,$7,$8 }' | sed '$d') 1>/dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 0
    else
      return 1
    fi
  else
    echo "check parameters for function #> check_files_in_zip"
    exit 9
  fi
}

#geo-ip 144.178.0.0
function geo-ip() {

  if [ -z "${1}" ]; then
    echo "Usage: h 'searchstring'"
    return 1
  else

    ret=$(curl --silent "http://api.db-ip.com/v2/free/$1")
    echo "$ret"

  fi
}

# "Usage: sftp_keyfile 'keyfile' port user host"
# "sftp_keyfile PATH/TO/PUBLICKEYFILE(id_rsa) 10022 user host"
function sftp_keyfile() {

  if [ -z "${1}" ]; then
    echo "Usage: sftp_keyfile 'keyfile' port user host"
    echo "sftp_keyfile PATH/TO/PUBLICKEYFILE(id_rsa) 10022 user host"
    #echo "sftp -v -o IdentityFile="/PATH/TO/PUBLICKEYFILE(id_rsa)" -o Port="10022" user@host"
    return 1
  else

    sftp -v -o IdentityFile="$1" -o Port="$2" "$3@$4"
    

  fi
}

#"Usage: Export_image_file_statistics_to_csv 'output.csv' "
function Export_image_file_statistics_to_csv() 
{
  if [ -z "${1}" ]; then
    echo "Usage: Export_image_file_statistics_to_csv 'output.csv' "
    return 1
  fi
  
    find . -regex ".*\.\(jpg\|gif\|png\|jpeg\)" -type f -printf "%p,%AY-%Am-%AdT%AT,%CY-%Cm-%CdT%CT,%TY-%Tm-%TdT%TT,%s\n" > $1
}

#"Usage:Tabs Export_image_file_statistics_to_csv_tabs 'output.csv' "
function Export_image_file_statistics_to_csv_tabs() 
{
  if [ -z "${1}" ]; then
    echo "Usage: Export_image_file_statistics_to_csv 'output.csv' "
    return 1
  fi
  
  find . -regex ".*\.\(jpg\|gif\|png\|jpeg\)" -type f -printf "%p \t %AY-%Am-%AdT%AT \t %CY-%Cm-%CdT%CT \t %TY-%Tm-%TdT%TT \t %s\n" > filestat_data_20141201.csv
}

#convert raw to jpg
function convert_cr2_to_jpg(){

  if command -v ufraw >/dev/null; then
    echo "sudo ​apt-get install ufraw"
  else
    for i in *.CR2; do ufraw-batch $i --out-type=jpeg --output $i.jpg; done;
  fi  

}

  #Copy something from this system to some other system:
  #echo scp /path/to/local/file username@hostname:/path/to/remote/file  
function ssh_copy_to_host()
{
  scp "$3 $1@$2:$4"
}

  #Copy something from some system to some other system:
  #scp username1@hostname1:/path/to/file username2@hostname2:/path/to/other/file 	
function ssh_copy_from_host_to_host(){
 scp "$1@$2:$3 $4@$5:$6"
  
}
	
  #Copy something from another system to this system:
  #scp username@hostname:/path/to/remote/file /path/to/local/file  
function ssh_copy_fron_host(){
  scp "$1@$2:$3 $4"
}
	
#dcraw -c RAW-Dateiname | convert - Ausgabedatei.FORMAT  
function convert_CR2_to_JPG_dcraw()
{
  dcraw -c "$1" | convert - "$2.$3"
}

#curl -i -k -X GET -u root:rootpw "https://knaak.org:8443/api/v2/domains" -H  "accept: application/json"
function checkSSLfromDomain()
{  
  echo "++++++++++++++++ $1 ++++++++++++++++" ;
  echo | openssl s_client -servername NAME -connect $1:443 2>/dev/null | openssl x509 -noout -dates ; echo --------------------------------------- ;

}


# bash generate random alphanumeric string
# bash generate random 32 character alphanumeric string (upper and lowercase) and 
function random_32chars_al()
{
  NEW_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  echo $NEW_UUID
}  

# bash generate random 32 character alphanumeric string (lowercase only)
function random_32chars_lc()
{
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# Random numbers in a range, more randomly distributed than $RANDOM which is not
# very random in terms of distribution of numbers.
# bash generate random number between 0 and 9
function random_number09()
{
  cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | head --bytes 1
}

# bash generate random number between 0 and 99
function random_number099()
{
  NUMBER=$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 2)
  if [ "$NUMBER" == "" ]; then
    NUMBER=0
  fi
  echo $NUMBER
}

# bash generate random number between 0 and 999
function random_number999()
{
  NUMBER=$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 3)
  if [ "$NUMBER" == "" ]; then
    NUMBER=0
  fi
   echo $NUMBER
}

#"Usage: syncFileToS3 'file' "
function syncFileToS3()
{
  if [ -z "${1}" ]; then
    echo "Usage: syncFileToS3 'file' "
    return 1
  fi

  DATE_TODAY=$(date +%Y_%m_%d) 
  SOURCE="$1"
  DEST="$CONST_USER_AT_SERVER::Medien/tmp/sync_tmp/$DATE_TODAY/"
  rsync -av -e "ssh -p 223" "$SOURCE" "$DEST";  
}


# changelog_(){
#     if (( $# != 1 )); then
#         echo "Usage: ${FUNCNAME[0]} PACKAGE"
#         return 1
#     fi

#     find -L "/usr/share/doc/$1" -type f -name 'changelog*.gz' -exec zless {} \; 2>/dev/null
# }

# lman
# center
# line
# qt
# qh
# ppp
# video2gif
# _man
# gifify
# parse_git_branch
# nonzero_return
# lc
# uc
# wtfis
# whenis
# box
# htmlEntityToUTF8
# UTF8toHtmlEntity
# optiImages
# lman
# testConnection
# netstat_used_local_ports
# netstat_free_local_port
# sniff
# httpdump
# iptablesBlockIP
# ips
# command_exists
# stripspace
# logssh
# calc
# mkd
# mkf
# rand_int
# passwdgen
# targz
# duh
# fs
# ff
# fstr
# file_backup_compressed
# file_backup
# file_information
# dataurl
# create_server
# phpserver
# psgrep
# cpuinfo
# jsonc
# escape
# unidecode
# history_top_used
# getcertnames
# t
# httpDebug
# digga
# tre
# pidenv
# processenv
# shorturl

#source ~/.dot/eachdir

# -*- mode: sh -*-
# shellcheck disable=SC2039
#
# Miscellaneous shell-related functions.


# Print boolean value of the exit code of the command passed as argument.
bool() {
    "$@" && echo "true" || echo "false"
}

# Split directories in a PATH-like variable.
split_path_dirs() {
    local paths="$1"
    # shellcheck disable=SC2001
    echo "$paths" | sed 's/:/\n/g'
}

# Return whether a string is present in a list of strings.
contains_string() {
    local match="$1"
    local strings="$2"

    local s
    for s in $strings; do
        if [ "$s" == "$match" ]; then
            return 0
        fi
    done
    return 1
}

# Return whether the shell is interactive.
is_interactive() {
    [[ $- == *i* ]]
}

# Source a system file.  If no filename is given, list the available names.
sf() {
    local sourcedir="$SYSTEM_DIR/source"
    if [ $# -eq 0 ]; then
        ls -1 "$sourcedir"
        return
    fi

    local file
    for file in "$@"; do
        # shellcheck disable=SC1090
        . "$sourcedir/$file"
    done
}

#git help
function gitHelpNew()
{
  echo "git init"
  git init
  
  echo " git add *"
  git add *
  
  echo "git commit -m 'initial project version'"
  git commit -m 'initial project version'
    
  echo "create new repo on github without readme like https://github.com/corgan2222/webCamFullScreen.git"
  echo -n "Enter github repo url [ENTER]: "
  read url
  
  echo "git remote add origin $url"
  git remote add origin $url
  
  echo "git push -u origin master"
  git push -u origin master
  
}

dtags () {
    local image="${1}"

    wget -q https://registry.hub.docker.com/v1/repositories/"${image}"/tags -O - \
        | tr -d '[]" ' | tr '}' '\n' | awk -F: '{print $3}'
}

#file diff
# "  comparing dirs:  vdiff dir_a dir_b"
# "  comparing files: vdiff file_a file_b"
vdiff () 
{
    if [ "${#}" -ne 2 ] ; then
        echo "vdiff requires two arguments"
        echo "  comparing dirs:  vdiff dir_a dir_b"
        echo "  comparing files: vdiff file_a file_b"
        return 1
    fi

    local left="${1}"
    local right="${2}"

    if [ -d "${left}" ] && [ -d "${right}" ]; then
        vim +"DirDiff ${left} ${right}"
    else
        vim -d "${left}" "${right}"
    fi
}

#extract embedded jpg from raw with ufraw
raw2jpg_embedded(){

    if [ -z "${1}" ]; then
      echo "Usage: raw2jpg_embedded 'file' "
      return 1
    fi

    ufraw-batch --out-type=jpeg --embedded-image "$1"
}

# "Usage: raw2jpg_convert 'ARW|CR2' "
raw2jpg_convert(){

    if [ -z "${1}" ]; then
      echo "Usage: raw2jpg_convert 'ARW|CR2' "
      return 1
    fi

    for file in *."${1}"; do convert "$file" "${file%"${1}"}JPG"; done
}

#convert raw parallel
raw2jpg_parallel(){

    if [ -z "${1}" ]; then
      echo "Usage: raw2jpg_parallel 'ARW|CR2' "
      return 1
    fi

    parallel convert {} {.}."${1}" ::: *."$1"
}

# "Usage: raw2jpg_ext 'ARW|CR2' 'outout Folder' "
raw2jpg_ext()
{

  if [ -z "${1}" ]; then
    echo "Usage: raw2jpg_ext 'ARW|CR2' 'outout Folder' "
    return 1
  fi
  
    if [ ! -d ./"${2}" ]; then mkdir ./"${2}"; fi;

    # processes raw files
    for f in *."${1}";
    do
      echo "Processing $f"
      ufraw-batch \
        --wb=camera \
        --exposure=auto \
        --out-type=jpeg \
        --compression=96 \
        --out-path=./"${2}" \
        "$f"
    done

}

#Get upgradable apts
apt-getUpgradable ()
{
  { apt-get --just-print upgrade 2>&1 | perl -ne 'if (/Inst\s([\w,\-,\d,\.,~,:,\+]+)\s\[([\w,\-,\d,\.,~,:,\+]+)\]\s\(([\w,\-,\d,\.,~,:,\+]+)\)? /i) {print "$1 (\e[1;34m$2\e[0m -> \e[1;32m$3\e[0m)\n"}';} | while read -r line; do echo -en "$line\n"; done;
}

#checkt ob angegebene files auf server vorhanden sind
checkURLs ()
{
  BASE="http://www.example.com"
  FILES="index.html
  about.html"

  for ITEM in ${FILES}; do
    URL="${BASE}/${ITEM}"
    # --head may work in some environments
    curl -s -D - "${URL}" -o /dev/null | head -1 | grep 'HTTP/1.[01] 200' > /dev/null
    if [ $? == 1 ]; then
      echo "${ITEM} not found"
    fi
  done
}

#epackage_exists
function package_exists() {
    return dpkg -l "$1" &> /dev/null
}


#"Usage: imgResize '75' '91' "
#"Usage: imgResize [sizeReduct][quality] "
function imgResize() {

 if [ -z "${1}" ]; then
    echo "Usage: imgResize '75' '91' "
    echo "Usage: imgResize [sizeReduct][quality] "
    return 1
  fi

 if [ -z "${2}" ]; then
    echo "Usage: imgResize '75' '91' "
    echo "Usage: imgResize [sizeReduct][quality] "
    return 1
  fi

  imgp -x "${1}" -w -p --pr -q "${2}"
}

function getSSL() {
  ssl_certificate_file=$(grep ssl_certificate /var/www/vhosts/system/knaak.org/conf/nginx.conf)
  ssl_client_certificate_file=$(grep ssl_client_certificate /var/www/vhosts/system/knaak.org/conf/nginx.conf)

}

#block all ip from country on all ports
function iptable_block_bad_countrys() {

  if [ ! -d "/usr/share/xt_geoip/BE" ]; then 
    echo "/usr/share/xt_geoip/BE not found. Install GeoIP-database"
    return 1
  fi;

    iptables -m geoip --src-cc BR,IN,RU,KR,CH,BD --dst-cc BR,IN,RU,KR,CH,BD
    iptables -I INPUT -m geoip --src-cc BR,IN,RU,KR,CH,BD -j DROP

    iptables -m geoip --src-cc PL,TH,CN,FR,AD,LT,MX --dst-cc PL,NL,TH,CN,FR,AD,LT,MX
    iptables -I INPUT -m geoip --src-cc PL,TH,CN,FR,AD,LT,MX -j DROP

    iptables -m geoip --src-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY --dst-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY
    iptables -I INPUT -m geoip --src-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY -j DROP   

    /sbin/iptables -L INPUT -v | grep CH
}

#block all ip from country on all ports
function iptable_ban_country() {

  if [ ! -d "/usr/share/xt_geoip/BE" ]; then 
    echo "/usr/share/xt_geoip/BE not found. Install GeoIP-database"
    return 1
  fi;

 if [ -z "${1}" ]; then
    echo "Usage: iptable_ban_country CH "   
    return 1
  fi
    /sbin/iptables -m geoip --src-cc "${1}" --dst-cc "${1}"
    /sbin/iptables -I INPUT -m geoip --src-cc "${1}" -j DROP   
    /sbin/iptables -L INPUT -v | grep "${1}"
}

#unblock all ip from country on all ports
function iptable_unban_country() {

  if [ ! -d "/usr/share/xt_geoip/BE" ]; then 
    echo "/usr/share/xt_geoip/BE not found. Install GeoIP-database"
    return 1
  fi;

 if [ -z "${1}" ]; then
    echo "Usage: iptable_unban_country CH "   
    return 1
  fi    
    /sbin/iptables -D INPUT -m geoip --src-cc "${1}" -j DROP   
    /sbin/iptables -L INPUT -v | grep "${1}"
}

#block  ip on all ports
function iptable_ban_ip() {

 if [ -z "${1}" ]; then
    echo "Usage: iptable_ban_ip ip "   
    return 1
  fi
    
    /sbin/iptables -I INPUT -s "${1}" -j DROP
}

#unblock  ip on all ports
function iptable_unban_ip() {

 if [ -z "${1}" ]; then
    echo "Usage: iptable_unban_ip ip "   
    return 1
  fi
    
    /sbin/iptables -D INPUT -s "${1}" -j DROP
    iptable_check_ip "${1}"
}

#is ip blocked
function iptable_check_ip() {

 if [ -z "${1}" ]; then
    echo "Usage: iptable_check_ip IP  "   
    return 1
  fi
    
    /sbin/iptables -L | grep  ${1}

}

#is subnet blocked
function iptable_block_subnet() {

 if [ -z "${1}" ]; then
    echo "Usage: iptable_block_subnet 10.0.0.0/8 "   
    return 1
  fi
    
    /sbin/iptables -i eth1 -A INPUT -s "${1}" -j DROP

}

#see all blocked IPs
function iptable_view_blocked() {
 /sbin/iptables -L -v
}

#diff compare local file with repo file
function diff_git_file()
{
  if [ -z "${1}" ]; then
      echo "Usage: iptable_diff_git_file raspi/raspi_info.sh"   
      return 1
  fi  
  git fetch origin master
  git diff origin/master -- "$1"
}

function installer-help(){
echo " 


    #start
    bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
    sudo -i
    sudo ap joe

    #block countrys
      https://linoxide.com/linux-how-to/block-ips-countries-geoip-addons/
      
      sudo -i
      mkcdir /tmp
      apt-get update && apt-get upgrade
      apt-get install iptables-dev xtables-addons-common libtext-csv-xs-perl pkg-config
      wget http://downloads.sourceforge.net/project/xtables-addons/Xtables-addons/xtables-addons-3.7.tar.xz
      tar xf xtables-addons-3.7.tar.xz
      cd xtables-addons-3.7
      ./configure
      make
      make install

      cd geoip
      #get https://legacy-geoip-csv.ufficyo.com/
      wget -q https://legacy-geoip-csv.ufficyo.com/Legacy-MaxMind-GeoIP-database.tar.gz -O - | tar -xvzf - -C /usr/share/xt_geoip
      
      cd /usr/share/xt_geoip/BE
      cp * ../
      iptables -m geoip --src-cc BR,IN,RU,KR,CH,BD --dst-cc BR,IN,RU,KR,CH,BD
      iptables -I INPUT -m geoip --src-cc BR,IN,RU,KR,CH,BD -j DROP

      iptables -m geoip --src-cc PL,NL,TH,CN,FR,AD,LT,MX --dst-cc PL,NL,TH,CN,FR,AD,LT,MX
      iptables -I INPUT -m geoip --src-cc PL,NL,TH,CN,FR,AD,LT,MX -j DROP

      iptables -m geoip --src-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY --dst-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY
      iptables -I INPUT -m geoip --src-cc MX,HK,SG,IT,VN,RO,PH,TR,IR,MY-j DROP         

      iptables -m geoip --src-cc BD --dst-cc BD
      iptables -I INPUT -m geoip --src-cc NL -j ACCEPT


      #check mit 
      /sbin/iptables -L INPUT -v
      /sbin/iptables -L INPUT -v | grep CH
      #test with nordvpn

  


"    
}
