#!/bin/bash

# ========== CONFIG ================
PROJETO_LOCAL="/mnt/c/Users/Suporte/atendechat"
DB_USER="atendechat"
DB_PASS="3PDTleNftG3hfREtysleqHx61bgyKO89z2wIQ2Guw7M="
DB_NAME="atendechat"
DB_PORT="5432"
DB_HOST="localhost"
DEPLOY_PASSWORD="deploybotmal"
REMOTE_USER="deploy"
REMOTE_HOST="seu.servidor.com"  # ALTERAR AQUI!
REMOTE_PATH="/deploy/home/atendechat"
SSH_KEY="$PROJETO_LOCAL/deploy_key.pem"
CERT_PRIV="$PROJETO_LOCAL/certs/privkey.pem"
CERT_FULL="$PROJETO_LOCAL/certs/fullchain.pem"
ENV_FILE="$PROJETO_LOCAL/.env"
REDIS_URI="redis://:123456@127.0.0.1:6379"
JWT_SECRET="kZaOTd+YZpjRUyyuQUpigJaEMk4vcW4YOymKPZX0Ts8="
JWT_REFRESH_SECRET="dBSXqFg9TaNUEDXVp6fhMTRLBysP+j2DSqf7+raxD3A="
# ==================================

echo "🧪 Verificando se Docker está instalado..."
if ! command -v docker &> /dev/null; then
    echo "⚙️ Instalando Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable docker --now
fi

if ! command -v docker-compose &> /dev/null; then
    echo "⚙️ Instalando Docker Compose..."
    sudo apt install -y docker-compose
fi

echo "📦 Verificando docker-compose.yml..."
if [ ! -f "$PROJETO_LOCAL/docker-compose.yml" ]; then
    echo "❌ docker-compose.yml não encontrado em $PROJETO_LOCAL"
    exit 1
fi

echo "🔒 Verificando certificados SSL..."
if [[ ! -f "$CERT_PRIV" || ! -f "$CERT_FULL" ]]; then
    echo "❌ Certificados .pem ausentes!"
    echo "Esperado: $CERT_PRIV e $CERT_FULL"
    exit 1
fi

echo "📝 Gerando arquivo .env..."

cat > "$ENV_FILE" <<EOF
NODE_ENV=development
APP_DEBUG=true

BACKEND_URL=http://localhost
FRONTEND_URL=http://localhost:3000
PROXY_PORT=80
PORT=80

DB_DIALECT=postgres
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_NAME=$DB_NAME

JWT_SECRET=$JWT_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET

REDIS_URI=$REDIS_URI
REDIS_OPT_LIMITER_MAX=1
REDIS_OPT_LIMITER_DURATION=3000

USER_LIMIT=10000
CONNECTIONS_LIMIT=100000
CLOSED_SEND_BY_ME=true
EOF

echo "✅ .env criado com sucesso."

echo "🐳 Subindo containers com Docker Compose..."
cd "$PROJETO_LOCAL"
docker-compose down -v --remove-orphans
docker-compose up -d --build

# Aguarda containers subirem
sleep 10

echo "⏳ Testando conexão com Postgres..."
docker exec -it $(docker ps --filter "ancestor=postgres" --format "{{.ID}}") \
    psql -U "$DB_USER" -d "$DB_NAME" -c '\l' || echo "❌ Banco não acessível via Docker!"

echo "⏳ Testando Redis..."
docker run --rm redis:7 redis-cli -u $REDIS_URI PING || echo "❌ Falha ao conectar com Redis!"

# ======== DEPLOY REMOTO =========
echo "📤 Fazendo deploy remoto para $REMOTE_USER@$REMOTE_HOST..."

if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ Chave SSH $SSH_KEY não encontrada!"
    exit 1
fi

chmod 600 "$SSH_KEY"

rsync -avz -e "ssh -i $SSH_KEY" "$PROJETO_LOCAL"/ $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH

echo "✅ Deploy completo!"
