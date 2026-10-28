# ~/.profile: executed by Bourne-compatible login shells.

#host files
if [ -f "$HOME/.dot/hosts/.${HOSTNAME:-}" ]; then
  . "$HOME/.dot/hosts/.${HOSTNAME:-}"
fi

# some systems load ~/.bashrc already from /etc/profile (Synology DSM: /etc.defaults/.bashrc_profile): once is enough.
# Bash only: BusyBox ash (Alpine, Asuswrt) and dash read ~/.profile too and stop at the bash syntax (28.10.26)
if [ -n "${BASH_VERSION:-}" ] && [ -f ~/.bashrc ] && [ -z "${_dot_bashrc_loaded:-}" ]; then
  . ~/.bashrc
elif [ -z "${BASH_VERSION:-}" ] && [ -f ~/.bashrc ]; then
  # an interactive login with another shell (Asuswrt's ash, root's sh on Alpine): continue in bash when there is one,
  # else say why prompt and aliases are missing; scripts and scp (not interactive) stay untouched
  case $- in
    *i*) if command -v bash >/dev/null 2>&1; then exec bash -l
         else echo "dotfiles: no bash here, prompt, aliases and MOTD need it (Asuswrt: opkg install bash)"; fi ;;
  esac
fi

 if [ -f /bin/mseg ]; then
    mesg n || true
  fi


#[ ! -s ~/.plesk_banner ] || . ~/.plesk_banner
 

# "if", not "&&": as the last line, a missing file made ~/.profile return 1 and ended scripts with "set -e"
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
