#!/bin/bash
# Which package brings a command, per package manager: for the commands the aliases and functions of these dotfiles
# call and that basics.sh does not install. command_not_found_handle (.bash_functions.sh) reads it only when a command
# is missing, so the login does not pay for it. "-" = no package there. Names checked in the images with
# lab/test-cmdpkg.sh.
#   command        apt                     dnf (Fedora)                dnf (RHEL+EPEL)             pacman               zypper              apk
_DOT_CMDPKG='
ffmpeg         ffmpeg                  ffmpeg-free                 ffmpeg-free                 ffmpeg               ffmpeg-7            ffmpeg
nmap           nmap                    nmap                        nmap                        nmap                 nmap                nmap
exiftool       libimage-exiftool-perl  perl-Image-ExifTool         perl-Image-ExifTool         perl-image-exiftool  exiftool            exiftool
python3        python3                 python3                     python3                     python               python313           python3
python         python-is-python3       python-unversioned-command  python-unversioned-command  python               python313           python3
pip3           python3-pip             python3-pip                 python3-pip                 python-pip           python313-pip       py3-pip
xmlstarlet     xmlstarlet              xmlstarlet                  xmlstarlet                  xmlstarlet           xmlstarlet          xmlstarlet
yamllint       yamllint                yamllint                    yamllint                    yamllint             python313-yamllint  yamllint
multitail      multitail               multitail                   multitail                   -                    multitail           -
arp-scan       arp-scan                arp-scan                    arp-scan                    arp-scan             arp-scan            arp-scan
wavemon        wavemon                 wavemon                     -                           wavemon              wavemon             wavemon
iw             iw                      iw                          iw                          iw                   iw                  iw
recode         recode                  recode                      recode                      recode               recode              -
bc             bc                      bc                          bc                          bc                   bc                  bc
figlet         figlet                  figlet                      figlet                      figlet               figlet              figlet
toilet         toilet                  toilet                      toilet                      toilet               -                   -
lolcat         lolcat                  lolcat                      lolcat                      lolcat               -                   -
lynx           lynx                    lynx                        lynx                        lynx                 lynx                lynx
gifsicle       gifsicle                gifsicle                    gifsicle                    gifsicle             gifsicle            gifsicle
convert        imagemagick             ImageMagick                 ImageMagick                 imagemagick          ImageMagick         imagemagick
dcraw          dcraw                   dcraw                       dcraw                       dcraw                dcraw               -
parallel       parallel                parallel                    parallel                    parallel             gnu_parallel        parallel
ngrep          ngrep                   ngrep                       ngrep                       ngrep                -                   ngrep
tcpdump        tcpdump                 tcpdump                     tcpdump                     tcpdump              tcpdump             tcpdump
strace         strace                  strace                      strace                      strace               strace              strace
xxd            xxd                     vim-common                  vim-common                  vim                  vim                 xxd
cabextract     cabextract              cabextract                  cabextract                  cabextract           cabextract          cabextract
rpm2cpio       rpm2cpio                rpm                         rpm                         rpm-tools            rpm                 rpm2cpio
cpio           cpio                    cpio                        cpio                        cpio                 cpio                cpio
telnet         telnet                  telnet                      telnet                      inetutils            telnet              busybox-extras
logrotate      logrotate               logrotate                   logrotate                   logrotate            logrotate           logrotate
locate         plocate                 plocate                     mlocate                     plocate              plocate             mlocate
lspci          pciutils                pciutils                    pciutils                    pciutils             pciutils            pciutils
lsusb          usbutils                usbutils                    usbutils                    usbutils             usbutils            usbutils
dig            dnsutils                bind-utils                  bind-utils                  bind                 bind-utils          bind-tools
xdg-open       xdg-utils               xdg-utils                   xdg-utils                   xdg-utils            xdg-utils           xdg-utils
puttygen       putty-tools             putty                       putty                       putty                putty               putty
yt-dlp         yt-dlp                  yt-dlp                      -                           yt-dlp               yt-dlp              yt-dlp
vim            vim                     vim-enhanced                vim-enhanced                vim                  vim                 vim
iptables       iptables                iptables-nft                iptables-nft                iptables             iptables            iptables
nft            nftables                nftables                    nftables                    nftables             nftables            nftables
lsof           lsof                    lsof                        lsof                        lsof                 lsof                lsof
tree           tree                    tree                        tree                        tree                 tree                tree
ack            ack                     ack                         ack                         -                    ack                 ack
ssh            openssh-client          openssh-clients             openssh-clients             openssh              openssh-clients     openssh-client
scp            openssh-client          openssh-clients             openssh-clients             openssh              openssh-clients     openssh-client
sftp           openssh-client          openssh-clients             openssh-clients             openssh              openssh-clients     openssh-client
ssh-keygen     openssh-client          openssh-clients             openssh-clients             openssh              openssh-clients     openssh-keygen
diff           diffutils               diffutils                   diffutils                   diffutils            diffutils           diffutils
hostname       hostname                hostname                    hostname                    inetutils            hostname            -
pygmentize     python3-pygments        python3-pygments            -                           python-pygments      python313-Pygments  py3-pygments
ruby           ruby                    ruby                        ruby                        ruby                 ruby                ruby
gem            ruby                    rubygems                    rubygems                    rubygems             ruby                ruby
traceroute     traceroute              traceroute                  traceroute                  traceroute           traceroute          -
whois          whois                   whois                       whois                       whois                whois               whois
ip             iproute2                iproute                     iproute                     iproute2             iproute2            iproute2
ss             iproute2                iproute                     iproute                     iproute2             iproute2            iproute2
grc            grc                     grc                         -                           grc                  grc                 -
mysql          mariadb-client          mariadb                     mariadb                     mariadb-clients      mariadb-client      mariadb-client
php            php-cli                 php-cli                     php-cli                     php                  php8                php
pv             pv                      pv                          pv                          pv                   pv                  pv
'

# prints the package of command $1 for this package manager (DOT_PKG), nothing when unknown or "-"
_dot_cmdpkg() {
  local col
  case ${DOT_PKG:-} in
    apt) col=2 ;;
    dnf|yum) if [ "${DOT_OS_BASE:-}" = rhel ]; then col=4; else col=3; fi ;;
    pacman) col=5 ;; zypper) col=6 ;; apk) col=7 ;; *) return 0 ;;
  esac
  awk -v c="$1" -v k="$col" '$1 == c && $k != "-" { print $k; exit }' <<<"$_DOT_CMDPKG"
}
