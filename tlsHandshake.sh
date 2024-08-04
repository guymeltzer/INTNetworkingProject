#!/bin/bash


if [ -z "$1" ]; then
    echo "You need to enter a valid IP address"
    exit 1
fi

SERVER_IP=$1
#ssh -i ~/.ssh/id_rsa ubuntu@SERVER_IP
#cd tls_webserver
#python3 -m venv venv
#source venv/bin/activate
#pip install aiohttp==3.9.3
#python3 app.py
echo "Sending Client Hello to $SERVER_IP..."
CLIENT_HELLO_RESPONSE=$(curl -s -X POST http://$SERVER_IP:8080/clienthello     -H "Content-Type: application/json"     -d '{
        "version": "1.3",
        "ciphersSuites": [
            "TLS_AES_128_GCM_SHA256",
            "TLS_CHACHA20_POLY1305_SHA256"
        ],
        "message": "Client Hello"
    }')

if [ $? -ne 0 ]; then
  echo "Failed to send Client Hello"
  exit 1
fi

echo "Client Hello sent successfully"
echo "Response: $CLIENT_HELLO_RESPONSE"

# Parse the JSON response to extract sessionID and serverCert
SESSION_ID=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.sessionID')
SERVER_CERT=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.serverCert')

if [ -z "$SESSION_ID" ] || [ -z "$SERVER_CERT" ]; then
  echo "Failed to parse sessionID or serverCert from response"
  exit 1
fi

echo "Session ID: $SESSION_ID"
echo "Server Certificate: $SERVER_CERT"
echo "$SERVER_CERT" > server_cert.pem
echo "Server certificate saved to server_cert.pem"
echo "Downloading CA certificate..."
wget https://exit-zero-academy.github.io/DevOpsTheHardWayAssets/networking_project/cert-ca-aws.pem

if [ ! -f cert-ca-aws.pem ]; then
  echo "Failed to download CA certificate."
  exit 1
fi

openssl verify -CAfile cert-ca-aws.pem server_cert.pem > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "cert.pem: OK"
else
  echo "Server Certificate is invalid."
  exit 5
fi


# Define the output file for the master key
MASTER_KEY_FILE="master_key.txt"
ENCRYPTED_KEY_FILE="encrypted_key.txt"
ENCRYPTED_KEY_BASE64_FILE="encrypted_key_base64.txt"
KEY_EXCHANGE_JSON="keyexchange.json"

# Generate 32 random bytes and encode them in base64
echo "Generating 32-byte master key..."
openssl rand -base64 32 > "$MASTER_KEY_FILE"

if [ ! -f "$MASTER_KEY_FILE" ]; then
    echo "Failed to generate master key."
    exit 1
fi
touch $ENCRYPTED_KEY_FILE
touch $ENCRYPTED_KEY_BASE64_FILE

echo "Master key generated and saved to $MASTER_KEY_FILE"

# Encrypt the master key
openssl smime -encrypt -aes-256-cbc -in "$MASTER_KEY_FILE" -out "$ENCRYPTED_KEY_FILE" -outform DER "server_cert.pem"
if [ $? -ne 0 ]; then
    echo "Failed to encrypt master key."
    exit 1
fi

# Convert encrypted key to base64
base64 -w 0 "$ENCRYPTED_KEY_FILE" > "$ENCRYPTED_KEY_BASE64_FILE"

# Create JSON file for key exchange
MASTER_KEY=$(cat "$ENCRYPTED_KEY_BASE64_FILE")
cat <<EOF > "$KEY_EXCHANGE_JSON"
{
    "sessionID": "$SESSION_ID",
    "masterKey": "$MASTER_KEY",
    "sampleMessage": "Hi server, please encrypt me and send to client!"
}
EOF

echo "Key exchange JSON created at $KEY_EXCHANGE_JSON"

#
# Send the key exchange request
KEY_EXCHANGE_RESPONSE=$(curl -s -X POST http://$SERVER_IP:8080/keyexchange \
     -H "Content-Type: application/json" \
     -d @"$KEY_EXCHANGE_JSON")

if [ $? -ne 0 ]; then
    echo "Failed to send Key Exchange request"
    exit 1
fi

echo "Key Exchange request sent successfully."
echo "Response: $KEY_EXCHANGE_RESPONSE"

# Parse the JSON response to extract the encrypted sample message
ENCRYPTED_SAMPLE_MESSAGE=$(echo $KEY_EXCHANGE_RESPONSE | jq -r '.encryptedSampleMessage')

if [ -z "$ENCRYPTED_SAMPLE_MESSAGE" ]; then
    echo "Failed to parse encrypted sample message from response"
    exit 1
fi

# Decode the encrypted sample message from base64
echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d > decrypted_sample_message.enc
# Define the sample message
SAMPLE_MESSAGE="Hi server, please encrypt me and send to client!"
# Decrypt the encrypted sample message using the master key
MASTER_KEY=$(cat "$MASTER_KEY_FILE")
DECRYPTED_MESSAGE=$(openssl enc -d -aes-256-cbc -pbkdf2 -k "$(cat $MASTER_KEY_FILE)" -in decrypted_sample_message.enc)
# Compare the decrypted message to the original sample message
if [ "$DECRYPTED_MESSAGE" != "$SAMPLE_MESSAGE" ]; then
    echo "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
else
    echo "Client-Server TLS handshake has been completed successfully."
fi



