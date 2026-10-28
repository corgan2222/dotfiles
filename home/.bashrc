#!/bin/bash -x

# bash only: sh, dash and BusyBox ash stop at the syntax below (~/.profile loads this file only under bash)
[ -n "${BASH_VERSION:-}" ] || return
# interactive shells only. Not PS1: Git Bash's /etc/profile sets it in every login shell, so the deploy's last
# "bash -l" without a terminal loaded everything (sensible.bash: "bind: line editing not enabled", 28.10.26)
case $- in *i*) ;; *) return ;; esac
# ~/.bashrc: executed by bash(1) for non-login shells.
# not exported: ~/.profile skips a second load in this shell, a new shell loads again
_dot_bashrc_loaded=1

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"

# reload the shell (i.e. invoke as a login shell)
alias reload='exec "$SHELL" -l'
alias load='source "$HOME"/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh'

# prints colored text
print_style () {

    if [ "$2" == "info" ] ; then
        COLOR="96m";
    elif [ "$2" == "success" ] ; then
        COLOR="92m";
    elif [ "$2" == "warning" ] ; then
        COLOR="93m";
    elif [ "$2" == "danger" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR" "$1";
}

# sources a file when it is readable; DOT_TIMING=1 bash -l prints how long each file takes (bash 5: EPOCHREALTIME)
_loadFile()
{
  [ -r "$1" ] || return 0
  if [ -n "${DOT_TIMING:-}" ] && [ -n "${EPOCHREALTIME:-}" ]; then
    local t0=${EPOCHREALTIME/[.,]/}
    source "$1"
    printf '%6d ms  %s\n' $(( (${EPOCHREALTIME/[.,]/} - t0) / 1000 )) "$1" >&2
  else
    source "$1"
  fi
}

# MOTD scripts: sourced like the rest, but without alias expansion: an alias such as df="df -kTh" in .bash_aliases
# would change what they read (the columns of df)
_loadMotd()
{
  # the user switches the MOTD off in setup.sh (DOT_MOTD=0)
  _dot_motd_off && return 0
  local had=0
  shopt -q expand_aliases && had=1
  shopt -u expand_aliases
  _loadFile "$@"
  [ $had = 1 ] && shopt -s expand_aliases
  return 0
}

# runs a command, with DOT_TIMING=1 also prints its time: _dot_time <label> <command…>
_dot_time()
{
  local label=$1 t0; shift
  [ -n "${DOT_TIMING:-}" ] && [ -n "${EPOCHREALTIME:-}" ] || { "$@"; return; }
  t0=${EPOCHREALTIME/[.,]/}
  "$@"
  printf '%6d ms  %s\n' $(( (${EPOCHREALTIME/[.,]/} - t0) / 1000 )) "$label" >&2
}

#load core system
_loadFile "$HOME"/.dot/core.sh "Core System"

resetHome()
{
  rm -r "$HOME"/.dot/ -f
  rm -r "$HOME"/.homesick/ -f
  rm .profile 
  rm .bashrc
  #bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
  #source .bashrc
  #gitSaveCredential
}

# Cygwin, Git Bash: "command -v" on a missing tool looks into every PATH directory, with the Windows PATH (100
# entries) 16 ms each, and the files below ask for about 45 tools (27.10.26). While they load, one listing of the
# PATH directories answers the misses; the end of this file removes the wrapper again.
case $OSTYPE in
  cygwin*|msys*)
    declare -A _dot_cmds=()
    _dot_cmd_dirs=: _dot_cmd_path=
    command()
    {
      [ "$1" = -v ] && [ $# = 2 ] && [[ $2 != */* ]] || { builtin command "$@"; return; }
      if [ "$PATH" != "$_dot_cmd_path" ]; then
        local - d f x IFS=:
        set -f
        for d in $PATH; do
          [[ $_dot_cmd_dirs == *":${d:-.}:"* ]] && continue
          _dot_cmd_dirs+="${d:-.}:"
          set +f; f=("${d:-.}"/*); set -f
          f=("${f[@]##*/}"); f=("${f[@],,}")
          printf -v x '[%q]=1 ' "${f[@]%.exe}"
          eval "_dot_cmds+=($x)"
        done
        _dot_cmd_path=$PATH
      fi
      [ -n "${_dot_cmds[${2,,}]:-}" ] && { builtin command -v "$2"; return; }
      # no such file in PATH: an alias, function or builtin still counts, found without the PATH walk
      PATH=/nonexistent builtin command -v "$2"
    }
    ;;
esac

#OS Check
_dot_time shootProfile shootProfile
shopt -s histappend 

#load basisc
#printf "\t%s \t%s \n" fresh "Base" 
_loadFile "$HOME"/.dot/.bash_aliases "Base Alias"
_loadFile "$HOME"/.dot/.bash_functions.sh "Base Functions"
_loadFile "$HOME"/.dot/.exports "Base Exports"
_loadFile "$HOME"/.dot/bin/sensible.bash "Bash Stuff"
_loadFile "$HOME"/.dot/prompt.sh "Prompt"

#printf "\t%s \t%s \n" "$DIST $PSUEDONAME $REV $MODELL_TYPE" 

# DIST, PSUEDONAME: lower-case system and codename from shootProfile (core.sh); DOT_OS_BASE is the family, so
# Ubuntu derivatives (Linux Mint, Pop!_OS, ...) load the Ubuntu files too
if [ "$DOT_OS_BASE" = "ubuntu" ]; then   
  # load the shell dotfiles, and then some:
  # * ~/.path can be used to extend `$PATH`.
  # * ~/.extra can be used for other settings you don’t want to commit.
  #for file in ~/.{config_dotfiles,path,load,colors,exports,icons,aliases,bash_complete,functions,extra,dotfilecheck}; do
  #for file in ~/.dot/ubuntu16/{.bashrc,.exports,.bash_aliases,debian.sh}; do
  #    [ -r "$file" ] && [ -f "$file" ] && _loadFile "$file"
  #done
  #printf "\t%s \t%s \n" fresh "Ubuntu $PSUEDONAME $REV"   
 
  if [ "$PSUEDONAME" = "disco" ]; then
      _loadFile "$HOME"/.dot/ubuntu19/.bashrc "Debian Userpromt"
      _loadFile "$HOME"/.dot/ubuntu19/.exports "Exports"
      _loadFile "$HOME"/.dot/ubuntu19/.bash_aliases "Debian Alias"    
    elif [ "$PSUEDONAME" = "bionic" ]; then
      _loadFile "$HOME"/.dot/ubuntu18/.bashrc "Debian Userpromt"
      _loadFile "$HOME"/.dot/ubuntu18/.exports "Exports"
      _loadFile "$HOME"/.dot/ubuntu18/.bash_aliases "Debian Alias"    
    # the version folders serve their own release only; newer Ubuntu and derivatives use the base (prompt.sh)
    elif [ "$PSUEDONAME" = "xenial" ]; then
      _loadFile "$HOME"/.dot/ubuntu16/.bashrc "Debian Userpromt"
      _loadFile "$HOME"/.dot/ubuntu16/.exports "Exports"
      _loadFile "$HOME"/.dot/ubuntu16/.bash_aliases "Debian Alias"
    fi
fi  

#PROG="`basename $0`" 
#BASEDIR=$(dirname "$0")
#echo "$BASEDIR"

if [ "$DIST" = "synology" ]; then 
  _loadFile "$HOME"/.dot/synology/.bashrc "$DIST Userpromt"
  _loadFile "$HOME"/.dot/synology/.exports " $DIST Exports"
  _loadFile "$HOME"/.dot/synology/.bash_aliases "$DIST Alias"
fi  

# raspi: Raspberry Pi OS or any distro on a Pi device tree (lib/detect.sh), not every Debian
if [ "$DIST" = "raspi" ]; then
 _loadFile "$HOME"/.dot/raspi/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/raspi/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/raspi/.bash_aliases "$DIST bash_aliases"
 _loadFile "$HOME"/.dot/raspi/raspi_bash_functions.sh "$DIST Functions"
fi

if [ "$DIST" = "proxmox" ]; then
 _loadFile "$HOME"/.dot/proxmox/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/proxmox/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/proxmox/.bash_aliases "$DIST bash_aliases"
 _loadFile "$HOME"/.dot/proxmox/proxmox_bash_functions.sh "$DIST Functions"
 _loadMotd "$HOME"/.dot/proxmox/motd_proxmox.sh "$DIST motd_proxmox"
fi

if [ "$DIST" = "asuswrt" ]; then 
 _loadFile "$HOME"/.dot/asuswrt/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/asuswrt/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/asuswrt/.bash_aliases "$DIST bash_aliases"  
 _loadFile "$HOME"/.dot/asuswrt/asus_bash_functions.sh "$DIST Functions"  
 _loadMotd "$HOME"/.dot/asuswrt/EntwareApps.sh "$DIST EntwareApps.sh"  
 _loadMotd "$HOME"/.dot/asuswrt/motd_asus.sh "$DIST motd_asus.sh"  
fi 

if [ "$DIST" = "kali" ]; then 
 _loadFile "$HOME"/.dot/kali/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/kali/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/kali/.bash_aliases "$DIST bash_aliases" 
 _loadMotd "$HOME"/.dot/kali/motd_kali.sh "$DIST motd_kali.sh"
fi 

if [ "$DIST" = "unraid" ]; then 
 _loadFile "$HOME"/.dot/unraid/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/unraid/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/unraid/.bash_aliases "$DIST bash_aliases" 
 _loadFile "$HOME"/.dot/unraid/unraid_bash_functions.sh "$DIST bash_aliases" 
 _loadMotd "$HOME"/.dot/unraid/motd/10-display-name "$DIST bash_aliases" 
 _loadMotd "$HOME"/.dot/unraid/motd/20-sysinfo "$DIST bash_aliases" 
fi 

# Cygwin, Git Bash and MSYS2 (lib/detect.sh): open, clipboard, path conversion, native symlinks
if [ "$DIST" = cygwin ] || [ "$DIST" = msys ]; then
 _loadFile "$HOME"/.dot/windows/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/windows/.bash_aliases "$DIST bash_aliases"
fi

# every other Linux gets the general login screen; the special systems above bring their own, Windows none
case $DIST in
  synology|raspi|proxmox|asuswrt|kali|unraid|cygwin|msys) ;;
  *) _loadMotd "$HOME"/.dot/motd.sh "motd" ;;
