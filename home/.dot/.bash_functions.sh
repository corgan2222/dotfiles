#!/bin/bash

# docker_build_push: builds the Dockerfile in the current directory as <parent>/<dir>:<timestamp> and :latest, then
# pushes both tags to Docker Hub. Until 28.10.26 it was "db" and logged in and pushed without asking.
# "docker push image" without a tag pushes only :latest, so both tags are named.
function docker_build_push() {
  local image tag latest
  [ -f Dockerfile ] || { echo "docker_build_push: no Dockerfile in $PWD" >&2; return 1; }
  image=$(to_lower "$(basename "${PWD%/*}")/${PWD##*/}")
  tag=$image:$(date +%Y%m%d%H%M%S)
  latest=$image:latest
  sudo docker build -t "$tag" -t "$latest" . || return 1
  echo "built $tag and $latest"
  confirm "Log in to Docker Hub and push $tag and $latest" || return 1
  sudo docker login || return 1
  sudo docker push "$tag" && sudo docker push "$latest"
}


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

# createUserSSH: ~/.ssh with an ed25519 key pair whose public key is in authorized_keys, optionally a PuTTY .ppk.
# Safe to run again: an existing key stays, the public key goes into authorized_keys once. Before 28.10.26 the
# quoted "~/.ssh" never matched (the check was always true), and it expected id_rsa, which ssh-keygen no longer
# writes by default since OpenSSH 9.5.
function createUserSSH() {
  local d=$HOME/.ssh key pub
  key=$d/id_ed25519
  mkdir -p "$d" && chmod 700 "$d" || return 1
  [ -f "$d/authorized_keys" ] || { touch "$d/authorized_keys" && chmod 600 "$d/authorized_keys"; } || return 1
  if [ -f "$key" ]; then echo "$key exists, kept"; else ssh-keygen -t ed25519 -f "$key" || return 1; fi
  pub=$(<"$key.pub")
  grep -qxF -- "$pub" "$d/authorized_keys" || printf '%s\n' "$pub" >>"$d/authorized_keys"
  if [ ! -f "$key.ppk" ] && confirm "Create $key.ppk for PuTTY (installs puttygen if missing)"; then
    # puttygen: putty-tools on the Debian family, putty elsewhere
    command -v puttygen >/dev/null || pkg_install "$([ "$DOT_PKG" = apt ] && echo putty-tools || echo putty)" ||
      return 1
    puttygen "$key" -o "$key.ppk"
  fi
}

# adds a user with a home folder and a password; the system hashes it (chpasswd), the password goes in on stdin.
# Before 28.10.26 it hashed with DES and a fixed salt (only 8 characters counted) and matched names by prefix.
function user_add_with_pass_and_folder()
{
  local username password
  [ "$(id -u)" -eq 0 ] || { echo "Only root may add a user to the system"; return 2; }
  read -r -p "Enter username : " username
  [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "not a valid user name: '$username'"; return 1; }
  getent passwd "$username" >/dev/null && { echo "$username exists!"; return 1; }
  read -r -s -p "Enter password : " password; echo
  [ -n "$password" ] || { echo "empty password, nothing added"; return 1; }
  useradd -m -- "$username" || { echo "Failed to add a user!"; return 1; }
  printf '%s:%s\n' "$username" "$password" | chpasswd ||
    { echo "user added, but setting the password failed: passwd $username"; return 1; }
  echo "User $username has been added, home /home/$username"
}

# removes a user and its home folder after a question (default no)
# 28.10.26: "^$username" with an empty name matched every line of /etc/passwd, Enter meant yes and "rm -R /home/" ran
# even when userdel failed: Enter twice removed /home. Now the name must be valid and exist, userdel -r removes the
# home folder from the passwd entry and nothing else.
function user_remove()
{
  local username response
  if [ "$(id -u)" -ne 0 ]; then
    echo "Only root may delete a user"
    return 2
  fi
  read -r -p "Enter username : " username
  if ! [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || ! getent passwd "$username" >/dev/null; then
    echo "$username dont exists!"
    return 1
  fi
  # system accounts (postgres, influxdb …) have their data in their home: userdel -r would delete it (28.10.26)
  local uid home min
  uid=$(getent passwd "$username" | cut -d: -f3) home=$(getent passwd "$username" | cut -d: -f6)
  min=$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs 2>/dev/null); min=${min:-1000}
  [ "$uid" -ge "$min" ] || { echo "$username is a system account (uid $uid), not removed"; return 1; }
  read -r -p "Remove the user $username and its home folder $home? [y/N] " response
  [[ ${response,,} =~ ^(y|yes)$ ]] || return 1
  userdel -r -- "$username"
}

# replaceStringInFile 'string' 'replace' file: replaces every literal occurrence of string in the file
# Until 28.10.26 the file check was inverted and sed searched for the text "$1" (in single quotes nothing expands).
function replaceStringInFile() {
  [ $# -eq 3 ] && [ -n "$1" ] || { echo "Usage:  replaceStringInFile 'string' 'replace' file" >&2; return 1; }
  [ -f "$3" ] || { echo "file $3 not found" >&2; return 1; }
  local content LC_ALL=C
  # bash instead of sed: quoted "$1" and "$2" are literal text, sed would need every regex character escaped.
  # read -d '' keeps the trailing newlines that $(<file) would drop; >| writes past noclobber (bin/sensible.bash)
  IFS= read -r -d '' content <"$3"
  # read stops at the first NUL byte: a binary or UTF-16 file would lose the rest (28.10.26, review). LC_ALL=C makes
  # ${#content} count bytes
  [ ${#content} -eq "$(wc -c <"$3")" ] || { echo "$3 is a binary file, not changed" >&2; return 1; }
  printf '%s' "${content//"$1"/"$2"}" >|"$3"
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

#init homeShick; -f: an HTTP error page is not run as a script
function initHome() {
  bash <(curl -fsSL https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
}

# saveHome "message" [path…]: commits the changes to files the dotfiles repository tracks already (git add -u) and
# the paths given (relative to the repository, e.g. home/.dot/new.sh), and pushes the current branch only after a
# yes. New files come in with addToHome, homeshick track stages them. Until 28.10.26 it ran "git add *" (every
# untracked file) and pushed to master without asking, and master is the GitHub Pages site.
function saveHome() {
  [ $# -gt 0 ] || { echo "usage: saveHome 'commit message' [path in the repository…]" >&2; return 1; }
  local msg=$1 repo=$HOME/.homesick/repos/dotfiles
  shift
  [ -d "$repo/.git" ] || { echo "saveHome: no repository in $repo" >&2; return 1; }
  git -C "$repo" add -u || return 1
  [ $# -eq 0 ] || git -C "$repo" add -- "$@" || return 1
  git -C "$repo" status --short
  git -C "$repo" commit -m "$msg" || return 1
  confirm "Push $(git -C "$repo" rev-parse --abbrev-ref HEAD) to origin" && git -C "$repo" push origin HEAD
}


# updates the dotfiles: pull, link new files, remove links of deleted ones, setup questions of what is new
# (~/.dot/update.sh), then a new login shell with all of it
function dotupdate() {
  bash "$HOME/.dot/update.sh" "$@" && exec "$SHELL" -l
}
# the old name (alias l)
function loadHome() { dotupdate "$@"; }

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
    homeshick track dotfiles "$@"
  fi
}

#create folder and enter it
function mkcdir() {
  mkdir -p -- "$1" &&
    cd -P -- "$1"
}

#kill all processess with this name, see kill_all_of_process
function psKillAllX() {
  kill_all_of_process "$@"
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

# extract: unified archive extractor, unpacks into the current directory
# usage: extract <file> [file…]   (tar.gz/bz2/xz/zst/lz, zip, rar, 7z, gz, bz2, xz, zst, lzma, Z, deb, rpm, iso, cab/exe)
# Missing tools fall back to 7z or bsdtar; basics.sh installs unrar, 7zip, zip/unzip.
# unzip and unrar ask before they replace a file; until 28.10.26 -o and -o+ overwrote without a word.
# tar and bsdtar keep existing files (-k) and name each one as an error; 7z asks itself.
extract() {
  [ $# -gt 0 ] || { echo "usage: extract <file> [file…]" >&2; return 1; }
  local f f2 lower rc=0 sevenz
  sevenz=$(command -v 7z || command -v 7zz || command -v 7za)
  for f in "$@"; do
    if [ ! -f "$f" ]; then echo "extract: '$f' is not a file" >&2; rc=1; continue; fi
    lower=${f,,}
    case $lower in
      *.tar.gz|*.tgz|*.tar.bz2|*.tbz|*.tbz2|*.tar.xz|*.txz|*.tar.lz|*.tar|*.tar.lzma)
        tar -kxf "$f" ;;
      *.tar.zst|*.tzst)
        if command -v zstd >/dev/null; then tar --zstd -kxf "$f"
        elif command -v bsdtar >/dev/null; then bsdtar -kxf "$f"
        else echo "extract: install zstd (basics.sh)" >&2; false; fi ;;
      *.zip|*.jar|*.whl|*.apk)
        if command -v unzip >/dev/null; then unzip "$f"; else ${sevenz:-false} x "$f"; fi ;;
      *.rar)
        if command -v unrar >/dev/null; then unrar x "$f"
        elif [ -n "$sevenz" ]; then "$sevenz" x "$f"
        elif command -v bsdtar >/dev/null; then bsdtar -kxf "$f"
        else echo "extract: no rar tool, install unrar (basics.sh)" >&2; false; fi ;;
      *.7z|*.iso)
        if [ -n "$sevenz" ]; then "$sevenz" x "$f"
        elif command -v bsdtar >/dev/null; then bsdtar -kxf "$f"
        else echo "extract: install 7zip (basics.sh)" >&2; false; fi ;;
      # single compressed files: decompress into the current directory, never over an existing file
      *.gz|*.bz2|*.xz|*.zst|*.lzma|*.z)
        local out base=${f##*/} tool
        out=${base%.*}
        case $lower in
          *.gz) tool="gzip -dc" ;; *.bz2) tool="bzip2 -dc" ;; *.xz) tool="xz -dc" ;;
          *.zst) tool="zstd -dc" ;; *.lzma) tool="xz --format=lzma -dc" ;; *.z) tool="uncompress -c" ;;
        esac
        if [ -e "$out" ]; then echo "extract: '$out' exists, not overwritten" >&2; false
        else $tool "$f" > "$out" || { rm -f "$out"; false; }; fi ;;
      *.deb)  if command -v dpkg-deb >/dev/null; then f2=${f##*/}; dpkg-deb -x "$f" "${f2%.*}"; else ar x "$f"; fi ;;
      *.rpm)  if command -v bsdtar >/dev/null; then bsdtar -kxf "$f"; else rpm2cpio "$f" | cpio -idmv; fi ;;
      *.cab|*.exe|*.msi) cabextract "$f" ;;
      *) echo "extract: '$f' has an unknown archive type" >&2; false ;;
    esac || { echo "extract: '$f' failed" >&2; rc=1; }
  done
  return $rc
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

