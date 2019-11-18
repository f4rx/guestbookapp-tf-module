###################################
# Create port
###################################
resource "openstack_networking_port_v2" "port_db" {
  name       = "node-db"
  network_id =  "${openstack_networking_network_v2.network_1.id}"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
  }
}

###################################
# Create Volume/Disk
###################################
resource "openstack_blockstorage_volume_v3" "volume_db" {
  name                 = "volume-for-db"
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
resource "openstack_compute_instance_v2" "instance_db" {
  name              = "db"
  flavor_id         = "${data.openstack_compute_flavor_v2.flavor_1.id}"
  key_pair          = "${openstack_compute_keypair_v2.terraform_key.id}"
  availability_zone = "${var.az_zone}"

  network {
    port = "${openstack_networking_port_v2.port_db.id}"
  }

  block_device {
    uuid             = "${openstack_blockstorage_volume_v3.volume_db.id}"
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
    source      = "${path.module}/scripts/setup_db.sh"
    destination = "/tmp/setup_db.sh"
    connection {
      type  = "ssh"
      host  = "${openstack_networking_floatingip_v2.floatingip_db.address}"
      user  = "root"
      # private_key = "${file("~/.ssh/id_rsa")}"
      agent = true
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_db.sh",
      "/tmp/setup_db.sh",
    ]

    connection {
      type = "ssh"
      host  = "${openstack_networking_floatingip_v2.floatingip_db.address}"
      user  = "root"
      # private_key = "${file("~/.ssh/id_rsa")}"
      agent = true
    }
  }
}

###################################
# Create floating IP
###################################
resource "openstack_networking_floatingip_v2" "floatingip_db" {
  pool = "external-network"
}

###################################
# Link floating IP to internal IP
###################################
resource "openstack_networking_floatingip_associate_v2" "association_1" {
  port_id     = "${openstack_networking_port_v2.port_db.id}"
  floating_ip = "${openstack_networking_floatingip_v2.floatingip_db.address}"
}
