#https://sbcode.net/grafana/install-promtail-service/

sudo cd /usr/local/bin
sudo curl -fSL -o promtail.gz "https://github.com/grafana/loki/releases/download/v1.6.1/promtail-linux-amd64.zip"
sudo gunzip promtail.gz
sudo chmod a+x promtail
sudo mkdir /etc/promtail
sudo cd /etc/promtail
# wget https://gist.githubusercontent.com/Sean-Bradley/fff3c40241b133666d122775bea30845/raw/8d6e04a56d5d47fa4203186e5bc9b936b09167e5/config-promtail.yml
# joe /etc/promtail/config-promtail.yml

cat << EOF >> /etc/promtail/config-promtail.yml

server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.2.254:3100/loki/api/v1/push

scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
EOF



sudo useradd --system promtail
sudo usermod -a -G systemd-journal promtail

cat << EOF >> joe /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=promtail
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail/config-promtail.yml --client.external-labels=hostname=$(hostname)

[Install]
WantedBy=multi-user.target
EOF

echo "joe /etc/promtail/config-promtail.yml"
echo "try"
echo "sudo ./promtail -config.file /etc/promtail/config-promtail.yml --client.external-labels=hostname=$(hostname)"
echo "sudo systemctl enable promtail.service"
echo "sudo service promtail start"