# _case lower|upper: converts STDIN; python3 handles umlauts in every locale, tr is the fallback without python3
function _case() {
  if command -v python3 >/dev/null; then
    python3 -c "import sys; sys.stdout.write(sys.stdin.read().$1())"
  elif [ "$1" = lower ]; then
    tr '[:upper:]' '[:lower:]'
  else
    tr '[:lower:]' '[:upper:]'
  fi
}

# lc: Convert the parameters or STDIN to lowercase.
function lc() {
  if [ $# -eq 0 ]; then _case lower; else printf '%s\n' "$@" | _case lower; fi
}

# uc: Convert the parameters or STDIN to uppercase.
function uc() {
  if [ $# -eq 0 ]; then _case upper; else printf '%s\n' "$@" | _case upper; fi
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
# (netstat or, where net-tools is missing, ss: both have the local address in column 4)
function netstat_used_local_ports() {
  { command -v netstat >/dev/null && netstat -atn || ss -atn; } |
    awk '{printf "%s\n", $4}' |
    grep -oE '[0-9]*$' |
    sort -n |
    uniq
}

# -------------------------------------------------------------------
# netstat_free_local_port: get one free tcp-port
function netstat_free_local_port() {
  local port used
  used=$(netstat_used_local_ports)
  for port in $(seq 32768 61000); do
    grep -qx "$port" <<<"$used" || { echo "$port"; return 0; }
  done
  return 1
}

# -------------------------------------------------------------------
# connection_overview: get stats-overview about your connections
netstat_connection_overview() {
  if command -v netstat >/dev/null; then netstat -nat | awk '{print $6}'; else ss -nat | awk 'NR > 1 {print $1}'; fi |
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
  ip -4 -o addr show | awk '{sub(/\/.*/, "", $4); print $4}'
}

# -------------------------------------------------------------------
# os-info: show some info about your system
function os-info() {
  lsb_release -a 2>/dev/null || cat /etc/os-release
  uname -a
  [ -r /etc/issue ] && cat /etc/issue
  [ -r /proc/version ] && cat /proc/version
  return 0
}

# -------------------------------------------------------------------
# command_exists: check if a command exists
function command_exists() {
  type "$1" &>/dev/null
}

# -------------------------------------------------------------------
# stripspace: strip unnecessary whitespace from file
function stripspace() {
  if [ $# -eq 0 ]; then
    echo "Usage: stripspace FILE"
    return 1
  else
    local tempfile
    tempfile=$(mktemp) || return 1
    git stripspace <"$1" >"$tempfile" && mv "$tempfile" "$1" || { rm -f "$tempfile"; return 1; }
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
# The old sed chain held a comment inside $(...), which made the next "-e" a command: decimals ended in
# "-e: command not found" (28.10.26).
function calc() {
  local result
  result=$(printf 'scale=10;%s\n' "$*" | bc -l | tr -d '\\\n')
  if [[ $result == *.* ]]; then
    # "0" before ".5" and "-.5", no trailing zeros
    result=$(printf '%s' "$result" | sed -e 's/^\./0./' -e 's/^-\./-0./' -e 's/0*$//;s/\.$//')
  fi
  printf '%s\n' "$result"
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
# The file name is taken after the cd, so relative paths work; quoted, so spaces stay (28.10.26)
function mkf() {
  [ $# -eq 1 ] || { echo "usage: mkf dir/file" >&2; return 1; }
  mkd "$(dirname -- "$1")" && touch -- "$(basename -- "$1")"
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
  local f rc=0
  for f; do
    if [[ -e "$f" ]]; then cp -a -- "$f" "${f}_$(date +%Y-%m-%d_%H-%M-%S)" || rc=1
    else echo "\"$f\" not found." >&2; rc=1; fi
  done
  return $rc
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
  python3 -c $'import http.server as s\nm = s.SimpleHTTPRequestHandler.extensions_map\nm[""] = "text/plain"\nfor k, v in list(m.items()):\n\tm[k] = v + ";charset=UTF-8"\ns.test(HandlerClass=s.SimpleHTTPRequestHandler, port=int(__import__("sys").argv[1]))' "$port"
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
  # pygmentize (python3-pygments) only colours, without it the formatted JSON comes plain
  local hl=cat fmt="python3 -m json.tool"
  command -v pygmentize >/dev/null && hl="pygmentize -l javascript"
  # Arch has no python3 in its base system; jq comes with basics.sh everywhere
  command -v python3 >/dev/null || fmt="jq ."
  if [ -t 0 ]; then # argument
    $fmt <<<"$*" | $hl
  else # pipe
    $fmt | $hl
  fi
}

function json2yaml(){
  
  if [ -z "${1}" ]; then
    echo "Usage: json2yaml file.json file.yaml "
    return 1
  fi

  cp -p "${1}" "${2}"

}

# kills the processes with exactly this name, after a look at the list: SIGTERM first, SIGKILL only on a second yes
# 28.10.26: "ps -ef | grep name | xargs kill -9" matched any part of the command line and also killed the own SSH
# session (sshd-session) and editors with the name in their arguments; pgrep -x compares the process name only
function kill_all_of_process(){
  local pids a
  if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: kill_all_of_process ffmpeg"
    return 1
  fi
  # the kernel keeps 15 characters of a process name: longer names are matched as the command's file name
  local -a sel=(-x -- "$1")
  [ ${#1} -le 15 ] || sel=(-f -- "^(\S*/)?$1( |$)")
  pids=$(pgrep "${sel[@]}") || { echo "no process named $1"; return 1; }
  pgrep -a "${sel[@]}" 2>/dev/null || echo "$pids" # busybox pgrep may lack -a
  read -r -p "Stop these processes (SIGTERM)? [y/N] " a
  [[ ${a,,} =~ ^(y|yes)$ ]] || return 1
  kill $pids
  sleep 2
  pids=$(pgrep "${sel[@]}") || return 0
  read -r -p "Still running: $(echo $pids). Kill them (SIGKILL)? [y/N] " a
  [[ ${a,,} =~ ^(y|yes)$ ]] || return 1
  kill -9 $pids
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

# scan multiple log subdirectories for the latest log files and tail them
function logsLatest(){
  ls /var/log/* -ld | tr -s " " | cut -d" " -f9 | xargs -i{} sh -c 'echo "\n---{}---\n"; tail -n50 {}/`ls -tr {} | tail -n1`'
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

  # Google's URL shortener closed in 2019; is.gd needs no account
  curl -fsS --get --data-urlencode "url=$1" "https://is.gd/create.php?format=simple" && echo
}

# -------------------------------------------------------------------
# o: open a file, folder or URL with the default program (no argument: this folder)
function o() {
  local cmd
  cmd=$(command -v xdg-open || command -v cygstart || command -v open) || {
    echo "o: no opener here (xdg-open from xdg-utils, cygstart on Cygwin)" >&2
    return 1
  }
  "$cmd" "${@:-.}"
}

# -------------------------------------------------------------------
# gz: compare the size of a file with its gzipped size
function gz() {
  [ -r "${1:-}" ] || { echo "Usage: gz <file>" >&2; return 1; }
  local orig gzip
  orig=$(wc -c <"$1") gzip=$(gzip -c "$1" | wc -c)
  awk -v o="$orig" -v g="$gzip" 'BEGIN { printf "orig: %d bytes\ngzip: %d bytes (%.2f%%)\n", o, g, o ? g * 100 / o : 0 }'
}

# -------------------------------------------------------------------
# codepoint: Unicode code point of a character: codepoint € -> U+20AC (needs a UTF-8 locale)
function codepoint() {
  [ -n "${1:-}" ] || { echo "Usage: codepoint <character>" >&2; return 1; }
  printf 'U+%04X\n' "'$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Process phone photo.
function ppp() {

  # Check if ImageMagick's convert command-line tool is installed.

  if ! command -v "convert" >/dev/null; then
    printf "Please install ImageMagick's 'convert' command-line tool!\n"
    return 1
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
# In the interactive shell it returns instead of exiting, which would close the session; a caller stops with: die "…" || return
function die() {
  local m="$1"   # message
  local e=${2-1} # default exit status 1
  echo "$m" >&2
  return $e
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
# Without a name or with PASSWD_FILE unset grep waited on stdin, and "ro" matched root (28.10.26)
function is_user_exits() {
  [ -n "$1" ] || return 1
  grep -q "^$1:" "${PASSWD_FILE:-/etc/passwd}"
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
function ct() {

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
  echo "systemctl daemon-reload"
  echo "service telegraf restart"
  echo "/var/log/telegraf/telegraf.log"

}

# yaml_r file [key.path]: one value of a YAML file through yq (basics.sh). Until 28.10.26 it put file name and key
# into Ruby code and installed the gem hash_dot
function yaml_r() {
  [ -f "$1" ] || { echo "usage: yaml_r file.yaml [key.path]" >&2; return 1; }
  command -v yq >/dev/null || { echo "yaml_r: yq is missing, install it with basics.sh" >&2; return 1; }
  yq ".${2:-}" "$1"
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
  cheat "$1"
  curl -s cli.help/suche | grep "$1"

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
  # completion line per command, from one "complete -p" (no subprocess per alias: each costs 10-30 ms on Windows)
  local -A compl=()
  local cl trig
  while IFS= read -r cl; do
    [[ $cl == *" -F "* ]] || continue
    trig=${cl##* }
    trig=${trig#\"}; trig=${trig%\"}
    compl[$trig]=$cl
  done < <(complete -p)
  ((${#compl[@]} == 0)) && return 0

  # parse alias definitions, where capture group 1 => trigger, 2 => command, 3 => command arguments
  local alias_regex="alias ([^=]+)='(\"[^\"]+\"|[^ ]+)(( +[^ ]+)*)'"
  # the wrappers and completions collect in a variable and run once at the end (no temporary file)
  local out= line noglob=
  # the evals expand a glob in an alias (*/) against the current folder: 496 ms in a /tmp with 7669 entries (28.10.26)
  [[ $- == *f* ]] || { set -f; noglob=1; }
  while read line; do
    # the evals below run command substitutions in the alias body: iw dev, date, ls at every login (28.10.26)
    [[ $line == *'$('* || $line == *'`'* || $line == *'<('* || $line == *'>('* ]] && continue
    eval "local alias_tokens=($line)" 2>/dev/null || continue # some alias arg patterns cause an eval parse error
    local alias_name="${alias_tokens[0]}" alias_cmd="${alias_tokens[1]}" alias_args="${alias_tokens[2]# }"

    # skip aliases to pipes, boolan control structures and other command lists
    # (leveraging that eval errs out if $alias_args contains unquoted shell metacharacters)
    eval "local alias_arg_words=($alias_args)" 2>/dev/null || continue

    # skip alias if there is no completion function triggered by the aliased command
    [ -n "${compl[$alias_cmd]:-}" ] || continue
    local new_completion=${compl[$alias_cmd]}

    # create a wrapper inserting the alias arguments if any
    if [[ -n $alias_args ]]; then
      local compl_func="${new_completion/#* -F /}"
      compl_func="${compl_func%% *}"
      # avoid recursive call loops by ignoring our own functions
      if [[ "${compl_func#_$namespace::}" == $compl_func ]]; then
        local compl_wrapper="_${namespace}::${alias_name}"
        out+="function $compl_wrapper {
           (( COMP_CWORD += ${#alias_arg_words[@]} ))
           COMP_WORDS=($alias_cmd $alias_args \${COMP_WORDS[@]:1})
           $compl_func
         }
"
        new_completion="${new_completion/ -F $compl_func / -F $compl_wrapper }"
      fi
    fi

    # replace completion trigger by alias
    out+="${new_completion% *} $alias_name
"
  done < <(alias -p | sed -rne "s/$alias_regex/\1 '\2' '\3'/p")
  [ -z "$noglob" ] || set +f
  eval "$out"
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

  # youtube-dl is unmaintained and breaks on YouTube; yt-dlp is its successor with the same options
  local ytdl
  ytdl=$(command -v yt-dlp || command -v youtube-dl) || {
    echo "needs yt-dlp: pkg_install yt-dlp (or: pipx install yt-dlp)" >&2
    return 1
  }
  "$ytdl" "$1" -x --audio-format mp3
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
    if [ -z "${bin_dl}" ]; then
      echo "need curl or wget for work please install one of them"
      return 98
    fi

    # download file
    if [[ "${1}" =~ http:// || "${1}" =~ https:// || "${1}" =~ ftp:// ]]; then
      # ${1} is an remote file will be downloaded to ${2}
      cd "${2}" && {
        ${bin_dl} "${1}"
        cd -
      }
    else
      # ${1} is not an remote file
      return 98
    fi
  else
    echo "check parameters for function #> get_remote_file"
    return 9
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
    return 9
  fi
}

#geo-ip 144.178.0.0
function geo-ip() {

  if [ -z "${1}" ]; then
    echo "Usage: h 'searchstring'"
    return 1
  else

    # HTTPS, and -f: an error page is not printed as the answer (28.10.26)
    curl -fsS "https://api.db-ip.com/v2/free/$1" && echo

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

  # ufraw left Debian 11, Ubuntu 20.04 and Fedora; dcraw plus ImageMagick do the same
  if command -v ufraw-batch >/dev/null; then
    for i in *.CR2; do ufraw-batch "$i" --out-type=jpeg --output "$i.jpg"; done
  elif command -v dcraw >/dev/null && command -v convert >/dev/null; then
    for i in *.CR2; do dcraw -c -w "$i" | convert - "$i.jpg"; done
  else
    echo "needs dcraw and ImageMagick: pkg_install dcraw imagemagick" >&2
    return 1
  fi  

}

  #Copy something from this system to some other system:
  #echo scp /path/to/local/file username@hostname:/path/to/remote/file  
function ssh_copy_to_host()
{
  scp "$3" "$1@$2:$4"
}

  #Copy something from some system to some other system:
  #scp username1@hostname1:/path/to/file username2@hostname2:/path/to/other/file 	
function ssh_copy_from_host_to_host(){
  scp "$1@$2:$3" "$4@$5:$6"
  
}
	
  #Copy something from another system to this system:
  #scp username@hostname:/path/to/remote/file /path/to/local/file  
function ssh_copy_fron_host(){
  scp "$1@$2:$3" "$4"
}
	
#dcraw -c RAW-Dateiname | convert - Ausgabedatei.FORMAT  
function convert_CR2_to_JPG_dcraw()
{
  dcraw -c "$1" | convert - "$2.$3"
}

# show the validity dates of the TLS certificate of a domain: checkSSLfromDomain example.com
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

    wget -q https://registry.hub.docker.com/v2/repositories/"${image}"/tags -O - \
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

    for file in *."${1}"; 
      do 
        convert "$file" "${file%"${1}"}JPG"; 
      done
}

#convert raw parallel
raw2jpg_parallel(){

    if [ -z "${1}" ]; then
      echo "Usage: raw2jpg_parallel 'ARW|CR2' "
      return 1
    fi

    parallel convert {} {.}."${1}" ::: "$1"
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
# "Usage: raw2jpg_embedded_batch ARW jpg/ "
raw2jpg_embedded_batch()
{

  if [ -z "${1}" ]; then
    echo "Usage: raw2jpg_embedded_batch 'ARW|CR2' 'outout Folder' "
    echo "Usage: Usage: raw2jpg_embedded_batch ARW jpg/ "
    return 1
  fi
  
    if [ ! -d ./"${2}" ]; then mkdir ./"${2}"; fi;

    # processes raw files
    for f in *."${1}";
    do
      echo "Processing $f"
      ufraw-batch \
        --embedded-image \
        --out-path=./"${2}" \
        "$f"
    done

}

#Get upgradable apts (apt only; pkg_upgradable works everywhere)
apt-getUpgradable ()
{
  [ "$DOT_PKG" = apt ] || { pkg_upgradable; return; }
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

# true when the login screen (MOTD) is switched off: DOT_MOTD=0 in the environment or in ~/.extra (setup.sh asks
# once). Read from the file because .bashrc loads ~/.extra after the MOTDs.
function _dot_motd_off() {
  [ "${DOT_MOTD:-}" = 0 ] && return 0
  [ -z "${DOT_MOTD:-}" ] && grep -qs '^export DOT_MOTD=0' "$HOME/.extra"
}

# --- packages on every system: DOT_PKG comes from lib/detect.sh (core.sh) ---

# installs packages with the package manager of this system: pkg_install lnav
function pkg_install() {
  case $DOT_PKG in
    apt)     sudo apt-get update -qq && sudo apt-get install -y "$@" ;;
    dnf|yum) sudo "$DOT_PKG" install -y "$@" ;;
    pacman)  sudo pacman -S --needed --noconfirm "$@" ;;
    zypper)  sudo zypper --non-interactive install "$@" ;;
    apk)     sudo apk add "$@" ;;
    opkg)    opkg install "$@" ;;
    *)       echo "no supported package manager here, install by hand: $*" >&2; return 1 ;;
  esac
}

# Installs a missing command on demand: bash calls this when a command is not found. Only commands that the aliases and
# functions here use and that lib/cmdpkg.sh maps to a package (ffmpeg, nmap, python3, ...); the question comes only on
# a terminal. Anything else goes to the handler the distribution brought (command-not-found on Ubuntu, PackageKit on
# Fedora), else to bash's usual message. Off: DOT_INSTALL_ON_DEMAND=0
# The "()" matters: without it eval ran the body of Ubuntu's handler at every login, and its "return" stopped loading
# this file (28.10.26: "_dot_cnf_prev{: command not found", 41 functions missing)
declare -F command_not_found_handle >/dev/null && ! declare -F _dot_cnf_prev >/dev/null &&
  eval "_dot_cnf_prev () $(declare -f command_not_found_handle | tail -n +2)"
function command_not_found_handle() {
  local pkg
  if [ "${DOT_INSTALL_ON_DEMAND:-1}" != 0 ] && [ -t 0 ] && [ -t 1 ] && [ -r "$HOME/.dot/lib/cmdpkg.sh" ]; then
    . "$HOME/.dot/lib/cmdpkg.sh"
    pkg=$(_dot_cmdpkg "$1")
    if [ -n "$pkg" ]; then
      # default No: until 28.10.26 Enter (or a stray key) installed the package
      if confirm "$1 is not installed. Install the package $pkg now"; then
        pkg_install "$pkg" && hash -r && command -v "$1" >/dev/null && { "$@"; return; }
      fi
    fi
  fi
  if declare -F _dot_cnf_prev >/dev/null; then _dot_cnf_prev "$@"; return; fi
  printf 'bash: %s: command not found\n' "$1" >&2
  return 127
}

# true when the package is installed: package_exists curl
function package_exists() {
  case $DOT_PKG in
    apt)            dpkg-query -W -f '${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
    dnf|yum|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman)         pacman -Q "$1" >/dev/null 2>&1 ;;
    apk)            apk info -e "$1" >/dev/null 2>&1 ;;
    opkg)           opkg list-installed "$1" 2>/dev/null | grep -q . ;;
    *)              return 1 ;;
  esac
}

# lists the packages with a newer version, without changing anything
function pkg_upgradable() {
  case $DOT_PKG in
    apt)     apt list --upgradable 2>/dev/null | tail -n +2 ;;
    dnf|yum) "$DOT_PKG" -q check-update; [ $? -le 100 ] ;;
    pacman)  if command -v checkupdates >/dev/null; then checkupdates; else pacman -Qu; fi ;;
    zypper)  zypper -q list-updates ;;
    apk)     apk -u list 2>/dev/null ;;
    opkg)    opkg list-upgradable ;;
  esac
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

