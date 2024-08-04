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
    # Create JSON file for key exchange
    cat <<EOF > keyexchange.json
{
    "sessionID": "$SESSION_ID",
    "masterKey": "$MASTER_KEY",
    "sampleMessage": "Hi server, please encrypt me and send to client!"
}
EOF

    # Generate 32 random bytes and encode them in base64
    echo "Generating 32-byte master key..."
    openssl rand -base64 32 > "$MASTER_KEY_FILE"

    # Check if the master key was generated and saved successfully
    if [ -f "$MASTER_KEY_FILE" ]; then
      echo "Master key generated and saved to $MASTER_KEY_FILE"
    else
      echo "Failed to generate master key."
      exit 1
    fi

    # Encrypt the master key
    openssl smime -encrypt -aes-256-cbc -in master_key.txt -outform DER server_cert.pem | base64 -w 0 > encrypted_key.txt
    if [ $? -ne 0 ]; then
      echo "Failed to encrypt master key."
      exit 1
    fi
    MASTER_KEY=$(cat $MASTER_KEY_FILE)
    # Send the key exchange request
curl -s -X POST http://$SERVER_IP:8080/keyexchange \
     -H "Content-Type: application/json" \
     -d @keyexchange.json



# Check for errors
if [ $? -ne 0 ]; then
    echo "Failed to send Key Exchange request"
    exit 1
fi

echo "Key Exchange request sent successfully."







