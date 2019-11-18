###################################
# Create port
###################################
resource "openstack_networking_port_v2" "port_app" {
  count = "${var.app_count}"
  name       = "node-app-${count.index + 1}"
  network_id =  "${openstack_networking_network_v2.network_1.id}"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
  }
}

###################################
# Create Volume/Disk
###################################
resource "openstack_blockstorage_volume_v3" "volume_app" {
  count                 = "${var.app_count}"
  name                  = "volume-for-app-${count.index + 1}"
  size                 = "${var.hdd_size}"
  image_id             = "${data.openstack_images_image_v2.ubuntu.id}"
  volume_type          = "${var.volume_type}"
  availability_zone    = "${var.az_zone}"
  enable_online_resize = true

  lifecycle {
    ignore_changes = ["image_id"]
  }
}
###################################
# Create Server
###################################
resource "openstack_compute_instance_v2" "instance_app" {
  count             = "${var.app_count}"
  name              = "app-${count.index + 1}"
  flavor_id         = "${data.openstack_compute_flavor_v2.flavor_1.id}"
  key_pair          = "${openstack_compute_keypair_v2.terraform_key.id}"
  availability_zone = "${var.az_zone}"

  network {
    port = "${openstack_networking_port_v2.port_app[count.index].id}"
  }

  block_device {
    uuid             = "${openstack_blockstorage_volume_v3.volume_app[count.index].id}"
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = 0
  }

  vendor_options {
    ignore_resize_confirmation = true
  }

  metadata = {
    consul = "server"
  }

  provisioner "file" {
    content = <<-EOT
    cat > /root/consul_app.json << EOF
{
  "service": {
    "id": "app-${count.index}",
    "name": "app-${count.index}",
    "port": 80,
    "tags": ["urlprefix-:80"],
    "checks": [{
      "id": "check-app-123",
      "http": "http://127.0.0.1",
      "interval": "15s"
    }]
  }
}
EOF

      docker run -d  --net=host --name consul \
      -e CONSUL_BIND_INTERFACE=eth0 \
      -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' \
      -v  /root/consul_app.json:/app.json \
      consul:1.6 \
      agent  -config-file /app.json \
      -dns-port=53 \
      -recursor=8.8.8.8 \
      -retry-join "provider=os tag_key=consul tag_value=server auth_url=https://api.selvpc.ru/identity/v3 password=${var.user_password} user_name=${var.user_name} project_id=${var.project_id}  domain_name=${var.domain_name} region=${var.region}"
      # '"
      sleep 5
      docker restart bookstack

      docker exec -ti consul consul services register -tag "urlprefix-:80 proto=tcp" -port 80 -name app-${count.index}
      # '"
    EOT
    destination = "/tmp/run_consul.sh"
    connection {
      type  = "ssh"
      host  = "${self.access_ip_v4}"
      user  = "root"
      # private_key = "${file("~/.ssh/id_rsa")}"
      agent = true
      bastion_host = "${openstack_networking_floatingip_v2.floatingip_db.address}"
      bastion_user = "root"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup_app.sh"
    destination = "/tmp/setup_app.sh"
    connection {
      type  = "ssh"
      host  = "${self.access_ip_v4}"
      user  = "root"
      # private_key = "${file("~/.ssh/id_rsa")}"
      agent = true
      bastion_host = "${openstack_networking_floatingip_v2.floatingip_db.address}"
      bastion_user = "root"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_app.sh",
      "/tmp/setup_app.sh",
      "chmod +x /tmp/run_consul.sh",
      "/tmp/run_consul.sh",
    ]

    connection {
      type = "ssh"
      host  = "${self.access_ip_v4}"
      user  = "root"
      # private_key = "${file("~/.ssh/id_rsa")}"
      agent = true
      bastion_host = "${openstack_networking_floatingip_v2.floatingip_db.address}"
      bastion_user = "root"
    }
  }
}
