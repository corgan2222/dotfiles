docker run -p 32768:9000 --name minio1 \
  -e "MINIO_ACCESS_KEY=S3PcTMXa4AmB4QUG" \
  -e "MINIO_SECRET_KEY=tfVPF9zvqoJURDWv48Kd" \
  -v /data/tl:/data \
  minio/minio server /data 