#!/bin/bash

set -e

# ----------------------------
# CONFIGURATION
# ----------------------------
AWS_REGION="us-east-1"
TIMESTAMP=$(date +%s)
BUCKET_NAME="terraform-backend-zero-${TIMESTAMP}"
DYNAMODB_TABLE="terraform-locks-zero-${TIMESTAMP}"
ROLE_NAME="TerraformRunnerRole"

# ----------------------------
# STEP 1: Update & install dependencies (smart check)
# ----------------------------
echo "[1/6] Installing Terraform and dependencies..."

sudo apt-get update -y

# Only install missing packages
ESSENTIAL_PACKAGES=(unzip curl gnupg software-properties-common)
TO_INSTALL=()

for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    TO_INSTALL+=("$pkg")
  fi
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
  echo "Installing: ${TO_INSTALL[*]}"
  sudo apt-get install -y "${TO_INSTALL[@]}"
else
  echo "All essential packages already installed – skipping"
fi

# Add HashiCorp GPG key and repo
curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y
sudo apt-get install -y terraform

echo "Terraform version:"
terraform -version

# ----------------------------
# STEP 2: Create S3 bucket
# ----------------------------
echo "[2/6] Creating S3 bucket: $BUCKET_NAME..."

if [[ "$AWS_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

# ----------------------------
# STEP 3: Enable versioning
# ----------------------------
echo "[3/6] Enabling versioning on bucket..."

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# ----------------------------
# STEP 4: Create DynamoDB table
# ----------------------------
echo "[4/6] Creating DynamoDB table: $DYNAMODB_TABLE..."

aws dynamodb create-table \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"

# ----------------------------
# STEP 5: Wait for DynamoDB table to be active
# ----------------------------
echo "[5/6] Waiting for DynamoDB table to become ACTIVE..."

aws dynamodb wait table-exists \
  --table-name "$DYNAMODB_TABLE" \
  --region "$AWS_REGION"

echo "Polling for table status = ACTIVE..."
for i in {1..30}; do
  STATUS=$(aws dynamodb describe-table \
    --table-name "$DYNAMODB_TABLE" \
    --region "$AWS_REGION" \
    --query "Table.TableStatus" --output text)

  if [[ "$STATUS" == "ACTIVE" ]]; then
    echo "✅ Table status is ACTIVE"
    break
  fi

  echo "⏳ Current status: $STATUS – waiting..."
  sleep 2
done

# ----------------------------
# STEP 6: Final Output
# ----------------------------
echo ""
echo "✅ Terraform installed"
echo "✅ S3 bucket created: $BUCKET_NAME"
echo "✅ DynamoDB table created: $DYNAMODB_TABLE"
echo ""
echo "---------------------------------------------"
echo "➡️ Use the following backend config in Terraform:"
echo "---------------------------------------------"
cat <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}
EOF
echo "---------------------------------------------"

# ----------------------------
# STEP 7: List IAM policies attached to TerraformRunnerRole
# ----------------------------
echo ""
echo "[6/6] Listing IAM policies attached to role: $ROLE_NAME"
aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME"
