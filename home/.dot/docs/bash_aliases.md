# scriptinfo
>* ------------------------------------------------------------------------------
>* | Defaults                                                                   |
>* ------------------------------------------------------------------------------

# c
>* short names only where no program of that name exists: an alias hides the program in the shell

# cl

# a

# f

# s

# l

# keyboardDE

# reload
>* reload the shell (i.e. invoke as a login shell)

# load
>*alias load='source ~/.bashrc && source ~/.dot/.bash_aliases && source ~/.dot/.bash_functions.sh'

# logs_multi_all

# logs_lnav_all

# logsTelegraf

# logsGrafana

# logsInflux

# logsApache

# logsMysql

# logsMongodb

# logsNeo4j

# logsNginx

# logsPlesk

# zabbix_server_reload

# sudo
>* Enable simple aliases to be sudo'ed. ("sudone"?)

# joe

# vi
>* vi -> joe only with joe installed

# hmm

# mkdir

# md

# rmd

# rd

# mkdd
>* create a dir with date from today

# linuxversion

# tarx

# e

# editAlias

# editFunctions

# editBash

# cf

# nodels

# py3

# py

# p3

# p

# cx

# bd

# cd
>* fallback by typo

# cd

# cd

# cd

# cdHomeshick

# ll

# la

# dir

# d

# da

# lsdir
>* list only directories (named lsdir, an alias dd would hide the dd command)

# d

# da

# dt

# lsdir

# user

# groups

# path
>* Print each PATH entry on a separate line

# cd_Aptlist

# cd_git

# cd_Scripts

# ssdn

# ssrn

# sgrep
>* super-grep ;)

# ack

# afind

# afind

# findLastFile

# list_services

# list_services_startup

# list_services_all

# list_services_tree

# list_services_locate

# list_PortsLocalhostNmap

# list_PortsLocalhostLsof

# check_servic_isActive

# check_servic_isActive_onBoot

# disable_mask_service

# disable_service

# enable_service

# ap

# apr

# apAutoremove

# apNoUpdate

# apPurge

# apRemovePurge

# apClean

# apSource

# apSourceCompile

# apDownload

# apChangelog

# apBuildDep

# apCheck

# apAutoclean

# apSearch

# apuu

# aptGetVersion

# aptList

# aptReconf

# aptListAll_names

# aptListAll_Path

# aptListSources
>*alias aptChangelog="xargs -I% -- zless /usr/share/doc/%/changelog.Debian.gz <<<"

# aptChangelog

# aptListSourcesList

# aptEditSourcesList

# aptListSourcesD

# aptSourcesSize

# aptgetAppInfos_fromthis

# listLoadedPhpInis7

# phplint

# gitp
>* ------------------------------------------------------------------------------
>* | git                                                                        |
>* ------------------------------------------------------------------------------
>* pushes the current branch

# gitsub

# gitsubadd

# gitsubget

# gitadd
>* only tracked files, like saveHome

# gc
>* only where graphviz's gc is not installed

# prettyGitLog

# prettyGitLog_clean
>* git config --global alias.lg "log --color --graph --pretty=format:'%C(>*dc322f)%h%C(>*b58900)%d %C(>*eee8d5)%s %C(>*dc322f)| %C(>*586f75)%cr %C(>*dc322f)| %C(>*586e75)%an%Creset' --abbrev-commit"

# map

# makescript

# checkport_lsof
>* ------------------------------------------------------------------------------
>* | Network                                                                    |
>* ------------------------------------------------------------------------------

# ports

# portsu

# myip_dns
>* external ip address

# myip_http

# ping

# fastping
>* Do not wait interval 1 second, go fast >*

# gurl
>* Gzip-enabled `curl`

# lsport
>* displays the ports that use the applications

# listen

# llport
>* shows more about the ports on which the applications use

# netlisteners
>* show only active network listeners

# nginxreload

# nginxtest

# lightyload

# lightytest

