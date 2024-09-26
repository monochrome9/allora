#!/bin/bash

read -p "Type your SEED phrase: " SEED

echo "Choose a TOKEN by entering the corresponding number: "
select TOKEN in ETH BTC SOL BNB ARB; do
    case $TOKEN in
        ETH|BTC|SOL|BNB|ARB)
            break
            ;;
        *)
            echo "Invalid option. Please choose a valid number."
            ;;
    esac
done

echo -e "\e[93mSelected token is: $TOKEN\e[0m"

echo "Choose a MODEL by entering the corresponding number: "
select MODEL in SVR KernelRidge BayesianRidge; do
    case $MODEL in
        SVR|KernelRidge|BayesianRidge)
            break
            ;;
        *)
            echo "Invalid option. Please choose a valid number."
            ;;
    esac
done

echo -e "\e[93mSelected model is: $MODEL\e[0m"

# Update and install essential packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl \
    git wget make jq build-essential pkg-config lsb-release libssl-dev \
    libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip \
    apt-transport-https

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Add user to docker group
sudo groupadd docker || true
sudo usermod -aG docker $USER

# Install Go
GO_VERSION=1.22.4
sudo rm -rf /usr/local/go
curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile

# Install Allora Wallet
git clone https://github.com/allora-network/allora-chain.git

# Clone prediction node
git clone https://github.com/allora-network/basic-coin-prediction-node
cd basic-coin-prediction-node

# Create .env
cat <<EOF > .env
TOKEN=$TOKEN
TRAINING_DAYS=30
TIMEFRAME=4h
MODEL=$MODEL
REGION=US
DATA_PROVIDER=binance
CG_API_KEY=
EOF

# Function to create config.json
generate_config() {
    local token=$1
    local topic_ids=()

    case $token in
        ETH) topic_ids=(1 2 7) ;;
        BTC) topic_ids=(3 4) ;;
        SOL) topic_ids=(5 6) ;;
        BNB) topic_ids=(8) ;;
        ARB) topic_ids=(9) ;;
    esac

    cat <<EOF > config.json
{
    "wallet": {
        "addressKeyName": "test",
        "addressRestoreMnemonic": "$SEED",
        "alloraHomeDir": "",
        "gas": "auto",
        "gasAdjustment": 1.5,
        "nodeRpc": "https://allora-rpc.testnet-1.testnet.allora.network/",
        "maxRetries": 1,
        "delay": 1,
        "submitTx": true
    },
    "worker": [
EOF

    for id in "${topic_ids[@]}"; do
        cat <<EOF >> config.json
        {
            "topicId": $id,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 5,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "$token"
            }
        },
EOF
    done

    # Remove trailing comma and close JSON
    sed -i '$ s/,$//' config.json
    echo '    ]' >> config.json
    echo '}' >> config.json

    echo -e "\e[93mConfig for $token generated\e[0m"
}

generate_config $TOKEN

chmod +x init.config && ./init.config

# Start Docker Compose
sudo docker-compose pull
sudo docker-compose up -d --build
echo -e "\e[32mThe worker has been installed\e[0m"
sudo docker-compose logs -f
