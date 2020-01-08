[31m# prompt_yn[0;37m()
[32m
[31m# get_keypress[0;37m()
[32m>* Read a single char from /dev/tty, prompting with "$*"
>* Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
>* See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.

[31m# get_yes_keypress[0;37m()
[32m>* Get a y/n from the user, return yes=0, no=1 enter=$2
>* Prompt using $1.
>* If set, return $2 on pressing enter, useful for cancel or defualting

[31m# confirm[0;37m()
[32m>* Credit: http://unix.stackexchange.com/a/14444/143394
>* Prompt to confirm, defaulting to NO on <enter>
>* Usage: confirm "Dangerous. Are you sure?" && rm *

[31m# confirm_yes[0;37m()
[32m>* Prompt to confirm, defaulting to YES on <enter>

[31m# scriptInfoPerl[0;37m()
[32m>*prints all functions from file

[31m# scriptInfoPerl_forGithub[0;37m()
[32m>*prints all functions from file

[31m# create_github_docs[0;37m()
[32m
[31m# function_exists[0;37m()
[32m>*return 0 on exist and 1 if not

[31m# findStringInFiles[0;37m()
[32m>*usage findStringInFiles /etc foo exclud
>*"Usage:  findStringInFiles 'string' 'folder' ['exclude']"

[31m# createUserSSH[0;37m()
[32m>*create ssh files for new user

[31m# user_add_with_pass_and_folder[0;37m()
[32m
[31m# user_remove[0;37m()
[32m
[31m# replaceStringInFile[0;37m()
[32m>*replaceStringInFile 'string' 'replace' file"

[31m# GetFilelist_clean[0;37m()
[32m>*GetFilelist_clean /home/user

[31m# GetFilelist_prefix[0;37m()
[32m>*GetFilelist_prefix ../PATH/TO/FOLDER/TO/LIST/FILES/FROM -type f -printf "%f\n

[31m# initHome[0;37m()
[32m>*init homeShick

[31m# saveHome[0;37m()
[32m>*save changes in dotfiles

[31m# loadHome[0;37m()
[32m>*load newest dotfiles

[31m# checkHome[0;37m()
[32m>*check dotfiles

[31m# gitSaveCredential[0;37m()
[32m>*save git infos

[31m# addToHome[0;37m()
[32m>*add new files or folder to dotfiles

[31m# mkcdir[0;37m()
[32m>*create folder and enter it

[31m# psKillAllX[0;37m()
[32m>*kill all processess

[31m# video2gif[0;37m()
[32m>* Convert video to gif file.
>* Usage: video2gif video_file (scale) (fps)

[31m# man[0;37m()
[32m>*color man

[31m# extract[0;37m()
[32m>* extract: unified archive extractor
>* usage: extract <file>

[31m# mkdatedir[0;37m()
[32m>*create folder with the current date

[31m# gifify[0;37m()
[32m>*create gif 
>*Usage: gifify <file_path>' 

[31m# parse_git_branch[0;37m()
[32m>* get current branch in git repo

[31m# parse_git_dirty[0;37m()
[32m>* get current status of git repo

[31m# git[0;37m()
[32m
[31m# nonzero_return[0;37m()
[32m
[31m# lc[0;37m()
[32m>* lc: Convert the parameters or STDIN to lowercase.

[31m# uc[0;37m()
[32m>* uc: Convert the parameters or STDIN to uppercase.

[31m# wtfis[0;37m()
[32m>* -------------------------------------------------------------------
>* wtfis: Show what a given command really is. It is a combination of "type", "file"
>* and "ls". Unlike "which", it does not only take $PATH into account. This
>* means it works for aliases and hashes, too. (The name "whatis" was taken,
>* and I did not want to overwrite "which", hence "wtfis".)
>* The return value is the result of "type" for the last command specified.
>*
>* usage:
>*
>*   wtfis man
>*   wtfis vi
>*
>* source: https://raw.githubusercontent.com/janmoesen/tilde/master/.bash/commands

[31m# whenis[0;37m()
[32m>* -------------------------------------------------------------------
>* whenis: Try to make sense of the date. It supports everything GNU date knows how to
>* parse, as well as UNIX timestamps. It formats the given date using the
>* default GNU date format, which you can override using "--format='%x %y %z'.
>*
>* usage:
>*
>*   $ whenis 1234567890            >* UNIX timestamps
>*   Sat Feb 14 00:31:30 CET 2009
>*
>*   $ whenis +1 year -3 months     >* relative dates
>*   Fri Jul 20 21:51:27 CEST 2012
>*
>*   $ whenis 2011-10-09 08:07:06   >* MySQL DATETIME strings
>*   Sun Oct  9 08:07:06 CEST 2011
>*
>*   $ whenis 1979-10-14T12:00:00.001-04:00 >* HTML5 global date and time
>*   Sun Oct 14 17:00:00 CET 1979
>*
>*   $ TZ=America/Vancouver whenis >* Current time in Vancouver
>*   Thu Oct 20 13:04:20 PDT 2011
>*
>* For more info, check out http://kak.be/gnudateformats.

>* Default GNU date format as seen in date.c from GNU coreutils.
[31m# box[0;37m()
[32m>* -------------------------------------------------------------------
>* box: a function to create a box of '=' characters around a given string
>*
>* usage: box 'testing'

[31m# htmlEntityToUTF8[0;37m()
[32m>* -------------------------------------------------------------------
>* htmlEntityToUTF8: convert html-entity to UTF-8

[31m# UTF8toHtmlEntity[0;37m()
[32m>* -------------------------------------------------------------------
>* UTF8toHtmlEntity: convert UTF-8 to html-entity

[31m# optiImages[0;37m()
[32m>* -------------------------------------------------------------------
>* optiImages: optimized images (png/jpg) in the current dir + sub-dirs
>*
>* INFO: use "grunt-contrib-imagemin" for websites!

[31m# lman[0;37m()
[32m>* -------------------------------------------------------------------
>* lman: Open the manual page for the last command you executed.

[31m# testConnection[0;37m()
[32m>* -------------------------------------------------------------------
>* testConnection: check if connection to google.com is possible
>*
>* usage:
>*   testConnection 1  >* will echo 1 || 0
>*   testConnection    >* will return 1 || 0

[31m# netstat_used_local_ports[0;37m()
[32m>* -------------------------------------------------------------------
>* netstat_used_local_ports: get used tcp-ports

[31m# netstat_free_local_port[0;37m()
[32m>* -------------------------------------------------------------------
>* netstat_free_local_port: get one free tcp-port

>* didn't work with zsh / bash is ok
>*read lowerPort upperPort < /proc/sys/net/ipv4/ip_local_port_range
[31m# netstat_connection_overview[0;37m()
[32m>* -------------------------------------------------------------------
>* connection_overview: get stats-overview about your connections

[31m# mount_info[0;37m()
[32m>* -------------------------------------------------------------------
>* nice mount (http://catonmat.net/blog/another-ten-one-liners-from-commandlingfu-explained)
>*
>* displays mounted drive information in a nicely formatted manner

[31m# mountFile[0;37m()
[32m
[31m# sniff[0;37m()
[32m>* -------------------------------------------------------------------
>* sniff: view HTTP traffic
>*
>* usage: sniff [eth0]

[31m# httpdump[0;37m()
[32m>* -------------------------------------------------------------------
>* httpdump: view HTTP traffic
>*
>* usage: httpdump [eth1]

[31m# iptablesBlockIP[0;37m()
[32m>* -------------------------------------------------------------------
>* iptablesBlockIP: block a IP via "iptables"
>*
>* usage: iptablesBlockIP 8.8.8.8

[31m# ips[0;37m()
[32m>* -------------------------------------------------------------------
>* ips: get the local IP's

[31m# os[0;37m()
[32m>* -------------------------------------------------------------------
>* os-info: show some info about your system

[31m# command_exists[0;37m()
[32m>* -------------------------------------------------------------------
>* command_exists: check if a command exists

[31m# stripspace[0;37m()
[32m>* -------------------------------------------------------------------
>* stripspace: strip unnecessary whitespace from file

[31m# logssh[0;37m()
[32m>* -------------------------------------------------------------------
>* logssh: establish ssh connection + write a logfile

[31m# lsssh[0;37m()
[32m>* -------------------------------------------------------------------
>* lsssh: pretty print all established SSH connections

[31m# calc[0;37m()
[32m>* -------------------------------------------------------------------
>* calc: Simple calculator
>* usage: e.g.: 3+3 || 6*6/2

[31m# mkd[0;37m()
[32m>* -------------------------------------------------------------------
>* mkd: Create a new directory and enter it

[31m# mkf[0;37m()
[32m>* -------------------------------------------------------------------
>* mkf: Create a new directory, enter it and create a file
>*
>* usage: mkf /tmp/lall/foo.txt

[31m# rand_int[0;37m()
[32m>* -------------------------------------------------------------------
>* rand_int: use "urandom" to get random int values
>*
>* usage: rand_int 8 --> e.g.: 32245321

[31m# passwdgen[0;37m()
[32m>* -------------------------------------------------------------------
>* passwdgen: a password generator
>*
>* usage: passwdgen 8 --> e.g.: f4lwka_2f

[31m# targz[0;37m()
[32m>* -------------------------------------------------------------------
>* targz: Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression

[31m# duh[0;37m()
[32m>* -------------------------------------------------------------------
>* duh: Sort the "du"-command output and use human-readable units.

[31m# fs[0;37m()
[32m>* -------------------------------------------------------------------
>* fs: Determine size of a file or total size of a directory

[31m# ff[0;37m()
[32m>* -------------------------------------------------------------------
>* ff: displays all files in the current directory (recursively)

[31m# fstr[0;37m()
[32m>* -------------------------------------------------------------------
>* fstr: find text in files

[31m# file_backup_compressed[0;37m()
[32m>* -------------------------------------------------------------------
>* file_backup_compressed: create a compressed backup (with date)
>* in the current dir
>*
>* usage: file_backup_compressed test.txt

[31m# file_backup[0;37m()
[32m>* -------------------------------------------------------------------
>* file_backup: creating a backup of a file (with date)

[31m# file_information[0;37m()
[32m>* -------------------------------------------------------------------
>* file_information: output information to a file

[31m# dataurl[0;37m()
[32m>* -------------------------------------------------------------------
>* dataurl: create a data URL from a file

[31m# create_server[0;37m()
[32m>* -------------------------------------------------------------------
>* server: Start an HTTP server from a directory, optionally specifying the port

[31m# phpserver[0;37m()
[32m>* -------------------------------------------------------------------
>* phpserver: Start a PHP server from a directory, optionally specifying 2x $_ENV and ip:port
>* (Requires PHP 5.4.0+.)
>*
>* usage:
>* phpserver [port=auto] [ip=127.0.0.1] [FOO_1=BAR_1] [FOO_2=BAR_2]

[31m# php[0;37m()
[32m>* php-parse-error-check: check for parse errors
>*
>* usage: php-parse-error-check /var/www/web3/

[31m# psgrep[0;37m()
[32m>* -------------------------------------------------------------------
>* psgrep: grep a process

[31m# cpuinfo[0;37m()
[32m>* -------------------------------------------------------------------
>* cpuinfo: get info about your cpu

[31m# jsonc[0;37m()
[32m>* -------------------------------------------------------------------
>* json: Syntax-highlight JSON strings or files
>*
>* usage: json '{"foo":42}'` or `echo '{"foo":42}' | json

[31m# escape[0;37m()
[32m>* -------------------------------------------------------------------
>* escape: Escape UTF-8 characters into their 3-byte format

[31m# unidecode[0;37m()
[32m>* -------------------------------------------------------------------
>* unidecode: Decode \x{ABCD}-style Unicode escape sequences

[31m# history_top_used[0;37m()
[32m>* -------------------------------------------------------------------
>* history_top_used: show your most used commands in your history

[31m# getcertnames[0;37m()
[32m>* -------------------------------------------------------------------
>* getcertnames: Show all the names (CNs and SANs) listed in the
>*               SSL certificate for a given domain.
>*
>* usage: getcertnames moelleken.org

[31m# t[0;37m()
[32m>* -------------------------------------------------------------------
>* tail with search highlight
>*
>* usage: t /var/log/Xorg.0.log [kHz]

[31m# httpDebug[0;37m()
[32m>* -------------------------------------------------------------------
>* httpDebug: download a web page and show info on what took time
>*
>* usage: httpDebug http://github.com

[31m# digga[0;37m()
[32m>* -------------------------------------------------------------------
>* digga: show dns-settings from a domain e.g. MX, IP
>*
>* usage: digga moelleken.org

[31m# tre[0;37m()
[32m>* -------------------------------------------------------------------
>* `tre`: is a shorthand for `tree` with hidden files and color enabled, ignoring
>* the `.git` directory, listing directories first. The output gets piped into
>* `less` with options to preserve color and line numbers, unless the output is
>* small enough for one screen.

[31m# pidenv[0;37m()
[32m>* -------------------------------------------------------------------
>* pidenv: show PID environment in human-readable form
>*
>* https://github.com/darkk/home/blob/master/bin/pidenv

[31m# processenv[0;37m()
[32m>* -------------------------------------------------------------------
>* process: show process-name environment in human-readable form

[31m# shorturl[0;37m()
[32m>* -------------------------------------------------------------------
>* shorturl: Create a short URL

[31m# ppp[0;37m()
[32m>* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
>* Process phone photo.

[31m# qh[0;37m()
[32m>* Search history.
>*           ┌─ enable colors for pipe
>*           │  ("--color=auto" enables colors only if
>*           │  the output is in the terminal)
>*grep --color=always "$*" "$HISTFILE" | less -RX
>* display ANSI color escape sequences in raw form ─┘│
>*       don't clear the screen after quitting less ─┘

[31m# qt[0;37m()
[32m>* Search for text within the current directory.
>*grep -ir --color=always "$*" --exclude-dir=".git" --exclude-dir="node_modules" . | less -RX
>*     │└─ search all files under each directory, recursively
>*     └─ ignore case

[31m# line[0;37m()
[32m>* Print a line of dashes or the given string across the entire screen.

[31m# center[0;37m()
[32m>* Print the given text in the center of the screen.

[31m# lman[0;37m()
[32m>* Open the man page for the previous command.

[31m# xxgetmac[0;37m()
[32m
[31m# to_lower[0;37m()
[32m>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Converts a string to lower case
>* Arguments:
>*   $1 -> String to convert to lower case

[31m# die[0;37m()
[32m>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Display an error message and die
>* Arguments:
>*   $1 -> Message
>*   $2 -> Exit status (optional)

[31m# is_root[0;37m()
[32m>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Return true if script is executed by the root user
>* Arguments: none
>* Return: True or False

[31m# is_user_exits[0;37m()
[32m>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Return true $user exits in /etc/passwd
>* Arguments: $1 (username) -> Username to check in /etc/passwd
>* Return: True or False

[31m# lastFileChange[0;37m()
[32m>* % date -d "@$(stat -c '%Y' a.out)"
>* Tue Jul 26 12:15:21 BDT 2016
>* date -r .bashrc Tue Aug  6 19:14:12 CEST 2019
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*

[31m# ps[0;37m()
[32m>* prints colored text
>* print_style "This is a green text " "success";
>* print_style "This is a yellow text " "warning";
>* print_style "This is a light blue with a \t tab " "info";
>* print_style "This is a red text with a \n new line " "danger";
>* print_style "This has no color";

[31m# telegrafAfterUpdate[0;37m()
[32m>*what to do after telegraf update

[31m# yaml_r[0;37m()
[32m>*https://coderwall.com/p/xatm5a/bash-one-liner-to-read-yaml-files

[31m# perlver[0;37m()
[32m>*info about perl

[31m# timeInfo[0;37m()
[32m>*all about the time

[31m# _cheat_autocomplete[0;37m()
[32m>*_cheat_autocomplete

[31m# h[0;37m()
[32m>*search in aliases, functions and cheats for the string

[31m# cheatsh[0;37m()
[32m>*wrapper for cheat.sh
>*cheatsh tar~list

[31m# alias_completion[0;37m()
[32m>* Automatically add completion for all aliases to commands having completion functions
>* source: http://superuser.com/questions/436314/how-can-i-get-bash-to-perform-tab-completion-for-my-aliases

[31m# getlocation[0;37m()
[32m>*Get your public IP address and host.

[31m# err[0;37m()
[32m>* -------------------------------------------------------------------
>* err: error message along with a status information
>*
>* example:
>*
>* if ! do_something; then
>*   err "Unable to do_something"
>*   exit "${E_DID_NOTHING}"
>* fi
>*

[31m# yt2mp3[0;37m()
[32m>*youtube-dl

[31m# mail_test_ssl_server_imap[0;37m()
[32m>*mail tester imap

[31m# mail_test_ssl_server_pop3[0;37m()
[32m>*mail tester pop3

[31m# mail_test_ssl_server_SMTP[0;37m()
[32m>*mail tester ssl

[31m# mail_test_ssl_server_SMTP_star[0;37m()
[32m>*mail tester imap

[31m# get_remote_file[0;37m()
[32m>*Funktion um Dateien aus dem Internet zu laden. Prüft ob curl vorhanden ist , wenn nicht wird wget versucht. Wenn gar nichts von beiden gefunden wird wird das Skript beendet.
>*https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
>* download an file to local storage
>* need 2 parameters : get_remote_file [URL_TO_FILE] [LOCAL_PATH]

[31m# check_files_in_zip[0;37m()
[32m>* Problem : Man möchte über Bash nur den Inhalt einer Zip Datei vergleichen. Die Zip Datei wird aber automatisiert auf einem Server über cron erstellt, was zur Folge hatte das der Zeitstempel und somit auch die md5 Summen unterschiedlich sind.
>* Lösung : Die Lösung ist mit unzip in die Datei zu schauen und diesen Output mit diff zu verleichen.
>* https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
>* compare the content of two zipfiles if equal the function return 0 otherwise 1
>* need 2 parameters : check_files_in_zip [NAME_OF_OLD_ZIPFILE] [NAME_OF_NEW_ZIPFILE]

[31m# geo[0;37m()
[32m>*geo-ip 144.178.0.0

[31m# sftp_keyfile[0;37m()
[32m>* "Usage: sftp_keyfile 'keyfile' port user host"
>* "sftp_keyfile PATH/TO/PUBLICKEYFILE(id_rsa) 10022 user host"

[31m# Export_image_file_statistics_to_csv[0;37m()
[32m>*"Usage: Export_image_file_statistics_to_csv 'output.csv' "

[31m# Export_image_file_statistics_to_csv_tabs[0;37m()
[32m>*"Usage:Tabs Export_image_file_statistics_to_csv_tabs 'output.csv' "

[31m# convert_cr2_to_jpg[0;37m()
[32m>*convert raw to jpg

[31m# ssh_copy_to_host[0;37m()
[32m>*Copy something from this system to some other system:
>*echo scp /path/to/local/file username@hostname:/path/to/remote/file  

[31m# ssh_copy_from_host_to_host[0;37m()
[32m>*Copy something from some system to some other system:
>*scp username1@hostname1:/path/to/file username2@hostname2:/path/to/other/file 	

[31m# ssh_copy_fron_host[0;37m()
[32m>*Copy something from another system to this system:
>*scp username@hostname:/path/to/remote/file /path/to/local/file  

[31m# convert_CR2_to_JPG_dcraw[0;37m()
[32m>*dcraw -c RAW-Dateiname | convert - Ausgabedatei.FORMAT  

[31m# checkSSLfromDomain[0;37m()
[32m>*curl -i -k -X GET -u root:rootpw "https://knaak.org:8443/api/v2/domains" -H  "accept: application/json"

[31m# random_32chars_al[0;37m()
[32m>* bash generate random alphanumeric string
>* bash generate random 32 character alphanumeric string (upper and lowercase) and 

[31m# random_32chars_lc[0;37m()
[32m>* bash generate random 32 character alphanumeric string (lowercase only)

[31m# random_number09[0;37m()
[32m>* Random numbers in a range, more randomly distributed than $RANDOM which is not
>* very random in terms of distribution of numbers.
>* bash generate random number between 0 and 9

[31m# random_number099[0;37m()
[32m>* bash generate random number between 0 and 99

[31m# random_number999[0;37m()
[32m>* bash generate random number between 0 and 999

[31m# syncFileToS3[0;37m()
[32m>*"Usage: syncFileToS3 'file' "

[31m# bool[0;37m()
[32m>* Print boolean value of the exit code of the command passed as argument.

[31m# split_path_dirs[0;37m()
[32m>* Split directories in a PATH-like variable.

[31m# contains_string[0;37m()
[32m>* Return whether a string is present in a list of strings.

[31m# is_interactive[0;37m()
[32m>* Return whether the shell is interactive.

[31m# sf[0;37m()
[32m>* Source a system file.  If no filename is given, list the available names.

[31m# gitHelpNew[0;37m()
[32m>*git help

[31m# dtags[0;37m()
[32m
[31m# vdiff[0;37m()
[32m>*file diff
>* "  comparing dirs:  vdiff dir_a dir_b"
>* "  comparing files: vdiff file_a file_b"

[31m# raw2jpg_embedded[0;37m()
[32m>*extract embedded jpg from raw with ufraw

[31m# raw2jpg_convert[0;37m()
[32m>* "Usage: raw2jpg_convert 'ARW|CR2' "

[31m# raw2jpg_parallel[0;37m()
[32m>*convert raw parallel

[31m# raw2jpg_ext[0;37m()
[32m>* "Usage: raw2jpg_ext 'ARW|CR2' 'outout Folder' "

[31m# checkURLs[0;37m()
[32m>*checkt ob angegebene files auf server vorhanden sind

[31m# package_exists[0;37m()
[32m>*epackage_exists

[31m# imgResize[0;37m()
[32m>*"Usage: imgResize '75' '91' "
>*"Usage: imgResize [sizeReduct][quality] "

[31m# getSSL[0;37m()
[32m
[31m# iptable_block_bad_countrys[0;37m()
[32m>*block all ip from country on all ports

[31m# iptable_ban_country[0;37m()
[32m>*block all ip from country on all ports

[31m# iptable_unban_country[0;37m()
[32m>*unblock all ip from country on all ports

[31m# iptable_ban_ip[0;37m()
[32m>*block  ip on all ports

[31m# iptable_unban_ip[0;37m()
[32m>*unblock  ip on all ports

[31m# iptable_check_ip[0;37m()
[32m>*is ip blocked

[31m# iptable_block_subnet[0;37m()
[32m>*is subnet blocked

[31m# iptable_view_blocked[0;37m()
[32m>*see all blocked IPs

[31m# diff_git_file[0;37m()
[32m>*diff compare local file with repo file

[31m# installer[0;37m()
[32m