esac

#echo $DIST



# ______ ______   _____________________ __________________________
# ___  //_/__  | / /__    |__    |__  //_/__  __ \__  __ \_  ____/
# __  ,<  __   |/ /__  /| |_  /| |_  ,<   _  / / /_  /_/ /  / __  
# _  /| | _  /|  / _  ___ |  ___ |  /| |__/ /_/ /_  _, _// /_/ /  
# /_/ |_| /_/ |_/  /_/  |_/_/  |_/_/ |_|(_)____/ /_/ |_| \____/   


#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

 
# Hint instead of 'homeshick refresh': its [yN] prompt blocked logins of scripts and agents.
# Reports commits known from the last fetch and fetches in the background for the next login.
_dotfilesCheck()
{
  local repo name behind to=""
  # no git is no error
  command -v git >/dev/null || return 0
  command -v timeout >/dev/null && to="timeout 20"
  for repo in "$HOME"/.homesick/repos/*; do
    [ -d "$repo/.git" ] || continue
    name=${repo##*/}
    behind=$(git -C "$repo" rev-list --count HEAD..@{u} 2>/dev/null)
    # dotupdate links the new files too and removes leftovers; a bare "homeshick pull" left new files unlinked
    if [ "${behind:-0}" -gt 0 ]; then
      if [ "$name" = dotfiles ]; then print_style " dotfiles: $behind new commit(s), update with: dotupdate" "warning"
      else print_style " $name: $behind new commit(s), update with: homeshick pull $name && homeshick link $name" "warning"; fi
      echo
    fi
    # fetch at most every 6 hours; never ask for credentials. The age check runs in the background too: a find
    # costs 50 ms on Windows (28.10.26). The job lets go of the terminal, also of fd 255 where an interactive bash
    # keeps it: else "bash -lic cmd 2>&1 | ..." waited for the fetch (28.10.26)
    ( exec 255>&- </dev/null >/dev/null 2>&1
      [ -n "$(find "$repo/.git/FETCH_HEAD" -mmin -360)" ] ||
        GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" $to git -C "$repo" fetch -q & )
  done
}

