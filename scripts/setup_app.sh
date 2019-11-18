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

docker run -d --restart=always --name guestbookapp \
-e MYSQL_SERVER_ADDRESS=db.node.consul \
-e MYSQL_USER=guestbookapp \
-e MYSQL_PASSWORD=secret-for-guest-book-user \
-e MYSQL_DATABASE=guestbookapp \
-e APP_ADDRESS=127.0.0.1 \
--net=host \
--dns=127.0.0.1 \
f3ex/guestbookapp:latest

docker run -d \
  --net="host" \
  --pid="host" \
  --restart=unless-stopped \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host