#block all ip from country on all ports
function iptable_block_bad_countrys() 
{

  #https://imanudin.net/2020/06/28/how-to-block-access-based-on-geoip-on-ubuntu/
  
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
    echo "Usage: iptable_block_subnet 198.51.100.0/24 [interface]"
    return 1
  fi
  # interface optional: until 28.10.26 it was eth1, a name current systems rarely have (enp*, ens*)
  local iface=()
  [ -n "$2" ] && iface=(-i "$2")
  /sbin/iptables -A INPUT "${iface[@]}" -s "${1}" -j DROP

}

#see all blocked IPs
function iptable_view_blocked() {
 /sbin/iptables -L -v
}

#see all blocked IPs
function iptable_view_blocked_geo() {
 /sbin/iptables -L -v | grep geo
}

#diff compare local file with repo file
function iptable_remove_lines()
{
  iptables -L INPUT --line-numbers | grep geo
  box "type iptables -D INPUT Linenumber"

} 

#diff compare local file with repo file
function diff_git_file()
{
  if [ -z "${1}" ]; then
      echo "Usage: diff_git_file raspi/raspi_info.sh"   
      return 1
  fi  
  git fetch origin master
  git diff origin/master -- "$1"
}


#add user to group
function user_add_to_group()
{
  if [ -z "${1}" ]; then
      echo "Usage: user_add_to_group user group"   
      return 1
  fi
  
  if [ -z "${2}" ]; then
      echo "Usage: user_add_to_group user group"   
      return 1
  fi
  
  sudo usermod -aG $2 $1

}

