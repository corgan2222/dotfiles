alias py3='python3'
alias py='py3'
alias p3='py3'
alias p='py3'


# ------------------------------------------------------------------------------
# | Navigation                                                                 |
# ------------------------------------------------------------------------------

alias cd_Scripts="cd $HOME/git/scripts"

# ------------------------------------------------------------------------------
# | Apt                                                                        |
# ------------------------------------------------------------------------------

alias ap='opkg install '
alias apuu='opkg update'
alias aptList="opkg list"

if [ "$MODELL_TYPE" == "DS1817+" ]; then
  source "$HOME/.dot/synology/motd.sh"
else  
  source "$HOME/.dot/synology/motd_415.sh"
fi  