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
# STEP 1: Install required dependencies
# -------------------------------
echo "Step 1: Installing software-properties-common"
if sudo apt-get install -y software-properties-common; then
  echo "Step 1 - done"
else
  echo "Step 1 - failed"
  exit 1
fi

# -------------------------------
# STEP 2: Add Ansible PPA
# -------------------------------
echo "Step 2: Adding Ansible PPA repository"
if sudo add-apt-repository --yes --update ppa:ansible/ansible; then
  echo "Step 2 - done"
else
  echo "Step 2 - failed"
  exit 1
fi

# -------------------------------
# STEP 3: Install Ansible
# -------------------------------
echo "Step 3: Installing Ansible"
if sudo apt-get install -y ansible; then
  echo "Step 3 - done"
else
  echo "Step 3 - failed"
  exit 1
fi

# -------------------------------
# STEP 4: Verify Ansible installation
# -------------------------------
echo "Step 4: Verifying Ansible version"
if ansible --version; then
  echo "Step 4 - done"
else
  echo "Step 4 - failed"
  exit 1
fi

# -------------------------------
# FINAL: Summary
# -------------------------------
echo ""
echo "========= Ansible Installation Summary ========="
echo "Ansible: $(ansible --version | head -n 1)"
echo "==============================================="