#list user groups
function user_list_groups()
{
  if [ -z "${1}" ]; then
      echo "Usage: user_list_groups user"   
      return 1
  fi
 
  sudo groups $1 
}

#List users and their groups:
function user_in_groups_list(){
  for user in $(awk -F: '{print $1}' /etc/passwd); 
    do groups $user; 
  done

}

#List groups and their users:
function groups_with_users_list(){

  cat /etc/group | awk -F: '{print $1, $3, $4}' | while read group gid members; 
  do
      members=$members,$(awk -F: "\$4 == $gid {print \",\" \$1}" /etc/passwd);
      echo "$group: $members" | sed 's/,,*/ /g';
  done

}

#list only manually added users
function groups_with_manual_users_list(){

  for user in $(getent passwd {1000..60000} |awk -F: '{print $1}');
  do 
      groups $user; 
  done

}

function zabbix_create_psk(){
  openssl rand -hex 48 -out /etc/zabbix/key.psk
  chown zabbix:zabbix /etc/zabbix/key.psk
  chmod 0400 /etc/zabbix/key.psk  

  cat /etc/zabbix/key.psk  

  if [ -e "/etc/zabbix/zabbix_agentd.conf" ]; then 
    cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.save

    echo -e "\nTLSConnect=psk\n" >> /etc/zabbix/zabbix_agentd.conf
    echo -e "TLSAccept=psk\n" >> /etc/zabbix/zabbix_agentd.conf
    echo -e "TLSPSKIdentity=Key1\n" >> /etc/zabbix/zabbix_agentd.conf
    echo -e "TLSPSKFile=/etc/zabbix/key.psk\n" >> /etc/zabbix/zabbix_agentd.conf
    
  fi;


}

