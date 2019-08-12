# ------------------------------------------------------------------------------
# | #plesk   Ubuntu 16                                                         |
# ------------------------------------------------------------------------------

alias pleskReadPhpHandler="plesk bin php_handler --reread"
alias peclPhp70Install="/opt/plesk/php/7.0/bin/pecl install "
alias peclPhp71Install="/opt/plesk/php/7.1/bin/pecl install "
alias peclPhp72Install="/opt/plesk/php/7.2/bin/pecl install "
alias peclPhp73Install="/opt/plesk/php/7.3/bin/pecl install "
alias pleskRestart="service sw-engine restart && service sw-cp-server restart"

# ------------------------------------------------------------------------------
# | #apache Ubuntu 16                                                          |
# ------------------------------------------------------------------------------

alias apacheModsAvailable="ls -l /etc/apache2/mods-available/"
alias apacheModsEnabled="ls -l /etc/apache2/mods-enabled/"
alias restartApachePhp="service apache2 restart" 
alias restartPhp73fpm="service plesk-php73-fpm restart"


alias aliasls='cat ~/.bashrc | grep alias'

alias py3='python3'
alias py='py3'
alias p3='py3'
alias p='py3'

alias bd=". bd -s"
alias eachdir=". eachdir"

# ------------------------------------------------------------------------------
# | Navigation                                                                 |
# ------------------------------------------------------------------------------

alias cdknaak='cd /var/www/vhosts/knaak.org/httpdocs'
alias cd_Aptlist='cd /etc/apt/'
alias cd_git="cd $HOME/git"
alias cd_Scripts="cd $HOME/git/scripts"

# ------------------------------------------------------------------------------
# | services Ubuntu 16                                                         |
# ------------------------------------------------------------------------------

#https://superuser.com/questions/896812/all-systemd-states

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
# | php                                                                        |
# ------------------------------------------------------------------------------

alias listLoadedPhpInis7="php --ini"
alias listLoadedPhpInis73="php73 --ini"


