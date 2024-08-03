#!/bin/bash

if [ $# -ne 2 ]; then
  echo "You need to enter a valid private IP address"
  exit 1
fi

PRIVATE_IP=$1
NEW_KEY_PATH="$HOME/.ssh/id_rsa"
OLD_KEY_PATH="${KEY_PATH}"
PUBLIC_IP=$2

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f $NEW_KEY_PATH -N ""

# Copy the new private key to the public instance
scp -i "$OLD_KEY_PATH" $NEW_KEY_PATH ubuntu@$PUBLIC_IP:/home/ubuntu/id_rsa
scp -i "$OLD_KEY_PATH" $NEW_KEY_PATH.pub ubuntu@$PUBLIC_IP:/home/ubuntu/id_rsa.pub

# Add the new public key to the authorized_keys on the private instance
ssh -i "$OLD_KEY_PATH" ubuntu@$PUBLIC_IP "echo $(cat $NEW_KEY_PATH.pub) >> ~/.ssh/authorized_keys"
ssh -i "$OLD_KEY_PATH" ubuntu@$PUBLIC_IP "ssh -i /home/ubuntu/id_rsa ubuntu@$PRIVATE_IP 'echo $(cat $NEW_KEY_PATH.pub) >> ~/.ssh/authorized_keys'"


# Replace the old key with the new key on the private instance
ssh -i "$NEW_KEY_PATH" ubuntu@$PUBLIC_IP "scp -i /home/ubuntu/id_rsa /home/ubuntu/id_rsa ubuntu@$PRIVATE_IP:/home/ubuntu/ && ssh -i /home/ubuntu/id_rsa ubuntu@$PRIVATE_IP 'mv /home/ubuntu/id_rsa /home/ubuntu/ent_key.pem'"

# Replace the old key with the new key locally
export KEY_PATH=""
mv $NEW_KEY_PATH /home/$USER/id_rsa.pub
mv ${NEW_KEY_PATH}.pub /home/$USER/id_rsa.pub

echo "SSH key rotation completed successfully."