# shows what takes space in caches, logs and old kernels, with the command that frees it on this system
function freeLinuxSpace() {
  local cache
  du -sh /var/tmp/ 2>/dev/null
  case $DOT_PKG in
    apt)     cache=/var/cache/apt;       echo " clean: sudo apt-get autoclean / sudo apt-get clean" ;;
    dnf|yum) cache=/var/cache/$DOT_PKG;  echo " clean: sudo $DOT_PKG clean all" ;;
    pacman)  cache=/var/cache/pacman/pkg; echo " clean: sudo pacman -Sc (paccache -r keeps three versions)" ;;
    zypper)  cache=/var/cache/zypp;      echo " clean: sudo zypper clean --all" ;;
    apk)     cache=/var/cache/apk;       echo " clean: sudo apk cache clean" ;;
  esac
  [ -n "$cache" ] && du -sh "$cache" 2>/dev/null
  if command -v journalctl >/dev/null; then
    journalctl --disk-usage
    echo " clean: sudo journalctl --vacuum-time=3d"
  fi
  [ -d /var/lib/snapd/snaps ] && du -sh /var/lib/snapd/snaps && echo " old snap revisions: snap list --all | grep disabled"
  du -sh ~/.cache/ 2>/dev/null
  echo " clean: find ~/.cache/ -type f -atime +365 -delete"

  echo "kernel: $(uname -r)"
  case $DOT_PKG in
    apt)     dpkg --list 'linux-image-*' | awk '/^ii/ {print "  " $2}'
             echo " remove old ones: sudo apt autoremove --purge" ;;
    dnf|yum) rpm -q kernel kernel-core 2>/dev/null | sed 's/^/  /'
             echo " old kernels go by installonly_limit in /etc/dnf/dnf.conf: sudo dnf remove --oldinstallonly" ;;
  esac
}


