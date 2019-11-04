# ------------------------------------------------------------------------------
# | #plesk   Ubuntu 16                                                         |
# ------------------------------------------------------------------------------

alias pleskReadPhpHandler="plesk bin php_handler --reread"
alias peclPhp70Install="/opt/plesk/php/7.0/bin/pecl install "
alias peclPhp71Install="/opt/plesk/php/7.1/bin/pecl install "
alias peclPhp72Install="/opt/plesk/php/7.2/bin/pecl install "
alias peclPhp73Install="/opt/plesk/php/7.3/bin/pecl install "
alias pleskRestart="service sw-engine restart && service sw-cp-server restart"

alias py3='python3'
alias py36='python3.6'
alias pip36='python3.6 -m pip '
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

alias grep='grep --color=auto'

function help_(){
echo -e "
\e[0;32m h \e[0m \e[0;34m#search a+c+f\e[0m
\e[0;32m a \e[0m \e[0;34m#search aliases\e[0m
\e[0;32m c \e[0m \e[0;34m#search cheats\e[0m
\e[0;32m f \e[0m \e[0;34m#search functions\e[0m
\e[0;32m s \e[0m \e[0;34m#savehome\e[0m
\e[0;32m l \e[0m \e[0;34m#loadhome\e[0m
\e[0;32m eg \e[0m \e[0;34m#search eg cheats\e[0m
plesk bin <utility name> [parameters] [options]
"
    }

alias pleskCertsList="la -la /usr/local/psa/var/modules/letsencrypt/etc/live/"    