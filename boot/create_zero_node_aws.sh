#!/bin/bash

REGION="us-east-1" # Deployment region; can be customized or externalized for multi-region deployments
AMI_ID="ami-04b4f1a9cf54c11d0"  # Official Ubuntu Server 22.04 LTS AMI (HVM, SSD-backed) for us-east-1
INSTANCE_TYPE="t3.micro" # Low-cost, burstable instance type for testing or lightweight automation workloads
KEY_NAME="My_mac" # Pre-generated EC2 key pair used for SSH access; must exist in the target region
INSTANCE_PROFILE_NAME="TerraformRunnerProfile" # IAM Instance Profile name used to attach the IAM Role to EC2
ROLE_NAME="TerraformRunnerRole" # IAM Role assumed by the EC2 instance to enable AWS API access via instance metadata
VPC_ID="vpc-02da23dcc42effc55" # Default Virtual Private Cloud (VPC); must match subnet and security group
SUBNET_ID="subnet-083c8f420a3e650bd" # Public Subnet within the target VPC; configured to auto-assign public IPs
SECURITY_GROUP_ID="sg-0325e0fb5c34df152"  # Security group with explicit SSH access enabled from any IPv4 source (0.0.0.0/0)

echo "Subnet: $SUBNET_ID"
echo "Security Group: $SECURITY_GROUP_ID"
echo "VPC: $VPC_ID"

# Create IAM Role for EC2 if it doesn't already exist
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' || echo "IAM role already exists"

# Attach AdministratorAccess policy to the role
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess || echo "Policy already attached"

# Create the instance profile (container for the IAM Role) if not present
aws iam create-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME || echo "Instance profile already exists"

# Ensure the role is attached to the instance profile (1:1 relationship)
sleep 5
aws iam add-role-to-instance-profile \
  --instance-profile-name $INSTANCE_PROFILE_NAME \
  --role-name $ROLE_NAME || echo "Role already added to instance profile"

# Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --associate-public-ip-address \
  --iam-instance-profile Name=$INSTANCE_PROFILE_NAME \
  --query "Instances[0].InstanceId" \
  --output text)

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "EC2 launch failed"
  exit 1
fi

# Add Name tag
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags Key=Name,Value=Terraform-Zero-Node \
  --region "$REGION"

# Wait for EC2 instance to be ready
echo "Waiting for EC2 instance to reach 'running' state..."
aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

# Now fetch public IP
echo "Fetching public IP for instance $INSTANCE_ID..."
PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "EC2 instance launched successfully: $INSTANCE_ID"
echo "Public IP address: $PUBLIC_IP"
