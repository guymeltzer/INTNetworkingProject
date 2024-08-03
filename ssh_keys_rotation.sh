#!/bin/bash

if [ $# -ne 2 ]; then
  echo "You need to enter a valid private IP address"
  exit 1
fi

PRIVATE_IP=$1
NEW_KEY_PATH="$HOME/.ssh/id_rsa"
OLD_KEY_PATH="${KEY_PATH}"
PUBLIC_IP=$2

# Old keypair path
OLD_KEYPAIR=/home/guy/PycharmProjects/INTNetworkingProject/guy_networking_project_keypair.pem

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f $NEW_KEY_PATH -N ""

# Add new SSH key to the public instance
scp -o StrictHostKeyChecking=no -i $OLD_KEYPAIR $NEW_KEY_PATH.pub ubuntu@$PUBLIC_IP:/home/ubuntu/.ssh/id_rsa.pub
ssh -o StrictHostKeyChecking=no -i $OLD_KEYPAIR ubuntu@$PUBLIC_IP "cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys"

# Add the new public key to the authorized_keys on the private instance via the public instance
ssh -o StrictHostKeyChecking=no -i $OLD_KEYPAIR ubuntu@$PUBLIC_IP << EOF
  scp -o StrictHostKeyChecking=no -i /home/ubuntu/guy_networking_project_keypair.pem /home/ubuntu/.ssh/id_rsa.pub ubuntu@$PRIVATE_IP:/home/ubuntu/.ssh/id_rsa.pub &&
  ssh -o StrictHostKeyChecking=no -i /home/ubuntu/guy_networking_project_keypair.pem ubuntu@$PRIVATE_IP "cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys"
EOF

# Replace the old key with the new key on the private instance
scp -o StrictHostKeyChecking=no -i $NEW_KEY_PATH $NEW_KEY_PATH ubuntu@$PUBLIC_IP:/home/ubuntu/
ssh -o StrictHostKeyChecking=no -i $NEW_KEY_PATH ubuntu@$PUBLIC_IP << EOF
  scp -o StrictHostKeyChecking=no -i /home/ubuntu/id_rsa /home/ubuntu/$(basename $NEW_KEY_PATH) ubuntu@$PRIVATE_IP:/home/ubuntu/ &&
  ssh -o StrictHostKeyChecking=no -i /home/ubuntu/id_rsa ubuntu@$PRIVATE_IP "mv /home/ubuntu/$(basename $NEW_KEY_PATH) /home/ubuntu/ent_key.pem"
EOF

# Replace the old key with the new key locally
export KEY_PATH=$NEW_KEY_PATH
mv ${NEW_KEY_PATH}.pub /home/$USER/id_rsa.pub

echo "SSH key rotation completed successfully."




#echo "/home/guy/Documents/id_ed25519" | ssh-keygen
#echo ""
#echo ""

#scp -i /home/guy/Downloads/guy_networking_project_keypair.pem /home/guy/Documents/id_ed25519 ubuntu@51.20.71.169:/home/ubuntu
#ssh -i /home/guy/Downloads/guy_networking_project_keypair.pem ubuntu@51.20.71.169 "scp -i /home/ubuntu/guy_networking_project_keypair.pem /home/ubuntu/id_ed25519 ubuntu@10.0.1.216:/home/ubuntu"