function help_journal()
{

echo "
Since yesterday:

$ journalctl --since=yesterday

Give a specific time period:

$ journalctl --since=2012-10-15 --until='2011-10-16 23:59:59'

Pick a specific service & time period:

$ journalctl -u httpd --since=00:00 --until=9:30

Point journalctl at specific devices, services, binaries
Look at a specific device:

$ journalctl /dev/sdc

Check on a binary:

$ journalctl /usr/sbin/vpnc

Check on the interlieved output from two specifics:

$ journalctl /usr/sbin/vpnc /usr/sbin/dhclient

Show all systemd units that have been started in your journal:

$ journalctl -F _SYSTEMD_UNIT
"

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


function help_mysql(){

echo "

  #server2server copy
    sudo apt-get install mysql-utilities
     mysqldbcopy --source=user:pw@server.com --destination=user:pw@server.com db_name_source:db_name_new (new db is created automaticly)


  #mysqldump  server2server
    mysqldump -h host.com -u user --password=pw SOURCE_dbname | mysql -h dest_host.com -u root --password=pw  DB_new_name #db must created first
    mysqldump -u <user name> --password=<pwd> <original db> | mysql -u <user name> -p <new db>

  #import from file using login-path
    mysql_config_editor set --login-path=choose_path --host=host --user=user --password
    mysql -login-path=path DB_NAme < DB_name_dump_.sql

  #dump local
  mysqldump -u root -p classicmodels > d:\db\classicmodels.sql

  #import local
  mysql -u root -p classicmodels_backup < d:\db\classicmodels.sql

"

}


#parallel portscan
function portscan_parallel (){
  time seq 65535 | parallel -k --joblog portscan -j9 --pipe --cat -j200% -n9000 --tagstring '\033[30;3{=$_=++$::color%8=}m' 'nc -vz localhost $(head -n1 {})-$(tail -n1 {})'
}

function portsD() {
    if ! command -v netstat &> /dev/null; then
        echo "Error: netstat is not installed. Please install it using your package manager."
        return 1  # Exit the function with an error code
    fi    

    # Define a list of ports to ignore
    IGNORE_PORTS=(53)

    echo "Processing netstat output and appending program paths and working directories..."

    # Print header with fixed column widths
    printf "%-22s %-25s %-45s %-s\n" "Local Address" "PID/Program Name" "Program Path" "Working Directory"

    # Run netstat command and process the output
    sudo netstat -lnpt4e | while read -r line; do
        # Skip the header line
        if [[ "$line" == *"Proto Recv-Q Send-Q"* ]]; then
            continue
        fi

        # Only process lines where state is LISTEN
        if [[ "$line" == *LISTEN* ]]; then
            # Extract the port number from Local Address
            local_addr=$(echo "$line" | awk '{print $4}')
            port=$(echo "$local_addr" | awk -F: '{print $NF}')

            # Check if the port is in the ignore list
            if [[ " ${IGNORE_PORTS[@]} " =~ " $port " ]]; then
                continue
            fi

            # Extract PID/Program Name
            pid_prog=$(echo "$line" | awk '{print $9}')

            # Extract PID from PID/Program Name
            pid=$(echo "$pid_prog" | cut -d'/' -f1)
            program_path="Unknown"
            working_dir="Unknown"

            # Retrieve the full path of the program using the PID
            if [[ "$pid" =~ ^[0-9]+$ ]]; then
                program_path=$(sudo readlink -f /proc/$pid/exe 2>/dev/null || echo "Unknown")
                working_dir=$(sudo readlink -f /proc/$pid/cwd 2>/dev/null || echo "Unknown")
            fi

            # Print formatted output with fixed column widths
            printf "%-22s %-25s %-45s %-s\n" "$local_addr" "$pid_prog" "$program_path" "$working_dir"
        fi
    done
}


#mural
function corganwashere(){
  tput setaf 1;tput rev;h=$(tput lines);w=$[$(tput cols)/6];c=$(seq -ws '_____|' $[$w+1]|tr -d "0-9");for a in $(seq $[$h/2]);do echo $c;echo ${c//|___/___|};done;tput cup 0;toilet -t -f bigmono12 "?Corganwashere";tput cup $h
}


#List all accessed configuration files while executing a program in linux terminal (improved version)
function get_all_configs_of_programm()
{

  if [ -z "${1}" ]; then
      echo "Usage: get_all_configs_of_programm docker"   
      return 1
  fi

  strace 2>&1 "${1}" |egrep -o "\".*\.conf\""

}

#Generates a TV noise alike output in the terminal
function tvNoise(){

while true;do printf "$(awk -v c="$(tput cols)" -v s="$RANDOM" 'BEGIN{srand(s);while(--c>=0){printf("\xe2\x96\\%s",sprintf("%o",150+int(10*rand())));}}')";done

}


function prq()
{

  if [ ! -d "${1}" ]; then
      echo "Usage: prq python_project_folder_path "   
      return 1
  fi

  # installs pipreqs only after a yes (until 28.10.26 without asking); _pip refuses outside a venv where PEP 668 rules
  if ! command -v pipreqs > /dev/null; then
    confirm "pipreqs is not installed. Install it with pip" || return 1
    _pip install pipreqs || return 1
  fi
  pipreqs "${1}"
  
}

function h_bash(){
echo '
if [[ -z "$string" ]]; then
  echo "String is empty"
elif [[ -n "$string" ]]; then
  echo "String is not empty"
fi

[[ -z STRING ]] 	Empty string
[[ -n STRING ]] 	Not empty string
[[ STRING == STRING ]] 	Equal
[[ STRING != STRING ]] 	Not Equal
[[ NUM -eq NUM ]] 	Equal
[[ NUM -ne NUM ]] 	Not equal
[[ NUM -lt NUM ]] 	Less than
[[ NUM -le NUM ]] 	Less than or equal
[[ NUM -gt NUM ]] 	Greater than
[[ NUM -ge NUM ]] 	Greater than or equal
[[ STRING =~ STRING ]] 	Regexp
(( NUM < NUM )) 	Numeric conditions
More conditions
[[ -o noclobber ]] 	If OPTIONNAME is enabled
[[ ! EXPR ]] 	Not
[[ X && Y ]] 	And
[[ X || Y ]] 	Or

File conditions
[[ -e FILE ]] 	Exists
[[ -r FILE ]] 	Readable
[[ -h FILE ]] 	Symlink
[[ -d FILE ]] 	Directory
[[ -w FILE ]] 	Writable
[[ -s FILE ]] 	Size is > 0 bytes
[[ -f FILE ]] 	File
[[ -x FILE ]] 	Executable
[[ FILE1 -nt FILE2 ]] 	1 is more recent than 2
[[ FILE1 -ot FILE2 ]] 	2 is more recent than 1
[[ FILE1 -ef FILE2 ]] 	Same files

Basic for loop
for i in /etc/rc.*; do
  echo $i
done

cat file.txt | while read line; do
  echo $line
done

for i in {1..5}; do
    echo "Welcome $i"
done

$((a + 200))      # Add 200 to $a

case "$1" in
  start | up)
    vagrant up
    ;;

  *)
    echo "Usage: $0 {start|stop|ssh}"
    ;;
esac



printf "Hello %s, Im %s" Sven Olga
#=> "Hello Sven, Im Olga

printf "1 + 1 = %d" 2
#=> "1 + 1 = 2"

printf "This is how you print a float: %f" 2
#=> "This is how you print a float: 2.000000"

Directory of script
DIR="${0%/*}"

Special variables
$? 	Exit status of last task
$! 	PID of last background task
$$ 	PID of shell
$0 	Filename of the shell script
$_ 	Last argrument of the previous command



if ping -c 1 google.com; then
  echo "It appears you have a working internet connection"
fi



https://devhints.io/bash

'

}

