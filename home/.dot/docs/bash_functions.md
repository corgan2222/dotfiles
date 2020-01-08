# prompt_yn()

# get_keypress()
>* Read a single char from /dev/tty, prompting with "$*"
>* Note: pressing enter will return a null string. Perhaps a version terminated with X and then remove it in caller?
>* See https://unix.stackexchange.com/a/367880/143394 for dealing with multi-byte, etc.

# get_yes_keypress()
>* Get a y/n from the user, return yes=0, no=1 enter=$2
>* Prompt using $1.
>* If set, return $2 on pressing enter, useful for cancel or defualting

# confirm()
>* Credit: http://unix.stackexchange.com/a/14444/143394
>* Prompt to confirm, defaulting to NO on <enter>
>* Usage: confirm "Dangerous. Are you sure?" && rm *

# confirm_yes()
>* Prompt to confirm, defaulting to YES on <enter>

# scriptInfoPerl()
>*prints all functions from file

# scriptInfoPerl_forGithub()
>*prints all functions from file

# create_github_docs()

# function_exists()
>*return 0 on exist and 1 if not

# findStringInFiles()
>*usage findStringInFiles /etc foo exclud
>*"Usage:  findStringInFiles 'string' 'folder' ['exclude']"

# createUserSSH()
>*create ssh files for new user

# user_add_with_pass_and_folder()

# user_remove()

# replaceStringInFile()
>*replaceStringInFile 'string' 'replace' file"

# GetFilelist_clean()
>*GetFilelist_clean /home/user

# GetFilelist_prefix()
>*GetFilelist_prefix ../PATH/TO/FOLDER/TO/LIST/FILES/FROM -type f -printf "%f\n

# initHome()
>*init homeShick

# saveHome()
>*save changes in dotfiles

# loadHome()
>*load newest dotfiles

# checkHome()
>*check dotfiles

# gitSaveCredential()
>*save git infos

# addToHome()
>*add new files or folder to dotfiles

# mkcdir()
>*create folder and enter it

# psKillAllX()
>*kill all processess

# video2gif()
>* Convert video to gif file.
>* Usage: video2gif video_file (scale) (fps)

# man()
>*color man

# extract()
>* extract: unified archive extractor
>* usage: extract <file>

# mkdatedir()
>*create folder with the current date

# gifify()
>*create gif 
>*Usage: gifify <file_path>' 

# parse_git_branch()
>* get current branch in git repo

# parse_git_dirty()
>* get current status of git repo

# git()

# nonzero_return()

# lc()
>* lc: Convert the parameters or STDIN to lowercase.

# uc()
>* uc: Convert the parameters or STDIN to uppercase.

# wtfis()
>* -------------------------------------------------------------------
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

# whenis()
>* -------------------------------------------------------------------
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
# box()
>* -------------------------------------------------------------------
>* box: a function to create a box of '=' characters around a given string
>*
>* usage: box 'testing'

# htmlEntityToUTF8()
>* -------------------------------------------------------------------
>* htmlEntityToUTF8: convert html-entity to UTF-8

# UTF8toHtmlEntity()
>* -------------------------------------------------------------------
>* UTF8toHtmlEntity: convert UTF-8 to html-entity

# optiImages()
>* -------------------------------------------------------------------
>* optiImages: optimized images (png/jpg) in the current dir + sub-dirs
>*
>* INFO: use "grunt-contrib-imagemin" for websites!

# lman()
>* -------------------------------------------------------------------
>* lman: Open the manual page for the last command you executed.

# testConnection()
>* -------------------------------------------------------------------
>* testConnection: check if connection to google.com is possible
>*
>* usage:
>*   testConnection 1  >* will echo 1 || 0
>*   testConnection    >* will return 1 || 0

# netstat_used_local_ports()
>* -------------------------------------------------------------------
>* netstat_used_local_ports: get used tcp-ports

# netstat_free_local_port()
>* -------------------------------------------------------------------
>* netstat_free_local_port: get one free tcp-port

>* didn't work with zsh / bash is ok
>*read lowerPort upperPort < /proc/sys/net/ipv4/ip_local_port_range
# netstat_connection_overview()
>* -------------------------------------------------------------------
>* connection_overview: get stats-overview about your connections

