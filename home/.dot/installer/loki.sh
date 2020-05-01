#!/bin/bash

loki_linux-amd64()
{
    #LOKI_ZIP="/usr/local/bin/loki-linux-amd64.zip"
    wget "https://github.com/grafana/loki/releases/download/v1.4.1/loki-linux-amd64.zip"
    unzip "loki-linux-amd64.zip"
    mv "loki-linux-amd64" "/usr/local/bin/loki" 
    rm "loki-linux-amd64.zip"    
    chmod a+x "/usr/local/bin/loki"    
    mkdir -p /data/loki
    mkdir -p /etc/loki

    LOKI_CONF_FILE="/etc/loki/config-loki.yml"

cat > $LOKI_CONF_FILE <<EOF

auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
  - from: 2018-04-15
    store: boltdb
    object_store: filesystem
    schema: v9
    index:
      prefix: index_
      period: 168h

storage_config:
  boltdb:
    directory: /data/loki/index

  filesystem:
    directory: /data/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0

table_manager:
  chunk_tables_provisioning:
    inactive_read_throughput: 0
    inactive_write_throughput: 0
    provisioned_read_throughput: 0
    provisioned_write_throughput: 0
  index_tables_provisioning:
    inactive_read_throughput: 0
    inactive_write_throughput: 0
    provisioned_read_throughput: 0
    provisioned_write_throughput: 0
  retention_deletes_enabled: false
  retention_period: 0    

EOF

echo "wrote loki config $LOKI_CONF_FILE"

LOKI_SERVICE_FILE="/etc/systemd/system/loki.service"

cat > $LOKI_SERVICE_FILE <<EOF

[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/loki -config.file /etc/loki/config-loki.yml

[Install]
WantedBy=multi-user.target

EOF

echo "wrote loki service $LOKI_SERVICE_FILE"
echo "run"
echo "sudo service loki start"
echo "sudo service loki status"


echo "close firewall"
echo "
iptables -A INPUT -p tcp -s localhost --dport 3100 -j ACCEPT
iptables -A INPUT -p tcp --dport 3100 -j DROP
iptables -L
"




}    

loki_linux-amd64