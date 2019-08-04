#systmctl service template (nextcloud)
# 5min Timer

#nano /etc/systemd/system/nextcloudcron.service
#####################################################

[Unit]
Description=Nextcloud cron.php job

[Service]
User=knaak
ExecStart=/opt/plesk/php/7.3/bin/php -f /var/www/vhosts/knaak.org/cloud.knaak.org/cron.php

[Install]
WantedBy=basic.target

########################################################

#nano /etc/systemd/system/nextcloudcron.timer

#########################################################
[Unit]
Description=Run Nextcloud cron.php every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=nextcloudcron.service

[Install]
WantedBy=timers.target

#########################################################

# systemctl enable --now nextcloudcron.timer