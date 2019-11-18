add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

apt-get update

apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

apt-get install -y docker-ce docker-ce-cli containerd.io

docker run -d --restart=unless-stopped \
  -e PUID=1000 \
  -e PGID=1000 \
  -e MYSQL_ROOT_PASSWORD=mysql-root-password-1 \
  -e TZ=Europe/Moscow \
  -e MYSQL_DATABASE=bookstackapp \
  -e MYSQL_USER=bookstack \
  -e MYSQL_PASSWORD=db-stack-root-password \
  --name=db \
  -p 3306:3306 \
  linuxserver/mariadb

docker run -d \
  --net="host" \
  --pid="host" \
  --restart=unless-stopped \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host

docker volume create consul_config

docker run -d \
  --restart=unless-stopped \
  --name=consul \
  --net=host \
  --hostname=db \
  -v consul_config:/consul/config \
  -e CONSUL_BIND_INTERFACE=eth0 \
  consul:1.6.1

docker run -d \
  --name fabio \
  --net=host \
  --restart=unless-stopped \
  fabiolb/fabio \
  -proxy.addr ':80;proto=tcp' -registry.consul.addr 127.0.0.1:8500
