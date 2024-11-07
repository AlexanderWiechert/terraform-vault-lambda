#!/bin/bash
sudo yum update -y
sudo yum install -y wget unzip jq polkit

# Vault installieren
wget https://releases.hashicorp.com/vault/1.18.1/vault_1.18.1_linux_amd64.zip
sudo unzip vault_1.18.1_linux_amd64.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/vault

sudo mkdir /etc/vault
sudo useradd --system --home /etc/vault --shell /bin/false vault
sudo chown -R vault:vault /etc/vault
sudo mkdir -p /var/lib/vault/data
sudo chown -R vault:vault /var/lib/vault/

# Vault-Konfiguration mit Auto-Unseal

cat << EOF > /etc/vault/config.hcl
ui = true

disable_mlock = true

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
EOF



# Systemd Service für Vault erstellen
cat <<EOF >/etc/systemd/system/vault.service
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
EOF

# Vault starten
sudo systemctl daemon-reload
sudo systemctl start vault
sudo systemctl enable vault

# Warten, bis Vault startet
sleep 30


# SSH Public Key in authorized_keys hinzufügen
echo "${ssh_pub_key}" | sudo tee /home/ec2-user/.ssh/authorized_keys > /dev/null
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys