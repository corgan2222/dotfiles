#!/bin/bash
 
# Allgemeine Variablen fr Logfiles
datum=`date +%Y_%0m_%0e`
 
ablauf_log="/share/log/ablauf-$datum.log"
error_log="/share/log/error-$datum.log"
 
# Maximales alter des Backupfiles in Tagen
alter="21"
 
echo Bereinigen wird gestartet $datum >>$ablauf_log
echo Bereinigen wird gestartet
echo ------------------------------------------------ >>$ablauf_log
echo ------------------------------------------------
 
# ---------------------------------- GESAMT BACKUP ROUTINE
ordner="/share/backup/sbs"
echo Variablen
echo Ordner wird auf $ordner gesetzt
echo Alter wird auf $alter gesetzt
echo
echo ------- $ordner -- Komplettsicherung aelter als $alter Tage >>$ablauf_log
echo Dateien in $ordner werden auf Alter ueberprueft  - max. $alter Tage
 
find $ordner -mtime +$alter -exec echo {} \;
find $ordner -mtime +$alter -exec rm {} \;
 
echo ------------------------------------------------
 
# ---------------------------------- WEBSERVER BACKUP ROUTINE
alter="15" # fuer webserve und lexware nur 15 Tage
ordner="/share/backup/webserver"
 
echo Neu setzen der Variablen
echo Ordner wird auf $ordner gesetzt
echo Alter wird auf $alter gesetzt
echo
 
echo ------- $ordner -- Webserversicherung aelter als $alter Tage >>$ablauf_log
echo Dateien in $ordner werden auf Alter ueberprueft  - max. $alter Tage
 
find $ordner -mtime +$alter -exec echo {} \;
find $ordner -mtime +$alter -exec rm {} \;
 
echo ------------------------------------------------
 
# ---------------------------------- LEXWARE BACKUP ROUTINE
# - Alter ist bereits definiert
# ---------------------------------------------------------
ordner="/share/backup/lexware"
 
echo Neu setzen der Variablen
echo Ordner wird auf $ordner gesetzt
echo Alter wird auf $alter gesetzt
echo
 
echo ------- $ordner -- Lexwaresicherung aelter als $alter Tage >>$ablauf_log
echo Dateien in $ordner werden auf Alter ueberprueft  - max. $alter Tage
 
find $ordner -mtime +$alter -exec echo {} \;
find $ordner -mtime +$alter -exec rm {} \;
 
echo ------------------------------------------------
echo
echo ------------------------------------------------ >>$ablauf_log
echo Vorgang abgeschlossen >>$ablauf_log