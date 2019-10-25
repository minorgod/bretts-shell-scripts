#/bin/bash

AMI_ID=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/hostname)
PRIVATE_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PUBLIC_KEYS=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/)
SECURITY_GROUPS=$(curl -s http://169.254.169.254/latest/meta-data/security-groups)

echo -e "AMI_ID=$AMI_ID"
echo -e "INSTANCE_ID=$INSTANCE_ID"
echo -e "INSTANCE_TYPE=$INSTANCE_TYPE"
echo -e "HOSTNAME=$HOSTNAME"
echo -e "PRIVATE_HOSTNAME=$PRIVATE_HOSTNAME"
echo -e "PRIVATE_IP=$PRIVATE_IP"
echo -e "PUBLIC_HOSTNAME=\e[32m$PUBLIC_HOSTNAME\e[0m"
echo -e "PUBLIC_IP=\e[32m$PUBLIC_IP\e[0m"
echo -e "PUBLIC_KEYS=$PUBLIC_KEYS"
echo -e "SECURITY_GROUPS=$SECURITY_GROUPS"