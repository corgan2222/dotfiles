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

alias startNetdata="sudo /opt/etc/init.d/S60netdata start"
alias stopNetdata="sudo /opt/etc/init.d/S60netdata stop"

alias startZabbix_Agent="sudo /opt/etc/init.d/S07zabbix_agentd start"
alias stopZabbix_Agent="sudo /opt/etc/init.d/S07zabbix_agentd stop"


if [ "$MODELL_TYPE" == "DS1817+" ]; then
  source "$HOME/.dot/synology/motd.sh"
else  
  source "$HOME/.dot/synology/motd_415.sh"
fi  

