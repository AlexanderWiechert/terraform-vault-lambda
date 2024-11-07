provider "aws" {
  region = var.region
}

provider "local" {}

provider "null" {}

provider "template" {}

provider "vault" {
  address = "http://${aws_instance.vault.public_ip}:8200"
  token   = jsondecode(data.local_file.vault_init_data.content)["root_token"]
}


data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

}

resource "aws_kms_key" "vault_unseal_key" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "VaultAutoUnsealKey"
  }
}

resource "aws_iam_role" "vault_ec2_role" {
  name = "VaultEC2Role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "vault_kms_policy" {
  name = "VaultKMSPolicy"
  role = aws_iam_role.vault_ec2_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": aws_kms_key.vault_unseal_key.arn
    }]
  })
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "VaultInstanceProfile"
  role = aws_iam_role.vault_ec2_role.name
}

resource "aws_key_pair" "vault" {
  key_name   = "vault"  # Name des Schlüsselpaares
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "vault" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vault_instance_profile.name
  key_name = aws_key_pair.vault.key_name
  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "VaultServer"
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/vault-user-data.tpl")

  vars = {
    kms_key_id = aws_kms_key.vault_unseal_key.key_id
    region     = var.region
    ssh_pub_key = file("~/.ssh/id_rsa.pub")  # Pfad zum lokalen SSH Public Key
  }
}

resource "null_resource" "wait_for_vault" {
  depends_on = [aws_instance.vault]

  provisioner "local-exec" {
    command = "sleep 60"  # Wartezeit, um sicherzustellen, dass Vault hochgefahren ist
  }
}


resource "null_resource" "configure_vault" {
  depends_on = [null_resource.wait_for_vault]

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /etc/vault",
      "sudo useradd --system --home /etc/vault --shell /bin/false vault",
      "sudo chown -R vault:vault /etc/vault",
      "sudo mkdir -p /var/lib/vault/data",
      "sudo chown -R vault:vault /var/lib/vault/",
      "echo 'api_addr = \"http://${aws_instance.vault.public_ip}:8200\"' | sudo tee -a /etc/vault/config.hcl", #problem
      "echo 'cluster_addr = \"https://${aws_instance.vault.private_ip}:8201\"' | sudo tee -a /etc/vault/config.hcl", #problem
      "sudo -u vault /usr/local/bin/vault operator init  -address http://${aws_instance.vault.public_ip}:8200 -format=json >> /home/ec2-user/vault_init.json",
      "echo \"Root Token: $(jq -r .root_token /home/ec2-user/vault_init.json)\"| sudo tee -a /home/ec2-user/root.txt"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"  # Benutzername für Amazon Linux
      private_key = file("~/.ssh/id_rsa")  # Ihr privater Schlüssel
      host        = aws_instance.vault.public_ip
    }
  }

  provisioner "local-exec" {
    command = "scp -i ~/.ssh/id_rsa ec2-user@${aws_instance.vault.public_ip}:/home/ec2-user/vault_init.json ./vault_init.json && cat ./vault_init.json"
  }
}

data "local_file" "vault_init_data" {
  filename = "${path.module}/vault_init.json"
  depends_on = [null_resource.configure_vault]
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"

  depends_on = [null_resource.configure_vault]
}

resource "vault_generic_endpoint" "userpass_user" {
  path      = "auth/userpass/users/testuser"
  data_json = jsonencode({
    password = "pass123"
    policies = ["default"]
  })

  depends_on = [vault_auth_backend.userpass]
}