# every system, not only those with a folder of their own
_dotfilesCheck

#a command-line fuzzy finde
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

#locals
[ -f ~/.dot/.secrets ] && source ~/.dot/.secrets 

# behind the system commands, which the scripts here must not hide; once only, a new login shell loads this again
# (28.10.26)
case ":$PATH:" in
  *":$HOME/.dot/bin:"*) ;;
  *) [ ! -d "$HOME/.dot/bin" ] || export PATH="$PATH:$HOME/.dot/bin" ;;
esac

if [ -d ~/.git-radar ] ; then
  export PATH=~/.git-radar:$PATH
fi

# modern replacements (cat->bat, ping->gping, df->duf, top->btop …), after all functions on purpose
_loadFile "$HOME"/.dot/.bash_aliases_modern "Modern Alias"


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

###-begin-pm2-completion-###
### credits to npm for the completion file model
#
# Installation: pm2 completion >> ~/.bashrc  (or ~/.zshrc)
#

COMP_WORDBREAKS=${COMP_WORDBREAKS/=/}
COMP_WORDBREAKS=${COMP_WORDBREAKS/@/}
export COMP_WORDBREAKS

if type complete &>/dev/null; then

  _pm2_completion () 
  {
    local si="$IFS"
    IFS=$'\n' COMPREPLY=($(COMP_CWORD="$COMP_CWORD" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           pm2 completion -- "${COMP_WORDS[@]}" \
                           2>/dev/null)) || return $?
    IFS="$si"
  }

  complete -o default -F _pm2_completion pm2

elif type compctl &>/dev/null; then

  _pm2_completion () 
  {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       pm2 completion -- "${words[@]}" \
                       2>/dev/null)) || return $?
    IFS="$si"
  }
  compctl -K _pm2_completion + -f + pm2
fi
###-end-pm2-completion-###

# personal settings that stay out of the repository (EDITOR, tokens, ...); setup.sh writes them
[ -r "$HOME/.extra" ] && . "$HOME/.extra"

# the command -v wrapper of Cygwin and Git Bash serves the loading only
if [ -n "${_dot_cmd_dirs:-}" ]; then
  unset -f command
  unset _dot_cmds _dot_cmd_dirs _dot_cmd_path
fi
