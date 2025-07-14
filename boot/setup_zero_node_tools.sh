#!/bin/bash

# Exit immediately if any command fails
set -e

# -------------------------------
# STEP 0: Update and upgrade system packages
# -------------------------------
echo "Step 0: System update & upgrade"
if sudo apt-get update -y && sudo apt-get upgrade -y; then
  echo "Step 0 - done"
else
  echo "Step 0 - failed"
  exit 1
fi

# -------------------------------
# STEP 1: Set system timezone
# -------------------------------
echo "Step 1: Setting timezone to America/New_York"
if sudo timedatectl set-timezone America/New_York; then
  timedatectl
  echo "Step 1 - done"
else
  echo "Step 1 - failed"
  exit 1
fi

# -------------------------------
# STEP 2: Install essential utilities
# -------------------------------
echo "Step 2: Installing required utilities (unzip, curl, gnupg, software-properties-common)"
if sudo apt-get install -y unzip curl gnupg software-properties-common; then
  echo "Step 2 - done"
else
  echo "Step 2 - failed"
  exit 1
fi

# -------------------------------
# STEP 3: Install other common tools
# -------------------------------
echo "Step 3: Installing tree, net-tools, python3, pip3, git, jq, htop, tmux"
if sudo apt-get install -y tree net-tools python3 python3-pip git jq htop tmux; then
  echo "Step 3 - done"
else
  echo "Step 3 - failed"
  exit 1
fi

# -------------------------------
# STEP 4: Install AWS CLI (v2)
# -------------------------------
echo "Step 4: Installing AWS CLI"
if curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip -o awscliv2.zip && sudo ./aws/install; then
  aws --version
  echo "Step 4 - done"
else
  echo "Step 4 - failed"
  exit 1
fi

# -------------------------------
# STEP 5: Create project directories
# -------------------------------
echo "Step 5: Creating ~/projects/terraform and ~/projects/ansible"
PROJECTS_DIR="$HOME/projects"
if mkdir -p "$PROJECTS_DIR/terraform" && mkdir -p "$PROJECTS_DIR/ansible"; then
  echo "Step 5 - done"
else
  echo "Step 5 - failed"
  exit 1
fi

# -------------------------------
# STEP 6: Save public IP to ~/projects/publicip
# -------------------------------
echo "Step 6: Saving public IP to $PROJECTS_DIR/publicip"
PUBLIC_IP=$(curl -s ifconfig.me)
PUBLIC_IP_FILE="$PROJECTS_DIR/publicip"
if echo "$PUBLIC_IP" > "$PUBLIC_IP_FILE"; then
  echo "Public IP saved to $PUBLIC_IP_FILE: $PUBLIC_IP"
  echo "Step 6 - done"
else
  echo "Step 6 - failed"
  exit 1
fi

# -------------------------------
# STEP 7: Generate SSH key
# -------------------------------
echo "Step 7: Generating SSH key (if not exists)"
SSH_KEY_PATH="$HOME/.ssh/zero-node-key"
if [[ -f "$SSH_KEY_PATH" ]]; then
  echo "SSH key already exists at $SSH_KEY_PATH - skipping"
else
  if ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "zero-node-key"; then
    echo "Step 7 - SSH key generated"
  else
    echo "Step 7 - failed to generate SSH key"
    exit 1
  fi
fi

# -------------------------------
# STEP 8: Copy public SSH key to ~/projects/
# -------------------------------
echo "Step 8: Copying SSH public key to $PROJECTS_DIR/ssh.pub"
if cp "$SSH_KEY_PATH.pub" "$PROJECTS_DIR/ssh.pub"; then
  echo "Step 8 - done"
else
  echo "Step 8 - failed"
  exit 1
fi

# -------------------------------
# FINAL: Summary of installed tools
# -------------------------------
echo ""
echo "========= Installed Tools Summary ========="
echo "Timezone: $(timedatectl | grep 'Time zone')"
echo "Python 3: $(python3 --version 2>&1)"
echo "pip3:     $(pip3 --version 2>&1)"
echo "Git:      $(git --version 2>&1)"
echo "Curl:     $(curl --version | head -n 1)"
echo "Unzip:    $(unzip -v | head -n 1)"
echo "Tree:     $(tree --version 2>&1)"
echo "JQ:       $(jq --version 2>&1)"
echo "AWS CLI:  $(aws --version 2>&1)"
echo "htop:     $(htop --version 2>&1)"
echo "tmux:     $(tmux -V 2>&1)"
echo "SSH key:  ${SSH_KEY_PATH} / ${SSH_KEY_PATH}.pub (also copied to $PROJECTS_DIR/ssh.pub)"
echo "Public IP: $PUBLIC_IP  (saved to $PUBLIC_IP_FILE)"
echo "Projects dir: $PROJECTS_DIR (contains terraform/, ansible/)"
echo "==========================================="
