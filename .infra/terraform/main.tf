terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.0.0"
    }
    aws = {
			source  = "hashicorp/aws"
			version = "~> 3.0"
		}
  }
  required_version = ">= 0.13"
}

# Create SSH pair for admin
resource "tls_private_key" "terraform_admin_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create SSH pair for cicd
resource "tls_private_key" "terraform_cicd_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create SSH pair for app
resource "tls_private_key" "terraform_app_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  pub_ssh_key_value_admin = "${fileexists("~/.ssh/admin_pub_key.pub") == true ? file("~/.ssh/admin_pub_key.pub") : tls_private_key.terraform_admin_private_key.public_key_openssh}"
  pub_ssh_key_value_cicd = "${fileexists("~/.ssh/cicd_pub_key.pub") == true ? file("~/.ssh/cicd_pub_key.pub") : tls_private_key.terraform_cicd_private_key.public_key_openssh}"
  pub_ssh_key_value_app = "${fileexists("~/.ssh/app_pub_key.pub") == true ? file("~/.ssh/app_pub_key.pub") : tls_private_key.terraform_app_private_key.public_key_openssh}"
}

resource "null_resource" "spool_priv_ssh" {
  provisioner "local-exec" {   
    command = <<-EOT
      if [ ! -f ~/.ssh/admin_priv_key.pem ]; then  
   
        mkdir -p /home/${var.user_info["username4"]}/.ssh

        echo '${tls_private_key.terraform_admin_private_key.private_key_pem}' > ~/.ssh/admin_priv_key.pem
        echo '${tls_private_key.terraform_admin_private_key.public_key_openssh}' > ~/.ssh/admin_pub_key.pub

        echo '${tls_private_key.terraform_cicd_private_key.private_key_pem}' > ~/.ssh/cicd_priv_key.pem
        echo '${tls_private_key.terraform_cicd_private_key.public_key_openssh}' ~/.ssh/cicd_pub_key.pub

        echo '${tls_private_key.terraform_app_private_key.private_key_pem}' > ~/.ssh/app_priv_key.pem
        echo '${tls_private_key.terraform_app_private_key.public_key_openssh}' > ~/.ssh/app_pub_key.pub

        chmod 400 ~/.ssh/*_key.pem
        chmod 400 ~/.ssh/*_key.pub
      else
        echo 'nothing'
      fi
    EOT
  }
}

# Configure the AWS Provider
provider "aws" {
	region     = "us-west-2"
	access_key = var.aws_access_token
	secret_key = var.aws_secret_key
}

provider "yandex" {
    token     = var.cloud_provider["token"]
    cloud_id  = var.cloud_provider["cloud_id"]
    folder_id = var.cloud_provider["folder_id"]
    zone      = var.cloud_provider["zone"]
}

resource "yandex_compute_instance" "vm-1" {
  name = var.vm_param["vm_name"]
  platform_id = var.vm_param["platform_id"]

  resources {
    cores  = var.vm_param["core_cnt"]
    memory = var.vm_param["mem_cnt"]
    core_fraction = var.vm_param["cpu_util_pct"]
  }

  boot_disk {
    initialize_params {
      size     = var.vm_param["disk_boot_size"]
      image_id = var.vm_param["os_image_id"]
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ${var.user_info["username1"]}\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${local.pub_ssh_key_value_admin}"
  }

  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = var.cloud_provider["zone"]
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

data "aws_route53_zone" "rebrain_dns_zone" {
  	name = var.rebrain_dns_zone

    depends_on = [yandex_compute_instance.vm-1]
}

resource "aws_route53_record" "www" {
	zone_id = data.aws_route53_zone.rebrain_dns_zone.zone_id
	name    = var.dns_name
	type    = "A"
	ttl     = "300"
	records = [yandex_compute_instance.vm-1.network_interface.0.nat_ip_address]
  allow_overwrite = true

  depends_on = [yandex_compute_instance.vm-1]
}

resource "local_sensitive_file" "foo" {

  content  = 	templatefile("${path.module}/templates/inventory.tftpl", {
    host_ip = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
    host_name = var.vm_param["vm_name"]
    domain_name = var.dns_name
    # domain_name = "app-${replace(yandex_compute_instance.vm-1.network_interface.0.nat_ip_address, ".", "-")}.nip.io"
    ansible_user = var.user_info["username1"]
    enable_ssl = var.enable_ssl
    private_ssh_key_path = "~/.ssh/admin_priv_key.pem"
    pub_ssh_key_cicd = trimspace(local.pub_ssh_key_value_cicd)
    pub_ssh_key_app = trimspace(local.pub_ssh_key_value_app)
    web_port = var.web_param["web_port"]
    web_secure_port = var.web_param["web_secure_port"]
  })
  filename = "../ansible/inventory.yml"

  depends_on = [yandex_compute_instance.vm-1, null_resource.spool_priv_ssh]
}

resource "time_sleep" "wait_30_seconds" {

  depends_on = [local_sensitive_file.foo]

  create_duration = "30s"
}


resource "null_resource" "ansible" {

    provisioner "local-exec" {
      command = "echo \"${yandex_compute_instance.vm-1.network_interface.0.nat_ip_address}\" | sudo tee /home/${var.user_info["username4"]}/host_ip > /dev/null; sudo chown -R ${var.user_info["username4"]}:${var.user_info["username4"]} /home/${var.user_info["username4"]}/host_ip; cd ..; export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i ansible/inventory.yml ansible/base.yml"
    }

    depends_on = [local_sensitive_file.foo, time_sleep.wait_30_seconds, aws_route53_record.www]
}



# terraform -chdir="/home/vbif/08-final-project/.infra/terraform" import aws_route53_record.www ZCOKAAJ9UMS0T_vbif87atmailru.devops.rebrain.srwx.net_A
