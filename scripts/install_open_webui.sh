#!/bin/bash
# Script para instalar Docker e configurar Open-WebUI

# Instala Docker e Docker Compose
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu # Adiciona 'ubuntu' ao grupo docker (para futuras sessões SSH)
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker e Docker Compose instalados com sucesso!"

# Cria diretório e configura docker-compose e nginx para Open-WebUI
sudo mkdir -p /opt/openwebui
cd /opt/openwebui

sudo cat > docker-compose.yml <<EOF
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "80:80"
    networks:
      - open
    depends_on:
      - open-webui

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    ports:
      - "11434:11434"
    networks:
      - open
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped

  open-webui:
    image: ghcr.io/open-webui/open-webui:latest
    container_name: open-webui
    depends_on:
      - ollama
    networks:
      - open
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=Y87Zf6WtXu7Xl
    volumes:
      - openwebui_data:/app/backend/data
    restart: unless-stopped

volumes:
  ollama_data:
  openwebui_data:

networks:
  open:
    driver: bridge
EOF

sudo cat > nginx.conf <<EOF
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://open-webui:8080/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_buffering off;
            client_max_body_size 20M;
            proxy_read_timeout 10m;
        }
    }
}
EOF

# Inicia os serviços Docker Compose
# Use 'sudo docker compose' para garantir que seja executado com as permissões corretas
sudo docker compose up -d