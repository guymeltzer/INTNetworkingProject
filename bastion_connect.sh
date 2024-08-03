#!/bin/bash

#KEY_PATH=/home/omer/omerNetworkingPTJkeypair.pem
KEY_PATH_2=/home/ubuntu/.ssh/github_test_ssh_key

# Check if KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

# Check the number of arguments
if [ "$#" -lt 1 ]; then
  echo "Please provide bastion IP address"
  exit 5
fi

# Assign variables
BASTION_IP=$1
PRIVATE_IP=$2
COMMAND=$3

scp_to_public_instance() {
  if [ -z "$3" ]; then
    echo "Usage: $0 <public-instance-ip> <local-file-path> <remote-file-path>"
    exit 5
  fi
  LOCAL_FILE=$2
  REMOTE_FILE=$3
  scp -i "$KEY_PATH" "$LOCAL_FILE" ubuntu@$PUBLIC_IP:"$REMOTE_FILE"
}
#scp -i ~/Downloads/guy_networking_project_keypair.pem /home/guy/Downloads/guy_networking_project_keypair.pem ubuntu@16.171.60.136:/home/ubuntu


# If only bastion IP is provided, connect to the bastion host
if [ -z "$PRIVATE_IP" ]; then
  ssh -i "$KEY_PATH" ubuntu@"$BASTION_IP"
else
  # If both bastion IP and private IP are provided, connect to the private host through the bastion host
  if [ -z "$COMMAND" ]; then
    ssh -t -i "$KEY_PATH" ubuntu@"$BASTION_IP" "ssh -i $KEY_PATH_2 ubuntu@$PRIVATE_IP"
  else
    ssh -t -i "$KEY_PATH" ubuntu@"$BASTION_IP" "ssh -i $KEY_PATH_2 ubuntu@$PRIVATE_IP '$COMMAND'"
  fi
fi
