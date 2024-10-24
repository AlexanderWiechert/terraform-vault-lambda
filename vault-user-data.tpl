#!/bin/bash
sudo yum update -y
sudo yum install -y wget unzip jq

# Vault installieren
wget https://releases.hashicorp.com/vault/1.9.0/vault_1.9.0_linux_amd64.zip
sudo unzip vault_1.9.0_linux_amd64.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/vault

# Vault Benutzer und Verzeichnisse einrichten
sudo mkdir /etc/vault
sudo useradd --system --home /etc/vault --shell /bin/false vault
sudo chown -R vault:vault /etc/vault
sudo mkdir -p /var/lib/vault/data
sudo chown -R vault:vault /var/lib/vault/

# Vault-Konfiguration mit Auto-Unseal
echo 'ui = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

storage "file" {
  path = "/var/lib/vault/data"
}

seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_id}"
}

api_addr      = "http://${public_ip}:8200"
cluster_addr  = "https://${private_ip}:8201"
' | sudo tee /etc/vault/config.hcl

# Systemd Service für Vault erstellen
sudo tee /etc/systemd/system/vault.service > /dev/null << SERVICE
[Unit]
Description=Vault service
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

# Vault starten
sudo systemctl daemon-reload
sudo systemctl start vault
sudo systemctl enable vault

# Warten, bis Vault startet
sleep 30

# Vault initialisieren
vault operator init -format=json > /home/ec2-user/vault_init.json

# Root Token sichern
echo "Root Token: $(jq -r '.root_token' /home/ec2-user/vault_init.json)" > /home/ec2-user/root_token.txt

# Entsperren (wird durch Auto-Unseal automatisch gehandhabt)
# vault operator unseal $(jq -r '.unseal_keys_b64[0]' /home/ec2-user/vault_init.json)
# vault operator unseal $(jq -r '.unseal_keys_b64[1]' /home/ec2-user/vault_init.json)
# vault operator unseal $(jq -r '.unseal_keys_b64[2]' /home/ec2-user/vault_init.json)