# httpdreload

# httpdtest

# interfaces_IP

# interfaces_IP2

# routesIP
>*alias interfaces_IP3="ifconfig | awk -v RS=\"\n\n\" '{ for (i=1; i<=NF; i++) if ($i == \"inet\" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != \"127.0.0.1\") printf \"%s\t%s\n\", $1, address }'"

# metricsIP

# date_iso_8601
>* date

# date_clean

# date_year

# date_month

# date_week

# date_day

# date_hour

# date_minute

# date_second

# date_time

# setTimeZone

# timer
>* stopwatch

# meminfo
>* pass options to free

# psg
>* find the PID of any process: psg [name] (named psg, an alias ps broke every later ps call)

# psmem
>* get top process eating memory

# psmem5

# psmem10

# pscpu
>* get top process eating cpu

# pscpu5

# pscpu10

# psx
>* shows the corresponding process to ...

# cpuinfo
>* older system use /proc/cpuinfo >*>*

# cpuinfo

# gpumeminfo
>*>* get GPU ram on desktop / laptop>*>*

# psKillAll
>*kill all process with name

# pst
>* shows the process structure to clearly

# psmy
>* shows all your processes

# loadavg
>* the load-avg

# partitions
>* show all partitions

# du
>* shows the disk usage of a directory legibly

# du5

# du10

# du_overview
>* show the biggest files in a folder first

# df
>* shows the complete disk usage to legibly

# renameImagaExif

# mountc

# devList

# helpMount

# dec2hex
>* decimal to hexadecimal value: dec2hex 255

# urldecode
>* urldecode - url http network decode: urldecode 'a%20b'

# rot13
>* ROT13-encode text. Works for decoding, too! ;)

# map
>* intuitive map function
>*
>* For example, to list all directories that contain a certain file:
>* find . -name .gitattributes | map dirname

# yamlcheck
>*>*>*>* Validators

# jsoncheck

# xmlcheck

# ascii_
>*>*>*>* Characters

# alphabet_

# unicode_

# numalphabet_

# regxmac
>*>*>*>* Regular Expressions

# regxip

# regxemail

# histg

# tree
>* displays a directory tree

>* displays a directory tree - paginated
# ltree

# tree

# ltree

# starwars
>*alias nyancat="telnet miku.acm.uiuc.edu"  >* offline

# colour

# as

# configure

# diff

# dig

# g

# gas

# gcc

# head

# ifconfig

# ld

# ls

# make

# mount

# netstat

# ping

# ps

# tail

# traceroute

# syslog

# pretty

# mcdstats
>*>* Memcached server status  >*>*

# mcdshow

# flushmcd
>*>* quickly flush out memcached server >*>*

# apacheModsAvailable

# apacheModsEnabled

# restartApachePhp

# restartPhp73fpm

# ls

# grep

# fgrep

# egrep

# colour

# as

# configure

# diff

# dig

# g

# gas

# gcc

# head

# ifconfig

# ld

# ls

# make

# mount

# netstat

# ping

# ps

# tail

# traceroute

# syslog

# difflight

# difflight

# difflight

# grafanaListDashboards

# grafanaImportDashbaord

# convert_CR2_to_JPG

# dl
>* list running containers

# dr
>* restart docker

# dockerContainerSize
>* list ContainerSize

# docker_prune_system
>* prunes docker

# docker_prune_system_withVolumes
>* prunes docker with volumes

# docker_list_images
>* list all images

# docker_process_list
>* list running containers (image instances)

# docker_kill_all_contailer
>* kill all running container processes:

# docker_rm_all_container
>* remove all containers

# docker_rm_all_images
>* remove all docker images

# docker_list_volumes
>* list all volumes

# docker_list_orphaned_volumes
>* list all orphaned volumes

# docker_rm_all_volumes
>* remove all docker volumes 

# docker_rm_all_orphaned_volumes
>* remove all orphaned docker volumes 

