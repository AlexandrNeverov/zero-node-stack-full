#!/bin/bash

# Exit on error
set -e

# -------------------------------
# STEP 1: Download and install Vault
# -------------------------------
echo "[1/6] Installing HashiCorp Vault..."

VAULT_VERSION="1.16.1"
cd /tmp
curl -O https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip -o vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
vault --version

# -------------------------------
# STEP 2: Create vault user and directories
# -------------------------------
echo "[2/6] Creating Vault user and directories..."

sudo useradd --system --home /etc/vault.d --shell /bin/false vault

sudo mkdir -p /etc/vault.d
sudo mkdir -p /opt/vault/data
sudo chown -R vault:vault /etc/vault.d /opt/vault

# -------------------------------
# STEP 3: Create Vault configuration
# -------------------------------
echo "[3/6] Creating Vault config..."

cat <<EOF | sudo tee /etc/vault.d/vault.hcl
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

disable_mlock = true
ui = true
EOF

sudo chown vault:vault /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl

# -------------------------------
# STEP 4: Set systemd unit file
# -------------------------------
echo "[4/6] Configuring systemd service..."

cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault - secure secret management
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
LimitNOFILE=65536
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# -------------------------------
# STEP 5: Enable and start Vault
# -------------------------------
echo "[5/6] Enabling and starting Vault..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable vault
sudo systemctl start vault

# -------------------------------
# STEP 6: Export VAULT_ADDR
# -------------------------------
echo "[6/6] Exporting VAULT_ADDR and verifying..."

echo 'export VAULT_ADDR=http://127.0.0.1:8200' >> ~/.bashrc
export VAULT_ADDR=http://127.0.0.1:8200

sleep 3
vault status || echo "Vault is starting up, run 'vault status' again shortly."

echo "✅ Vault installation complete!"
