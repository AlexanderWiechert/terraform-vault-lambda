provider "aws" {
  region = var.region
}

provider "local" {}

provider "null" {}

provider "template" {}

provider "vault" {
  address = "http://${aws_instance.vault.public_ip}:8200"
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

resource "aws_instance" "vault" {
  ami                         = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vault_instance_profile.name
  key_name                    = var.key_name  # Ersetze durch deinen Schlüssel

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
    public_ip  = aws_instance.vault.public_ip
    private_ip = aws_instance.vault.private_ip
  }
}

resource "null_resource" "wait_for_vault" {
  depends_on = [aws_instance.vault]

  provisioner "local-exec" {
    command = "sleep 60"  # Wartezeit, um sicherzustellen, dass Vault hochgefahren ist
  }
}

resource "vault_initialization" "vault_init" {
  depends_on = [null_resource.wait_for_vault]

  # Vault ist mit Auto-Unseal konfiguriert, daher ist keine manuelle Entsperrung erforderlich
  # Initialisierung kann über den Vault Provider erfolgen, wenn der Root Token verfügbar ist
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"

  depends_on = [vault_initialization.vault_init]
}

resource "vault_generic_endpoint" "userpass_user" {
  path      = "auth/userpass/users/testuser"
  data_json = jsonencode({
    password = "pass123"
    policies = ["default"]
  })

  depends_on = [vault_auth_backend.userpass]
}

output "vault_address" {
  description = "Die öffentliche IP-Adresse der Vault-Instanz"
  value       = aws_instance.vault.public_ip
}

output "api_invoke_url" {
  description = "Die Invoke URL der API Gateway für die Lambda-Funktion"
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
}