# docker_net_info
>*show all container with internal IP 

# dc
>* docker compose (assumes current directory contains the docker-compose.yml)
>* only where the desk calculator dc is not installed

# dcupd
>* start docker stack defined by docker-compose.yml as deamon

# dcup
>* start docker stack defined by docker-compose.yml

# dcdn
>* stop docker stack defined by docker-compose.yml

# dcb
>* rebuild docker stack

# dcl
>* watch logs in docker stack

# dcp
>* watch logs in docker stack

# vncServerStop

# vncServerStart

# vncServerStatus

# vncServerPW

# ListShellandEnvironmentVariables

# fx

# how
>* function: howdoi "$@" -c -n 5 (pip install howdoi)

# wifi_ls_controller
>*wifi

# wifi_show_infos

# wifi_show_quality

# wifi_show_quality2

# wifi_show_quality_continuosly

# wifi_show_quality_continuosly_wavemon

# journal_show_errors
>*journalctl 

# journal_show_thisunit

# journal_show_live_from

# journal_show_live

# logrotateTest
>*logrotate

# logrotateTestThis

# logrotateDoThis

# fail2ban

# fail2ban

# fail2ban

# fail2ban

# fail2ban

# fail2ban

# graylistCheck

# graylistServerinfo

# checkIP

# restartXserver

# ffmpegs
>*silent

# ffm_muxerInfo
>*Display options specific to, and information about, a particular muxer:

# ffm_demuxerInfo
>*Display options specific to, and information about, a particular demuxer:

# ffm_listFormats
>*List all formats:

# ffm_listCodecs
>*List all codecs:

# ffm_listCodecsH264

# ffm_listCodecsH265

# ffm_listEncoders
>*List all encoders:

# ffm_listDecoders
>*List all decoders:

# ffm_DetailsEncoderThis
>*Display options specific to, and information about, a particular encoder:

# ffm_DetailsDecoderThis
>*Display options specific to, and information about, a particular decoder:

# list_functions
>* function: lists the functions with line and file, without the internal _ ones

# topFiles
>*top for files

# gethw
>* Quick and dirty hardware summary where lshw is not available. Requires util-linux, procps, pciutils, usbutils and net-tools, which should be preinstalled on most systems. 

# py_createVirt
>*python

# pi

# pf

# pir
>* pip install -r requirements.txt (pr is the coreutils pager)

# nmap_open_ports
>*nmap
>*scan for open ports on target.

# nmap_list_interfaces
>* list all network interfaces on host where the command runs.

# nmap_slow
>*slow scan that avoids to spam the targets logs.

# nmap_scanIP
>* scan to see if hosts are up with TCP FIN scan.

# nmap_full
>*aggressive full scan that scans all ports, tries to determine OS and service versions.

# nmap_check_for_firewall
>*TCP ACK scan to check for firewall existence.

# nmap_ping_through_firewall
>*host discovery with SYN and ACK probes instead of just pings to avoid firewall restrictions.

# nmap_fast
>*fast scan of the top 300 popular ports.

# nmap_detect_versions
>*detects versions of services and OS, runs on all ports.

# nmap_check_for_vulns
>*uses vulscan script to check target services for vulnerabilities.

# nmap_full_udp
>*same as full but via UDP

# nmap_traceroute
>*try to traceroute using the most common ports.

# nmap_full_with_scripts
>*same as nmap_full but also runs all the scripts.

# nmap_web_safe_osscan
>*ittle "safer" scan for OS version as connecting to only HTTP and HTTPS ports doesn't look so attacking.

# nmap_ping_scan
>*ICMP scan for active hosts

# nmap_scanIP_os
>*OS-Scan

# nmap_scanIP_osService
>*OS & Service Scan

# nmap_scanNetwork
>* find all active IP addresses in a network

# scanNetwork_arp
>*Host-Discovery mit ARP

# scanNetwork_arpScan
>*Host-Discovery mit ARP-scan

