#!/usr/bin/env bash
# Nuvem PIX — instalador para VPS (Ubuntu 22.04/24.04 limpa).
# Baixa as imagens prontas do GHCR (com o token de acesso que você recebeu) e sobe a stack.
# Uso:  sudo bash install.sh
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
info() { printf "  \033[36m%s\033[0m\n" "$1"; }
gen()  { openssl rand -hex "${1:-24}"; }
ask()  { local p="$1" d="${2:-}" v; read -r -p "$p${d:+ [$d]}: " v; echo "${v:-$d}"; }
asks() { local p="$1" v; read -r -s -p "$p: " v; echo "" >&2; echo "$v"; }

[ "$(id -u)" = "0" ] || { echo "Rode como root:  sudo bash install.sh"; exit 1; }

bold "== Nuvem PIX — instalação =="

# ---- 1) Docker ----
if ! command -v docker >/dev/null 2>&1; then
  bold "Instalando Docker..."; curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || { echo "Instale o docker-compose-plugin."; exit 1; }
info "Docker OK: $(docker --version)"

# ---- 2) Login no registro de imagens (GHCR) ----
bold "Acesso às imagens (credenciais que você recebeu):"
GHCR_USER=$(ask "Usuário GHCR" "fredericozapponi")
GHCR_TOKEN=$(asks "Token de acesso (read:packages)")
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
info "Login no GHCR OK."

# ---- 3) Config / segredos ----
if [ -f .env ] && [ "$(ask 'Já existe .env. Reconfigurar? (s/N)' 'N')" != "s" ]; then
  info "Mantendo .env atual."; SKIP_ENV=1
fi

if [ "${SKIP_ENV:-0}" != "1" ]; then
  bold "Configuração:"
  DOMAIN=$(ask "Domínio (apontado para esta VPS)" "")
  while [ -z "$DOMAIN" ]; do DOMAIN=$(ask "Domínio é obrigatório" ""); done
  ACME_EMAIL=$(ask "E-mail do certificado (Let's Encrypt)" "admin@$DOMAIN")
  ADMIN_EMAIL=$(ask "E-mail do admin (login)" "admin@$DOMAIN")
  ADMIN_PASSWORD=$(asks "Senha do admin")
  while [ "${#ADMIN_PASSWORD}" -lt 6 ]; do ADMIN_PASSWORD=$(asks "Senha do admin (mín. 6)"); done
  PIX_PROVIDER=$(ask "Gateway Pix (mercadopago/mock)" "mercadopago")
  PIX_PAYER_EMAIL=$(ask "E-mail pagador padrão" "pagador@$DOMAIN")
  # As chaves do Mercado Pago NÃO são mais pedidas aqui: cada estabelecimento configura
  # a própria conta de recebimento no painel (Estabelecimentos → Recebimento).

  bold "Gerando segredos..."
  POSTGRES_PASSWORD=$(gen 16); MQTT_PASSWORD=$(gen 16)
  EMQX_AUTH_TOKEN=$(gen 24); EMQX_NODE_COOKIE=$(gen 16); JWT_SECRET=$(gen 32)

  cat > .env <<EOF
APP_ENV=production
HTTP_ADDR=:8080
NUVEMPIX_VERSION=latest
DOMAIN=${DOMAIN}
ACME_EMAIL=${ACME_EMAIL}
POSTGRES_USER=nuvempix
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=nuvempix
DATABASE_URL=postgres://nuvempix:${POSTGRES_PASSWORD}@postgres:5432/nuvempix?sslmode=disable
REDIS_URL=redis://redis:6379/0
MQTT_BROKER_URL=tcp://emqx:1883
MQTT_CLIENT_ID=nuvem-pix-backend
MQTT_USERNAME=backend
MQTT_PASSWORD=${MQTT_PASSWORD}
MQTT_TLS_INSECURE=false
EMQX_AUTH_TOKEN=${EMQX_AUTH_TOKEN}
EMQX_NODE_COOKIE=${EMQX_NODE_COOKIE}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DEVICE_BACKEND_URL=http://${DOMAIN}:8080
DEVICE_MQTT_HOST=${DOMAIN}
DEVICE_MQTT_PORT=1883
FIRMWARE_DIR=/app/data/firmware
LANDING_DIR=/app/data/landing
PIX_PROVIDER=${PIX_PROVIDER}
MP_BASE_URL=https://api.mercadopago.com
PIX_WEBHOOK_BASE_URL=https://${DOMAIN}
PIX_PAYER_EMAIL=${PIX_PAYER_EMAIL}
# Credenciais Mercado Pago são POR ESTABELECIMENTO (configuradas no painel), não aqui.
MP_ACCESS_TOKEN=
MP_WEBHOOK_SECRET=
JWT_SECRET=${JWT_SECRET}
JWT_TTL=24h
HEARTBEAT_TTL=60s
MONITOR_TICK=20s
PIX_PENDING_TTL=30m
EOF
  chmod 600 .env
  info ".env gerado."
fi

# ---- 4) Config do EMQX (injeta o token) ----
EMQX_TOKEN=$(grep '^EMQX_AUTH_TOKEN=' .env | cut -d= -f2)
sed "s/<EMQX_AUTH_TOKEN>/${EMQX_TOKEN}/g" emqx/emqx.prod.conf > emqx/emqx.runtime.conf

# ---- 5) Volume de dados ----
mkdir -p data && chown -R 65532:65532 data || true

# ---- 6) Firewall ----
if command -v ufw >/dev/null 2>&1; then
  for p in 22 80 443 1883 8080; do ufw allow "$p"/tcp >/dev/null 2>&1 || true; done
  info "Portas liberadas no ufw: 22, 80, 443, 1883, 8080."
fi

# ---- 7) Baixa as imagens e sobe ----
bold "Baixando imagens e subindo..."
docker compose pull
docker compose up -d

DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
echo ""
bold "== Pronto! =="
info "Painel/site:  https://${DOMAIN}"
info "Placas (HTTP): http://${DOMAIN}:8080   |   MQTT: ${DOMAIN}:1883"
info "DNS: o domínio precisa apontar para o IP desta VPS para o HTTPS."
info "Logs:    docker compose logs -f"
info "Atualizar: sudo bash update.sh"
