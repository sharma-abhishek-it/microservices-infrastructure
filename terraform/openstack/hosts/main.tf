variable auth_url { }
variable control_count {}
variable control_flavor_name { }
variable datacenter { default = "openstack" }
variable glusterfs_volume_size { default = "100" } # size is in gigabytes
variable image_name { }
variable keypair_name { }
variable long_name { default = "microservices-infrastructure" }
variable net_id { }
variable resource_count {}
variable resource_flavor_name { }
variable security_groups { default = "default" }
variable short_name { default = "mi" }
variable ssh_user { default = "centos" }
variable tenant_id { }
variable tenant_name { }

provider "openstack" {
  auth_url = "${ var.auth_url }"
  tenant_id	= "${ var.tenant_id }"
  tenant_name	= "${ var.tenant_name }"
}

resource "openstack_blockstorage_volume_v1" "mi-control-glusterfs" {
  name = "${ var.short_name }-control-glusterfs-${format("%02d", count.index+1) }"
  description = "${ var.short_name }-control-glusterfs-${format("%02d", count.index+1) }"
  size = "${ var.glusterfs_volume_size }"
  metadata = {
    usage = "container-volumes"
  }
  count = "${ var.control_count }"
}

resource "openstack_compute_instance_v2" "control" {
  name = "${ var.short_name}-control-${format("%02d", count.index+1) }"
  key_pair = "${ var.keypair_name }"
  image_name = "${ var.image_name }"
  flavor_name = "${ var.control_flavor_name }"
  security_groups = [ "${ var.security_groups }", "${var.short_name}-consul-common", "${var.short_name}-consul-agents", "${var.short_name}-mesos-infra", "${var.short_name}-zookeeper", "${var.short_name}-common" ]
  network = { uuid  = "${ var.net_id }" }
  volume = {
    volume_id = "${element(openstack_blockstorage_volume_v1.mi-control-glusterfs.*.id, count.index)}"
    device = "/dev/vdb"
  }
  metadata = {
    dc = "${var.datacenter}"
    role = "control"
    ssh_user = "${ var.ssh_user }"
  }
  count = "${ var.control_count }"
}

resource "openstack_compute_instance_v2" "resource" {
  name = "${ var.short_name}-worker-${format("%02d", count.index+1) }"
  key_pair = "${ var.keypair_name }"
  image_name = "${ var.image_name }"
  flavor_name = "${ var.resource_flavor_name }"
  security_groups = [ "${ var.security_groups }", "${var.short_name}-consul-common", "${var.short_name}-consul-servers", "${var.short_name}-mesos-infra", "${var.short_name}-web", "${var.short_name}-common" ]
  network = { uuid = "${ var.net_id }" }
  metadata = {
    dc = "${var.datacenter}"
    role = "worker"
    ssh_user = "${ var.ssh_user }"
  }
  count = "${ var.resource_count }"
}

resource "openstack_compute_secgroup_v2" "secgroup_consul_common" {
  name = "${var.short_name}-consul-common"
  description = "security group for common ports between agents and servers"

  rule { # HTTP-API
    from_port = 8500
    to_port = 8500
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # DNS
    from_port = 8600
    to_port = 8600
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # DNS
    from_port = 8600
    to_port = 8600
    ip_protocol = "udp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_consul_agents" {
  name = "${var.short_name}-consul-agents"
  description = "security group for consul agents only"

  rule { # Serf-LAN
    from_port = 8301
    to_port = 8301
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # Serf-LAN
    from_port = 8301
    to_port = 8301
    ip_protocol = "udp"
    cidr = "0.0.0.0/0"
  }
  rule { # Cli-RPC
    from_port = 8400
    to_port = 8400
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_consul_servers" {
  name = "${var.short_name}-consul-servers"
  description = "security group for consul servers only"

  rule { # Server-RPC
    from_port = 8300
    to_port = 8300
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # Serf-WAN
    from_port = 8302
    to_port = 8302
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # Serf-WAN
    from_port = 8302
    to_port = 8302
    ip_protocol = "udp"
    cidr = "0.0.0.0/0"
  }
}


resource "openstack_compute_secgroup_v2" "secgroup_mesos_infra" {
  name = "${var.short_name}-mesos-infra"
  description = "security group for mesos ecosystem"

  rule { # mesos-leader
    from_port = 5050
    to_port = 5050
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # mesos-worker
    from_port = 5051
    to_port = 5051
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # marathon
    from_port = 8080
    to_port = 8080
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { # chronos
    from_port = 4400
    to_port = 4400
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_zookeeper" {
  name = "${var.short_name}-zookeeper"
  description = "security group for zookeeper"

  rule {
    from_port = 2181
    to_port = 2181
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 2888
    to_port = 2888
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = 3888
    to_port = 3888
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_web" {
  name = "${var.short_name}-web"
  description = "security group for web ports"

  rule { #http
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { #https
    from_port = 443
    to_port = 443
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_common" {
  name = "${var.short_name}-common"
  description = "security group common between workers and control nodes"

  rule { #ssh
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
  rule { #ICMP
    from_port = -1
    to_port = -1
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
  }
}
