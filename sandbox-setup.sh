#!/bin/bash

# Default values
DOMAIN="www.supernets-rpc.com"
RPC_PORT="10002"
RELEASE_TAG="v0.6.3"

# Usage function
usage() {
  echo "Usage: $0 [-d domain] [-p rpc_port] [-r release_tag]" 1>&2;
  exit 1;
}

# Parse arguments
while getopts ":d:p:r:" opt; do
  case ${opt} in
    d )
      DOMAIN=$OPTARG
      ;;
    p )
      RPC_PORT=$OPTARG
      ;;
    r )
      RELEASE_TAG=$OPTARG
      ;;
    \? )
      usage
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Exit script on error
set -e

# Install Docker
log "Installing Docker"
sudo apt-get update -y
# Uninstall Old Versions
sudo apt-get remove docker docker-engine docker.io containerd runc || true
# Update apt to download over https
sudo apt-get update -y
sudo apt-get install ca-certificates curl gnupg -y
# Add Docker's official GPG Key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Set up Repository
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Install Docker Compose
log "Installing Docker Compose"
sudo apt install -y python3-pip
sudo pip3 install docker-compose

# Clone Edge and switch to the desired release commit
log "Cloning Polygon Edge"
git clone https://github.com/0xPolygon/polygon-edge.git
cd polygon-edge
git checkout -b v0.6.3 ae79516

# Build and run containers
log "Building and running containers"
cd docker/local/
sudo docker-compose build
sudo docker-compose up -d

# Setting up nginx and certbot
# Install Nginx
log "Installing Nginx"
sudo apt-get update
sudo apt-get install -y nginx

# Install Certbot
log "Installing Certbot"
sudo apt-get install -y certbot python3-certbot-nginx

# Creating nginx config
log "Creating Nginx config"
cd /etc/nginx/sites-enabled/
echo "server {
    server_name $DOMAIN;
    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://127.0.0.1:$RPC_PORT;

        # WebSocket support
    	proxy_http_version 1.1;
    	proxy_set_header Upgrade \$http_upgrade;
    	proxy_set_header Connection \"upgrade\";
    }
}" | sudo tee $DOMAIN.conf > /dev/null

# Verify Nginx config and restart Nginx
log "Reloading Nginx config"
sudo nginx -t && sudo nginx -s reload

# Obtain SSL/TLS Certificate
log "Obtaining SSL/TLS Certificate"
sudo certbot --nginx -d $DOMAIN

# Done
log "Setup complete"