# mount_info()
>* -------------------------------------------------------------------
>* nice mount (http://catonmat.net/blog/another-ten-one-liners-from-commandlingfu-explained)
>*
>* displays mounted drive information in a nicely formatted manner

# mountFile()

# sniff()
>* -------------------------------------------------------------------
>* sniff: view HTTP traffic
>*
>* usage: sniff [eth0]

# httpdump()
>* -------------------------------------------------------------------
>* httpdump: view HTTP traffic
>*
>* usage: httpdump [eth1]

# iptablesBlockIP()
>* -------------------------------------------------------------------
>* iptablesBlockIP: block a IP via "iptables"
>*
>* usage: iptablesBlockIP 8.8.8.8

# ips()
>* -------------------------------------------------------------------
>* ips: get the local IP's

# os()
>* -------------------------------------------------------------------
>* os-info: show some info about your system

# command_exists()
>* -------------------------------------------------------------------
>* command_exists: check if a command exists

# stripspace()
>* -------------------------------------------------------------------
>* stripspace: strip unnecessary whitespace from file

# logssh()
>* -------------------------------------------------------------------
>* logssh: establish ssh connection + write a logfile

# lsssh()
>* -------------------------------------------------------------------
>* lsssh: pretty print all established SSH connections

# calc()
>* -------------------------------------------------------------------
>* calc: Simple calculator
>* usage: e.g.: 3+3 || 6*6/2

# mkd()
>* -------------------------------------------------------------------
>* mkd: Create a new directory and enter it

# mkf()
>* -------------------------------------------------------------------
>* mkf: Create a new directory, enter it and create a file
>*
>* usage: mkf /tmp/lall/foo.txt

# rand_int()
>* -------------------------------------------------------------------
>* rand_int: use "urandom" to get random int values
>*
>* usage: rand_int 8 --> e.g.: 32245321

# passwdgen()
>* -------------------------------------------------------------------
>* passwdgen: a password generator
>*
>* usage: passwdgen 8 --> e.g.: f4lwka_2f

# targz()
>* -------------------------------------------------------------------
>* targz: Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression

# duh()
>* -------------------------------------------------------------------
>* duh: Sort the "du"-command output and use human-readable units.

# fs()
>* -------------------------------------------------------------------
>* fs: Determine size of a file or total size of a directory

# ff()
>* -------------------------------------------------------------------
>* ff: displays all files in the current directory (recursively)

# fstr()
>* -------------------------------------------------------------------
>* fstr: find text in files

# file_backup_compressed()
>* -------------------------------------------------------------------
>* file_backup_compressed: create a compressed backup (with date)
>* in the current dir
>*
>* usage: file_backup_compressed test.txt

# file_backup()
>* -------------------------------------------------------------------
>* file_backup: creating a backup of a file (with date)

# file_information()
>* -------------------------------------------------------------------
>* file_information: output information to a file

# dataurl()
>* -------------------------------------------------------------------
>* dataurl: create a data URL from a file

# create_server()
>* -------------------------------------------------------------------
>* server: Start an HTTP server from a directory, optionally specifying the port

# phpserver()
>* -------------------------------------------------------------------
>* phpserver: Start a PHP server from a directory, optionally specifying 2x $_ENV and ip:port
>* (Requires PHP 5.4.0+.)
>*
>* usage:
>* phpserver [port=auto] [ip=127.0.0.1] [FOO_1=BAR_1] [FOO_2=BAR_2]

# php()
>* php-parse-error-check: check for parse errors
>*
>* usage: php-parse-error-check /var/www/web3/

# psgrep()
>* -------------------------------------------------------------------
>* psgrep: grep a process

# cpuinfo()
>* -------------------------------------------------------------------
>* cpuinfo: get info about your cpu

# jsonc()
>* -------------------------------------------------------------------
>* json: Syntax-highlight JSON strings or files
>*
>* usage: json '{"foo":42}'` or `echo '{"foo":42}' | json

# escape()
>* -------------------------------------------------------------------
>* escape: Escape UTF-8 characters into their 3-byte format

# unidecode()
>* -------------------------------------------------------------------
>* unidecode: Decode \x{ABCD}-style Unicode escape sequences

# history_top_used()
>* -------------------------------------------------------------------
>* history_top_used: show your most used commands in your history

# getcertnames()
>* -------------------------------------------------------------------
>* getcertnames: Show all the names (CNs and SANs) listed in the
>*               SSL certificate for a given domain.
>*
>* usage: getcertnames moelleken.org

# t()
>* -------------------------------------------------------------------
>* tail with search highlight
>*
>* usage: t /var/log/Xorg.0.log [kHz]

# httpDebug()
>* -------------------------------------------------------------------
>* httpDebug: download a web page and show info on what took time
>*
>* usage: httpDebug http://github.com

# digga()
>* -------------------------------------------------------------------
>* digga: show dns-settings from a domain e.g. MX, IP
>*
>* usage: digga moelleken.org

# tre()
>* -------------------------------------------------------------------
>* `tre`: is a shorthand for `tree` with hidden files and color enabled, ignoring
>* the `.git` directory, listing directories first. The output gets piped into
>* `less` with options to preserve color and line numbers, unless the output is
>* small enough for one screen.

# pidenv()
>* -------------------------------------------------------------------
>* pidenv: show PID environment in human-readable form
>*
>* https://github.com/darkk/home/blob/master/bin/pidenv

# processenv()
>* -------------------------------------------------------------------
>* process: show process-name environment in human-readable form

# shorturl()
>* -------------------------------------------------------------------
>* shorturl: Create a short URL

# ppp()
>* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
>* Process phone photo.

# qh()
>* Search history.
>*           ┌─ enable colors for pipe
>*           │  ("--color=auto" enables colors only if
>*           │  the output is in the terminal)
>*grep --color=always "$*" "$HISTFILE" | less -RX
>* display ANSI color escape sequences in raw form ─┘│
>*       don't clear the screen after quitting less ─┘

# qt()
>* Search for text within the current directory.
>*grep -ir --color=always "$*" --exclude-dir=".git" --exclude-dir="node_modules" . | less -RX
>*     │└─ search all files under each directory, recursively
>*     └─ ignore case

# line()
>* Print a line of dashes or the given string across the entire screen.

# center()
>* Print the given text in the center of the screen.

# lman()
>* Open the man page for the previous command.

# xxgetmac()

# to_lower()
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Converts a string to lower case
>* Arguments:
>*   $1 -> String to convert to lower case

# die()
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Display an error message and die
>* Arguments:
>*   $1 -> Message
>*   $2 -> Exit status (optional)

# is_root()
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Return true if script is executed by the root user
>* Arguments: none
>* Return: True or False

# is_user_exits()
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*
>* Purpose: Return true $user exits in /etc/passwd
>* Arguments: $1 (username) -> Username to check in /etc/passwd
>* Return: True or False

# lastFileChange()
>* % date -d "@$(stat -c '%Y' a.out)"
>* Tue Jul 26 12:15:21 BDT 2016
>* date -r .bashrc Tue Aug  6 19:14:12 CEST 2019
>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*>*

# ps()
>* prints colored text
>* print_style "This is a green text " "success";
>* print_style "This is a yellow text " "warning";
>* print_style "This is a light blue with a \t tab " "info";
>* print_style "This is a red text with a \n new line " "danger";
>* print_style "This has no color";

# telegrafAfterUpdate()
>*what to do after telegraf update

# yaml_r()
>*https://coderwall.com/p/xatm5a/bash-one-liner-to-read-yaml-files

# perlver()
>*info about perl

# timeInfo()
>*all about the time

# _cheat_autocomplete()
>*_cheat_autocomplete

# h()
>*search in aliases, functions and cheats for the string

# cheatsh()
>*wrapper for cheat.sh
>*cheatsh tar~list

# alias_completion()
>* Automatically add completion for all aliases to commands having completion functions
>* source: http://superuser.com/questions/436314/how-can-i-get-bash-to-perform-tab-completion-for-my-aliases

# getlocation()
>*Get your public IP address and host.

# err()
>* -------------------------------------------------------------------
>* err: error message along with a status information
>*
>* example:
>*
>* if ! do_something; then
>*   err "Unable to do_something"
>*   exit "${E_DID_NOTHING}"
>* fi
>*

# yt2mp3()
>*youtube-dl

# mail_test_ssl_server_imap()
>*mail tester imap

# mail_test_ssl_server_pop3()
>*mail tester pop3

# mail_test_ssl_server_SMTP()
>*mail tester ssl

# mail_test_ssl_server_SMTP_star()
>*mail tester imap

# get_remote_file()
>*Funktion um Dateien aus dem Internet zu laden. Prüft ob curl vorhanden ist , wenn nicht wird wget versucht. Wenn gar nichts von beiden gefunden wird wird das Skript beendet.
>*https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
>* download an file to local storage
>* need 2 parameters : get_remote_file [URL_TO_FILE] [LOCAL_PATH]

# check_files_in_zip()
>* Problem : Man möchte über Bash nur den Inhalt einer Zip Datei vergleichen. Die Zip Datei wird aber automatisiert auf einem Server über cron erstellt, was zur Folge hatte das der Zeitstempel und somit auch die md5 Summen unterschiedlich sind.
>* Lösung : Die Lösung ist mit unzip in die Datei zu schauen und diesen Output mit diff zu verleichen.
>* https://hope-this-helps.de/serendipity/categories/Bash-68/P3.html
>* compare the content of two zipfiles if equal the function return 0 otherwise 1
>* need 2 parameters : check_files_in_zip [NAME_OF_OLD_ZIPFILE] [NAME_OF_NEW_ZIPFILE]

# geo()
>*geo-ip 144.178.0.0

# sftp_keyfile()
>* "Usage: sftp_keyfile 'keyfile' port user host"
>* "sftp_keyfile PATH/TO/PUBLICKEYFILE(id_rsa) 10022 user host"

# Export_image_file_statistics_to_csv()
>*"Usage: Export_image_file_statistics_to_csv 'output.csv' "

# Export_image_file_statistics_to_csv_tabs()
>*"Usage:Tabs Export_image_file_statistics_to_csv_tabs 'output.csv' "

# convert_cr2_to_jpg()
>*convert raw to jpg

# ssh_copy_to_host()
>*Copy something from this system to some other system:
>*echo scp /path/to/local/file username@hostname:/path/to/remote/file  

# ssh_copy_from_host_to_host()
>*Copy something from some system to some other system:
>*scp username1@hostname1:/path/to/file username2@hostname2:/path/to/other/file 	

# ssh_copy_fron_host()
>*Copy something from another system to this system:
>*scp username@hostname:/path/to/remote/file /path/to/local/file  

# convert_CR2_to_JPG_dcraw()
>*dcraw -c RAW-Dateiname | convert - Ausgabedatei.FORMAT  

# checkSSLfromDomain()
>*curl -i -k -X GET -u root:rootpw "https://knaak.org:8443/api/v2/domains" -H  "accept: application/json"

# random_32chars_al()
>* bash generate random alphanumeric string
>* bash generate random 32 character alphanumeric string (upper and lowercase) and 

# random_32chars_lc()
>* bash generate random 32 character alphanumeric string (lowercase only)

# random_number09()
>* Random numbers in a range, more randomly distributed than $RANDOM which is not
>* very random in terms of distribution of numbers.
>* bash generate random number between 0 and 9

# random_number099()
>* bash generate random number between 0 and 99

# random_number999()
>* bash generate random number between 0 and 999

# syncFileToS3()
>*"Usage: syncFileToS3 'file' "

# bool()
>* Print boolean value of the exit code of the command passed as argument.

# split_path_dirs()
>* Split directories in a PATH-like variable.

# contains_string()
>* Return whether a string is present in a list of strings.

# is_interactive()
>* Return whether the shell is interactive.

# sf()
>* Source a system file.  If no filename is given, list the available names.

# gitHelpNew()
>*git help

# dtags()

# vdiff()
>*file diff
>* "  comparing dirs:  vdiff dir_a dir_b"
>* "  comparing files: vdiff file_a file_b"

# raw2jpg_embedded()
>*extract embedded jpg from raw with ufraw

# raw2jpg_convert()
>* "Usage: raw2jpg_convert 'ARW|CR2' "

# raw2jpg_parallel()
>*convert raw parallel

# raw2jpg_ext()
>* "Usage: raw2jpg_ext 'ARW|CR2' 'outout Folder' "

# checkURLs()
>*checkt ob angegebene files auf server vorhanden sind

# package_exists()
>*epackage_exists

# imgResize()
>*"Usage: imgResize '75' '91' "
>*"Usage: imgResize [sizeReduct][quality] "

# getSSL()

# iptable_block_bad_countrys()
>*block all ip from country on all ports

# iptable_ban_country()
>*block all ip from country on all ports

# iptable_unban_country()
>*unblock all ip from country on all ports

# iptable_ban_ip()
>*block  ip on all ports

# iptable_unban_ip()
>*unblock  ip on all ports

# iptable_check_ip()
>*is ip blocked

# iptable_block_subnet()
>*is subnet blocked

# iptable_view_blocked()
>*see all blocked IPs

# diff_git_file()
>*diff compare local file with repo file

# installer()

