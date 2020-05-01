#!/bin/bash

loki_linux-amd64()
{
    #LOKI_ZIP="/usr/local/bin/loki-linux-amd64.zip"
    wget "https://github.com/grafana/loki/releases/download/v1.4.1/promtail-linux-amd64.zip"
    

    unzip "promtail-linux-amd64.zip"
    mv "promtail-linux-amd64" "/usr/local/bin/promtail" 
    rm "promtail-linux-amd64.zip"    
    chmod a+x "/usr/local/bin/promtail"    
    mkdir -p /data/loki
    mkdir -p /etc/loki

    PT_CONF_FILE="/etc/loki/config-promtail.yml"

cat > $PT_CONF_FILE <<EOF

server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://127.0.0.1:3100/loki/api/v1/push

scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      path: /var/log/journal
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'


EOF

echo "wrote promtail config cat $PT_CONF_FILE"
echo "try sudo promtail -config.file /etc/loki/config-promtail.yml"

SERVICE_FILE="/etc/systemd/system/promtail.service"

cat > $SERVICE_FILE <<EOF

[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file /etc/loki/config-promtail.yml

[Install]
WantedBy=multi-user.target

EOF

echo "close firewall"
echo "
iptables -A INPUT -p tcp -s localhost --dport 9080 -j ACCEPT
iptables -A INPUT -p tcp --dport 9080 -j DROP
iptables -L

#activate journal 
joe /etc/systemd/journald.conf
mkdir /var/log/journal
systemctl force-reload systemd-journald
systemctl restart systemd-journald

echo "wrote loki service cat $SERVICE_FILE"
echo "run"
echo "sudo service promtail start"
echo "sudo service promtail status"

"




}    

loki_linux-amd64