

systemctl stop zabbix-server

echo "Create Folders"
mkdir -p /mnt/backup_s4/bin_files /mnt/backup_s4/conf_files /mnt/backup_s4/doc_files
mkdir -p /mnt/backup_s4/web_files /mnt/backup_s4/db_files /mnt/backup_s4/etc_zabbix

echo "copy conf"
cp -rp /etc/zabbix/zabbix_server.conf /mnt/backup_s4/conf_files

echo "copy conf"
cp -rp /etc/zabbix /mnt/backup_s4/etc_zabbix


echo "copy bin"
cp -rp /usr/sbin/zabbix_server /mnt/backup_s4/bin_files

echo "copy docs"
cp -rp /usr/share/doc/zabbix-* /mnt/backup_s4/doc_files

echo "copy http"
cp -rp /etc/httpd/conf.d/zabbix.conf /mnt/backup_s4/conf_files 2>/dev/null

echo "copy apache"
cp -rp /etc/apache2/conf-enabled/zabbix.conf /mnt/backup_s4/conf_files 2>/dev/null

echo "copy php"
cp -rp /etc/zabbix/php-fpm.conf /mnt/backup_s4/conf_files 2>/dev/null

echo "copy web"
cp -rp /usr/share/zabbix/ /mnt/backup_s4/web_files

echo "backup db"
mysqldump --single-transaction 'zabbix' | gzip > /mnt/backup_s4/db_files/zabbix_backup.sql.gz