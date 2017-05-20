provider "aws" {}

resource "aws_vpc" "default" {
        cidr_block           = "10.0.0.0/16"
        enable_dns_support   = true
        enable_dns_hostnames = true
}

module "mesos_ceph" {
        source                   = "github.com/riywo/mesos-ceph/terraform"
        vpc_id                   = "${aws_vpc.default.id}"
        key_name                 = "${var.key_name}"
        key_path                 = "${var.key_path}"
        subnet_availability_zone = "us-west-2"
        subnet_cidr_block        = "10.0.1.0/24"
        master1_ip               = "10.0.1.11"
        master2_ip               = "10.0.1.12"
        master3_ip               = "10.0.1.13"
}


resource "aws_instance" "admin" {
	instance_type     = "${var.instance_type[admin]}"
	ami               = "${lookup(var.ami, var.region)}"
	key_name          = "${var.key_name}"
	subnet_id         = "${aws_subnet.public.id}"
	security_groups   = ["${aws_security_group.private.id}", "${aws_security_group.maintenance.id}"]
	depends_on        = ["aws_internet_gateway.public"]

	connection {
		user     = "ubuntu"
		key_file = "${var.key_path}"
	}

	provisioner "file" {
		source      = "${var.key_path}"
		destination = "/home/ubuntu/.ssh/ec2-key.pem"
	}

	provisioner "remote-exec" {
		inline = [
			"chmod 600 /home/ubuntu/.ssh/ec2-key.pem",
			"echo \"Host ip-*\"                                      >> /home/ubuntu/.ssh/config",
			"echo \"    IdentityFile /home/ubuntu/.ssh/ec2-key.pem\" >> /home/ubuntu/.ssh/config",
			"echo \"    StrictHostKeyChecking no\"                   >> /home/ubuntu/.ssh/config",
			"echo \"    UserKnownHostsFile=/dev/null\"               >> /home/ubuntu/.ssh/config",
			"echo \"    LogLevel ERROR\"                             >> /home/ubuntu/.ssh/config",
			"echo ${var.master1_ip} >> /home/ubuntu/masters",
			"echo ${var.master2_ip} >> /home/ubuntu/masters",
			"echo ${var.master3_ip} >> /home/ubuntu/masters",
		]
	}

	provisioner "file" {
		source      = "${path.module}/scripts/header.sh"
		destination = "/tmp/${aws_instance.admin.id}-00header.sh"
        }

	provisioner "file" {
		source      = "${path.module}/scripts/init_admin.sh"
		destination = "/tmp/${aws_instance.admin.id}-01init_admin.sh"
	}

        provisioner "remote-exec" {
                inline = [
                        "echo main ${aws_instance.admin.private_ip} | cat /tmp/${aws_instance.admin.id}-*.sh - | bash"
                ]
        }
}
