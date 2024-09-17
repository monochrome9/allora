#!/bin/bash

read -p "Type your SEED phrase: " SEED

sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip

# Docker
sudo apt install -y apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Docker Compose
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

sudo groupadd docker
sudo usermod -aG docker $USER

# Go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile

# Clone prediction node
git clone https://github.com/allora-network/basic-coin-prediction-node
cd basic-coin-prediction-node

# Create .env
cat <<EOF > .env
TOKEN=ETH
TRAINING_DAYS=30
TIMEFRAME=4h
MODEL=SVR
REGION=US
DATA_PROVIDER=binance
CG_API_KEY=
EOF

# Setup config.json
cp config.example.json config.json
sed -i "s/\"addressRestoreMnemonic\": \"\"/\"addressRestoreMnemonic\": \"$SEED\"/" config.json

chmod +x init.config
./init.config

# Start
docker-compose up -d --build && docker-compose logs -f
