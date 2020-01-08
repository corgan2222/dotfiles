# scriptinfo
>* ------------------------------------------------------------------------------
>* | Defaults                                                                   |
>* ------------------------------------------------------------------------------

# c

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

# logsWWW

# zabbix_server_reload

# sudo
>* Enable simple aliases to be sudo'ed. ("sudone"?)

# joe

# vi

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

# dd

# d

# da

# dt

# dd

# userls

# path
>* Print each PATH entry on a separate line

# cd_Aptlist

# cd_git

# cd_Scripts

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

# listLoadedPhpInis7

# listLoadedPhpInis73

# phplint

# dl

# dr

# dockerContainerSize

# gitp
>* ------------------------------------------------------------------------------
>* | git                                                                        |
>* ------------------------------------------------------------------------------

# gitsub

# gitsubadd

# gitsubget

# gitadd

# gc

# prettyGitLog

# prettyGitLog_clean
>* git config --global alias.lg "log --color --graph --pretty=format:'%C(>*dc322f)%h%C(>*b58900)%d %C(>*eee8d5)%s %C(>*dc322f)| %C(>*586f75)%cr %C(>*dc322f)| %C(>*586e75)%an%Creset' --abbrev-commit"

# createGitChangelog

# map

# makescript

# wget
>* ------------------------------------------------------------------------------
>* | Network                                                                    |
>* ------------------------------------------------------------------------------

# checkport

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
>*also pass it via sudo so whoever is admin can reload it without calling yo

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

# ps

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

# sulast
>* becoming root + executing last command

# mountc

# mountMedien

# devList

# helpMount

# dec2hex
>* decimal to hexadecimal value

# urldecode
>* urldecode - url http network decode

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

# backup
>* if cron fails or if you want backup on demand just run these commands >*
>* again pass it via sudo so whoever is in admin group can start the job >*
>* Backup scripts >*

# nasbackup

# s3backup

# rsnapshothourly

# rsnapshotdaily

# rsnapshotweekly

# rsnapshotmonthly

# amazonbackup

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

# debianSynoStart

# grafanaListDashboards

# grafanaImportDashbaord

# convert_CR2_to_JPG

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

# dc
>* docker compose (assumes current directory contains the docker-compose.yml)

# dc_up
>* start socker stack defined by docker-compose.yml

# dc_down
>* stop docker stack defined by docker-compose.yml

# dc_rebuild
>* rebuild docker stack

# dc_logs
>* watch logs in docker stack

# vncServerStop

# vncServerStart

# vncServerStatus

# vncServerPW

# install_zerotiert

# ListShellandEnvironmentVariables

# fx

# how

