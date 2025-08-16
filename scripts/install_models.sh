#!/bin/bash
# Script para instalar Docker e configurar Ollama/LLM Models

# Instala Docker e Docker Compose
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg # Mude a permissão para o novo nome de arquivo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu # Adiciona 'ubuntu' ao grupo docker (para futuras sessões SSH)
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker e Docker Compose instalados com sucesso!"

# Cria diretório e configura docker-compose para Ollama
sudo mkdir -p /opt/ollama_models
cd /opt/ollama_models

sudo cat > docker-compose.yml <<EOF
services:
  ollama:
    image: ollama/ollama
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped
    entrypoint: >
      sh -c "
        ollama serve &
        sleep 5 &&
        ollama pull llama3:8b &&
        tail -f /dev/null
      "
volumes:
  ollama_data:
EOF

# Inicia os serviços Docker Compose
# Use 'sudo docker compose' para garantir que seja executado com as permissões corretas
sudo docker compose up -d