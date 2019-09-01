#!/bin/bash
#
#
# Sichert den eingestellten Ordner
#
# -- Variablen
#
# Ordner und Zieldatei
#

 if [ -z "${1}" ]; then
    echo "Usage: \`create_folder_Backup folder-to-backup backupname\`"
    return 1
  fi

   if [ -z "${2}" ]; then
    echo "Usage: \`create_folder_Backup folder-to-backup backupname\`"
    return 1
  fi

Ordner=$1
BackupName=$2
#Target=$BACKUP_DIR_LOCAL_TODAY
Target="/data/backups_all/$BackupName"
mkdir $Target

   if [ ! -d "$Ordner" ]; then
    echo "Folder: $1 doesnt exist"
    return 1
   fi

NAME="$BackupName"_`date +%Y_%m_%d_%H_%M_%S`

tmp_temp="/tmp/$NAME"
mkdir "$tmp_temp"

Error=/var/log/my_backup/"$NAME"_Error.log
Ablauf=/var/log/my_backup/"$NAME"_log.log
# Stufe der Komprimierung (0-9)
Compression=9
#
# Name der Backup Datei
#
#
# Startzeit ermitteln
#
StrTime=`date +%R`
#
# wenn kein Logfile mitgeschrieben werden soll
# umleiten in //dev/null
#
echo Backup wird gestartet $StrTime

#/opt/lampp/lampp stop >>$Ablauf 2>>$Error
 
echo Daten werden gesammelt und gezippt
zip -r -$Compression $Target/$NAME.zip $Ordner | pv 2>>$Error
#zip -qr -$Compression $Target/$NAME.zip $Ordner | pv -s $(du -bs $Ordner | awk '{print $1}')
#zip -rdb -$Compression $Ordner | (pv -p --timer --rate --bytes > $Target/$NAME.zip)
#pv $Ordner | zip -r > $Target/$NAME.zip
 
echo temp Dateien werden entfernt
echo
rm -R $tmp_temp -f >>$Ablauf 2>>$Error
 
echo Rechte auf Backupdatei werden geaendert
chmod 777 $Target/$NAME.zip
 
echo Backup abgeschlossen - $Target/$NAME.zip
ls -la $Target/