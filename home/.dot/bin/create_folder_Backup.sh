#!/bin/bash
#
#
# Sichert den eingestellten Ordner
#
# -- Variablen
#
# Ordner und Zieldatei
#
Ordner=/opt/lampp/htdocs
Target=/share/backup/webserver
tmp_temp=/opt/lampp/htdocs/xtc/templates_c/*.php
tmp_cach=/opt/lampp/htdocs/xtc/cache/*.html
Error=/share/log/`date +%Y_%0m_%0e`_Error_WebSRV.log
Ablauf=/share/log/`date +%Y_%0m_%0e`_Ablauf_WebSRV.log
# Stufe der Komprimierung (0-9)
Compression=9
#
# Name der Backup Datei
#
NameZIP=`date +%Y_%0m_%0e`_WEBSRV
#
# Startzeit ermitteln
#
StrTime=`date +%R`
#
#
# wenn kein Logfile mitgeschrieben werden soll
# umleiten in //dev/null
#
echo Backup wird gestartet $StrTime
echo LAMPP wird beendet
 
/opt/lampp/lampp stop >>$Ablauf 2>>$Error
 
echo Daten werden gesammelt und gezippt
zip -r -$Compression $Target/$NameZIP.zip $Ordner >>//dev/null 2>>$Error
 
echo temp Dateien werden entfernt
echo
rm $tmp_temp >>$Ablauf 2>>$Error
rm $tmp_cach >>$Ablauf 2>>$Error
 
echo LAMPP wird gestartet
/opt/lampp/lampp start >>$Ablauf 2>>$Error
 
echo Rechte auf Backupdatei werden geaendert
chmod 777 $Target/$NameZIP.zip
 
echo Backup abgeschlossen