# find all active IP addresses in a network
scanNetwork_nmap(){
  
  if ! [ -x "$(command -v nmap)" ]; then
    echo 'Error: nmap is not installed.' >&2
    return 1
  fi


  if [ -z "${1}" ]; then
    echo "Usage: scanNetwork 192.0.2 "   
    return 1
  fi

  nmap -sP "${1}.0/24"; arp-scan --localnet | grep "${1}.[0-9]* *ether"

  if ! [ -x "$(command -v arp-scan)" ]; then
    echo 'Error: arp-scan is not installed.' >&2
  fi
}

# Quickly ping range of IP adresses and return only those that are online
scanNetwork_ping(){

  if [ -z "${1}" ]; then
    echo "Usage: scanNetwork_ping 192.0.2 "   
    return 1
  fi

  network="${1}"

  { for i in {1..254}; do ping -c 1 -W 1 ${network}.$i & done } | grep "64 bytes"

}

# Function to get the local IP and run nmap
nmap_scanNetworkPing() {
    # Get the local IP address
    local IP=$(getmyIP)
    
    # Extract the network part of the IP address
    local NETWORK=$(echo $IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
    
    # Run nmap with the constructed network range
    sudo nmap -PE -sn -oG - $NETWORK
    
}

# Function to get the local IP and run nmap
nmap_scanNetworkAdvance() {
    # Get the local IP address
    local IP=$(getmyIP)
    
    # Extract the network part of the IP address
    local NETWORK=$(echo $IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
    
    # Run nmap with the constructed network range
    sudo nmap -sn -oG - $NETWORK  
}

# Function to get the local IP and run nmap
nmap_listScan() {
    # Get the local IP address
    local IP=$(getmyIP)
    
    # Extract the network part of the IP address
    local NETWORK=$(echo $IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
    
    # Run nmap with the constructed network range
    sudo nmap -sL $NETWORK     
}


function nmap_bacnet_scanNetwork {
# get the IP address
    # Get the local IP address
    local IP=$(getmyIP)
    
    # Extract the network part of the IP address
    local NETWORK=$(echo $IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')

echo "Start nmap scan: sudo nmap --script bacnet-info -sU -p 47808 $NETWORK"
echo ""
sudo nmap --script bacnet-info -sU -p 47808 $NETWORK 
echo ""
}

# Function: lanv
# Ensures 'lnav' is installed and uses it to view system logs. If '/var/log/syslog' is absent, logs are streamed from 'journalctl'. 
# It checks for 'lnav' presence, installs it if missing, and chooses the appropriate log source based on system configuration.
# Usage: Call 'lanv' without arguments to view logs. Requires sudo privileges for installation and log access.
function lnav() {
    # Find the full path of lnav (type -P: the program, not this function; which is missing on minimal systems)
    local lnav_path f
    lnav_path=$(type -P lnav)
    
    # If lnav is not installed, install it after a yes (until 28.10.26 without asking).
    if [ -z "$lnav_path" ]; then
        confirm "lnav is not installed. Install it" || return 1
        pkg_install lnav || return 1
        lnav_path=$(type -P lnav)  # Re-check for lnav path after installation
    fi

    # With arguments, or when /var/log/syslog exists, run lnav as usual. Without both, feed today's journal into
    # lnav; systems without journald log to /var/log/messages (Alpine, Synology) or /tmp/syslog.log (Asuswrt).
    if [ -n "$1" ] || [ -f "/var/log/syslog" ]; then
        "$lnav_path" "$@"
    elif command -v journalctl >/dev/null; then
        journalctl --since today -f -n 100 --no-pager | "$lnav_path"
    else
        for f in /var/log/messages /tmp/syslog.log /var/log; do
            [ -e "$f" ] && { "$lnav_path" "$f"; return; }
        done
    fi
}

# Prints one line "<name> <number of files>" per service under /var/log, sorted; used by logs and its tab completion
function _logs_names() {
    local dir=/var/log f n ext
    for f in "$dir"/*; do
        n=${f##*/}
        # strip rotation and compression suffixes:
        # auth.log.2.gz -> auth, syslog-20261026 -> syslog, telegraf.2026-10-16-1792167900.log -> telegraf
        while :; do
            ext=${n##*.}
            case $n in
                *.gz|*.xz|*.bz2|*.zst|*.old|*.log|*.err|*.out) n=${n%.*} ;;
                *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) n=${n%-*} ;;
                # last part only digits, '-' or '_', so php7.4-fpm stays
                *.*) [ -z "${ext//[0-9_-]/}" ] && n=${n%.*} || break ;;
                *) break ;;
            esac
        done
        # binary files lnav cannot read
        case $n in journal|wtmp|btmp|lastlog|faillog|'*') continue ;; esac
        # a directory counts with the files in it
        if [ -d "$f" ]; then
            echo "$n $(ls -A "$f" 2>/dev/null | wc -l)"
        else
            echo "$n 1"
        fi
    done | awk '{ c[$1] += $2 } END { for (n in c) if (c[n]) print n, c[n] }' | sort
}

# Tab completion for logs: logs <TAB> offers the names that logs lists
function _logs_complete() {
    COMPREPLY=()
    [ "$COMP_CWORD" -eq 1 ] || return 0
    COMPREPLY=($(compgen -W "$(_logs_names | cut -d' ' -f1)" -- "${COMP_WORDS[1]}"))
}
complete -F _logs_complete logs

