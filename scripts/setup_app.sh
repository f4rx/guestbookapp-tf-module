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

mkdir -p /opt/docker_apps/bookstack

docker run -d --restart=always --name bookstack \
  -v /opt/docker_apps/bookstack/:/config/ \
  -e DB_HOST=db.node.consul \
  -e DB_USER=bookstack \
  -e DB_PASS=db-stack-root-password \
  -e DB_DATABASE=bookstackapp \
  --net=host \
  --dns=127.0.0.1 \
  linuxserver/bookstack

docker run -d \
  --net="host" \
  --pid="host" \
  --restart=unless-stopped \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host

# docker volume create consul_config

# docker run -d \
#     --restart=unless-stopped \
#     --name=consul \
#     --net=host \
#     --hostname=db \
#     -v consul_config:/consul/config \
#     -e CONSUL_BIND_INTERFACE=eth0 \
#     consul
