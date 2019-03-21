#!/bin/bash -e

echo "-> Installing dependencies....."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  git \
  jq \
  less \
  software-properties-common \
  unzip \
  vim

echo "-> Downloading Vault....."
cd /tmp && {
curl -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
rm -fr vault_${VAULT_VERSION}_linux_amd64.zip
}

echo "-> Checking Vault version"
vault --version

echo "-> Create Vault data directories"
sudo mkdir /etc/vault
sudo mkdir -p /var/lib/vault/data

echo "-> Create user named vault"
sudo useradd --system --home /etc/vault --shell /bin/false vault
sudo chown -R vault:vault /etc/vault /var/lib/vault/

echo "-> Enable command autocompletion"
vault -autocomplete-install
complete -C /usr/local/bin/vault vault

echo "-> Writing systemd unit....."
cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/config.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill --signal HUP 
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitBurst=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "-> Create basic config"
sudo touch /etc/vault/config.hcl
cat <<EOF | sudo tee /etc/vault/config.hcl
disable_cache = true
disable_mlock = true
ui = true
listener "tcp" {
   address          = "0.0.0.0:8200"
   tls_disable      = 1
}
storage "file" {
   path  = "/var/lib/vault/data"
 }
api_addr         = "http://0.0.0.0:8200"
max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "vault"
raw_storage_endpoint     = true
disable_sealwrap     = true
disable_printable_check = true
EOF

echo "-> Starting vault....."
sudo systemctl daemon-reload
sudo systemctl enable --now vault

echo "-> Initialize vault....."
export VAULT_ADDR=http://127.0.0.1:8200
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bashrc

sudo rm -rf  /var/lib/vault/data/*
vault operator init | sudo tee /etc/vault/init.file