# Function: logs
# Lists and opens logs under /var/log. Uses only bash and busybox tools, so it also works on embedded systems.
# Usage: logs           one entry per service with its number of files, in two columns
#        logs <name>    all files of <name> incl. rotated and compressed ones in lnav,
#                       without lnav 'tail -f' on the plain files, without files the systemd journal of <name>
#        logs <TAB>     completes the names
function logs() {
    local dir=/var/log f
    local files=() plain=()

    if [ -z "$1" ]; then
        _logs_names |
            # two columns, sorted top to bottom; one column on terminals below 76 chars
            awk -v w="${COLUMNS:-80}" '{ n[NR] = $1; c[NR] = $2 } END {
                cols = (w >= 76) ? 2 : 1; rows = int((NR + cols - 1) / cols)
                for (r = 1; r <= rows; r++) {
                    line = ""
                    for (k = 0; k < cols; k++) {
                        i = r + k * rows
                        if (i <= NR) line = line sprintf("%-31s %4d   ", n[i], c[i])
                    }
                    sub(/ +$/, "", line); print line
                }
            }'
        return
    fi

    for f in "$dir/$1" "$dir/$1".* "$dir/$1"-[0-9]*; do
        # empty directories (chronograf logs to the journal) do not count
        [ -d "$f" ] && [ -z "$(ls -A "$f" 2>/dev/null)" ] && continue
        [ -e "$f" ] && files+=("$f")
    done

    if [ ${#files[@]} -eq 0 ]; then
        if type -P journalctl >/dev/null && journalctl -u "$1" -n 1 -q --no-pager 2>/dev/null | grep -q .; then
            if type -P lnav >/dev/null; then
                journalctl -u "$1" --since today --no-pager | command lnav
            else
                journalctl -u "$1" -n 100 -f
            fi
        else
            echo "logs: nothing found for '$1' in $dir" >&2
            return 1
        fi
    elif type -P lnav >/dev/null; then
        command lnav "${files[@]}"
    else
        for f in "${files[@]}"; do
            [ -d "$f" ] && set -- "$f"/* || set -- "$f"
            for f in "$@"; do
                case $f in *.gz|*.xz|*.bz2|*.zst) ;; *) [ -f "$f" ] && plain+=("$f") ;; esac
            done
        done
        [ ${#plain[@]} -eq 0 ] && { echo "logs: only compressed files for '$1', install lnav" >&2; return 1; }
        tail -n 100 -f "${plain[@]}"
    fi
}


# -t Tabelle	Diese Filterregel gilt für die Tabelle "Tabelle".
# -I Chain [Position]	Regel wird an Position "Position" der Kette "Chain" eingefügt. Bei Nichtangabe der Position wird die Regel am Anfang der Kette eingefügt.
# -A Chain	Regel wird an die Kette "Chain" angehängt.
# -D Chain	Regel wird aus der Kette "Chain" gelöscht.
# -F Chain	Alle Regeln der Kette "Chain" löschen.
# -L Chain	Liste alle Regeln der Kette "Chain" auf.
# -p Protokoll	Das Paket wird nur geprüft, wenn es gemäß "IP-Protokoll" ist (z.B. TCP, UDP, ICMP).
# -s IP-Adresse	Das Paket wird nur geprüft, wenn es von der definierten IP-Adresse stammt.
# -d IP-Adresse	Das Paket wird nur geprüft, wenn es an die definierte IP-Adresse gesendet wird.
# -i Netzwerkschnittstelle	Das Paket wird nur geprüft, wenn es über die definierte Netzwerkschnittstelle eingegangen ist.
# -o Netzwerkschnittstelle	Das Paket wird nur geprüft, wenn es über die definierte Netzwerkschnittstelle versendet wird.
# --sport Port-Nr oder --source-port Port-Nr	Das Paket wird nur geprüft, wenn es von der definierten Port-Nummer stammt. Muss zwingend in Verbindung mit -p benutzt werden!
# --dport Port-Nr oder -destination-port Port-Nr	Das Paket wird nur geprüft, wenn es an die definierte Port-Nummer gesendet wird. Muss zwingend in Verbindung mit -p benutzt werden!
# -j Aktion	Legt fest, welche Aktion auf das Paket angewendet werden soll, wenn alle Prüfkriterien erfüllt wurden. Weitere Details siehe hier.
# -P Chain Aktion	Legt eine Policy für eine Chain fest, falls keine Filterregel zutrifft. Weitere Details siehe hier.

# Trifft ein Filterregel auf ein Paket zu, muss noch festgelegt werden, wie mit dem Paket verfahren werden soll (Option -j Aktion, siehe oben). Bei "normaler" Filterung sind die häufigsten Aktionen:
# verschiedene Aktionen, die auf ein Paket angewendet werden
# Aktion	Beschreibung
# ACCEPT	Das Paket wird akzeptiert und angenommen.
# DROP	Das Paket wird nicht angenommen, der Sender erhält keine Nachricht.
# REJECT	Das Paket wird nicht angenommen, der Sender wird benachrichtigt.
# LOG	Die Paketdaten werden im System-Log festgehalten, anschließend wird die nächste Regel der Chain geprüft und ggf. angewendet.

# Note that [[ is actually a command/program that returns either 0 (true) or 1 (false). Any program that obeys the same logic (like all base utils, such as grep(1) or ping(1)) can be used as condition, see examples.
# [[ -z STRING ]] 	Empty string
# [[ -n STRING ]] 	Not empty string
# [[ STRING == STRING ]] 	Equal
# [[ STRING != STRING ]] 	Not Equal
# [[ NUM -eq NUM ]] 	Equal
# [[ NUM -ne NUM ]] 	Not equal
# [[ NUM -lt NUM ]] 	Less than
# [[ NUM -le NUM ]] 	Less than or equal
# [[ NUM -gt NUM ]] 	Greater than
# [[ NUM -ge NUM ]] 	Greater than or equal
# [[ STRING =~ STRING ]] 	Regexp
# (( NUM < NUM )) 	Numeric conditions
# [[ -o noclobber ]] 	If OPTIONNAME is enabled
# [[ ! EXPR ]] 	Not
# [[ X ]] && [[ Y ]] 	And
# [[ X ]] || [[ Y ]] 	Or

# File conditions
# [[ -e FILE ]] 	Exists
# [[ -r FILE ]] 	Readable
# [[ -h FILE ]] 	Symlink
# [[ -d FILE ]] 	Directory
# [[ -w FILE ]] 	Writable
# [[ -s FILE ]] 	Size is > 0 bytes
# [[ -f FILE ]] 	File
# [[ -x FILE ]] 	Executable
# [[ FILE1 -nt FILE2 ]] 	1 is more recent than 2
# [[ FILE1 -ot FILE2 ]] 	2 is more recent than 1
# [[ FILE1 -ef FILE2 ]] 	Same files