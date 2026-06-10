#!/usr/bin/env bash
# Nuvem PIX — instalador/menu para VPS (Ubuntu 22.04/24.04 limpa).
# Uso:  sudo bash install.sh
set -euo pipefail
SELFDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELFDIR"
. "$SELFDIR/lib.sh"

[ "$(id -u)" = "0" ] || { echo "Rode como root:  sudo bash install.sh"; exit 1; }

pause() { printf '\n'; read -r -p "  Enter para voltar ao menu..." _ || true; }

# ============================================================
#  Nova instalação
# ============================================================
do_install() {
  logo
  bold "Nova instalação"
  local N=7

  # ---- 1) Docker ----
  step 1 $N "Docker"
  if ! command -v docker >/dev/null 2>&1; then
    note "Instalando Docker (pode demorar um pouco)..."
    curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 &
    spinner $! "Baixando e instalando o Docker"
  fi
  command -v docker >/dev/null 2>&1 || die "Docker não foi instalado."
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 ausente (instale o docker-compose-plugin)."
  ok "Docker pronto — $(docker --version | cut -d, -f1)"

  # ---- 2) Login no registro de imagens (GHCR) ----
  step 2 $N "Acesso às imagens"
  note "Use as credenciais que você recebeu (token read:packages)."
  GHCR_USER=$(ask "Usuário GHCR" "fredericozapponi")
  GHCR_TOKEN=$(asks "Token de acesso")
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin >/dev/null 2>&1 \
    || die "Login no GHCR falhou — confira o usuário e o token."
  ok "Login no GHCR OK."

  # ---- 3) Config / segredos ----
  step 3 $N "Configuração"
  if [ -f .env ] && ! yesno "Já existe um .env. Reconfigurar do zero?" "N"; then
    ok "Mantendo o .env atual."; SKIP_ENV=1
  fi

  if [ "${SKIP_ENV:-0}" != "1" ]; then
    printf "  ${DIM}Responda abaixo (Enter aceita o padrão entre colchetes):${RST}\n\n"
    DOMAIN=""
    while ! is_domain "$DOMAIN"; do
      DOMAIN=$(ask "Domínio apontado para esta VPS" "")
      is_domain "$DOMAIN" || warn "Domínio inválido (ex.: nuvempix.com.br)."
    done
    ACME_EMAIL=""
    while ! is_email "$ACME_EMAIL"; do
      ACME_EMAIL=$(ask "E-mail do certificado (Let's Encrypt)" "admin@$DOMAIN")
      is_email "$ACME_EMAIL" || warn "E-mail inválido."
    done
    ADMIN_EMAIL=""
    while ! is_email "$ADMIN_EMAIL"; do
      ADMIN_EMAIL=$(ask "E-mail do admin (login do painel)" "admin@$DOMAIN")
      is_email "$ADMIN_EMAIL" || warn "E-mail inválido."
    done
    while :; do
      ADMIN_PASSWORD=$(asks "Senha do admin (mín. 6)")
      [ "${#ADMIN_PASSWORD}" -ge 6 ] || { warn "Senha curta demais."; continue; }
      CONFIRM=$(asks "Confirme a senha")
      [ "$ADMIN_PASSWORD" = "$CONFIRM" ] && break || warn "As senhas não conferem, tente de novo."
    done
    PIX_PROVIDER=$(ask "Gateway Pix (mercadopago/mock)" "mercadopago")
    PIX_PAYER_EMAIL=$(ask "E-mail pagador padrão" "pagador@$DOMAIN")
    # As chaves do Mercado Pago são por estabelecimento (no painel), não aqui.

    printf "\n  ${B}Revise a configuração:${RST}\n"
    printf "    ${DIM}%-13s${RST} %s\n" "Domínio" "$DOMAIN"
    printf "    ${DIM}%-13s${RST} %s\n" "Painel" "https://$DOMAIN"
    printf "    ${DIM}%-13s${RST} %s\n" "Admin" "$ADMIN_EMAIL"
    printf "    ${DIM}%-13s${RST} %s\n\n" "Gateway Pix" "$PIX_PROVIDER"
    yesno "Confirmar e instalar?" "S" || die "Instalação cancelada."

    note "Gerando segredos fortes..."
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
PIX_WEBHOOK_BASE_URL=https://${DOMAIN}/api
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
    ok ".env gerado (segredos fortes; só root lê)."
  fi

  # ---- 4) EMQX ----
  step 4 $N "Broker MQTT (EMQX)"
  EMQX_TOKEN=$(grep '^EMQX_AUTH_TOKEN=' .env | cut -d= -f2)
  sed "s/<EMQX_AUTH_TOKEN>/${EMQX_TOKEN}/g" emqx/emqx.prod.conf > emqx/emqx.runtime.conf
  ok "Config do EMQX preparada."

  # ---- 5) Volume de dados ----
  step 5 $N "Volume de dados"
  mkdir -p data && chown -R 65532:65532 data || true
  ok "Pasta de dados pronta."

  # ---- 6) Firewall ----
  step 6 $N "Firewall"
  if command -v ufw >/dev/null 2>&1; then
    for p in 22 80 443 1883 8080; do ufw allow "$p"/tcp >/dev/null 2>&1 || true; done
    ok "Portas liberadas no ufw: 22, 80, 443, 1883, 8080."
  else
    note "ufw não encontrado — abra as portas 80, 443, 1883 e 8080 no firewall."
  fi

  # ---- 7) Baixa as imagens e sobe ----
  step 7 $N "Subindo a stack"
  local LOG=/tmp/nuvempix-install.log
  docker compose pull >"$LOG" 2>&1 &
  spinner $! "Baixando as imagens (detalhes em $LOG)"
  wait $! || { printf '\n'; tail -n 20 "$LOG"; die "Falha ao baixar as imagens."; }
  docker compose up -d >>"$LOG" 2>&1 &
  spinner $! "Iniciando os serviços"
  wait $! || { printf '\n'; tail -n 20 "$LOG"; die "Falha ao subir a stack — veja o log acima."; }
  ok "Serviços no ar."

  DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
  ADMIN_EMAIL=$(grep '^ADMIN_EMAIL=' .env | cut -d= -f2)
  printf "\n  ${GREEN}${B}╔══════════════════════════════════════════════╗${RST}\n"
  printf "  ${GREEN}${B}║            INSTALAÇÃO CONCLUÍDA ✔             ║${RST}\n"
  printf "  ${GREEN}${B}╚══════════════════════════════════════════════╝${RST}\n\n"
  printf "  ${B}Painel/site${RST}   https://%s\n" "$DOMAIN"
  printf "  ${B}Placas${RST}        http://%s:8080   ${DIM}|${RST}   MQTT: %s:1883\n" "$DOMAIN" "$DOMAIN"
  printf "  ${B}Login admin${RST}   %s\n" "$ADMIN_EMAIL"
  services_status
  printf '\n'
  note "DNS: o domínio precisa apontar para o IP desta VPS para o HTTPS."
  note "Logs: docker compose logs -f"
}

# ============================================================
#  Menu
# ============================================================
while true; do
  logo
  printf "  ${B}MENU${RST}\n\n"
  printf "    ${GOLD}${B}1${RST})  Nova Instalação\n"
  printf "    ${GOLD}${B}2${RST})  Atualizar Instalação\n"
  printf "    ${GOLD}${B}3${RST})  Sair\n\n"
  read -r -p "  Escolha [1-3]: " OPT || exit 0
  case "${OPT:-}" in
    1) do_install; pause ;;
    2) bash "$SELFDIR/update.sh"; pause ;;
    3) printf "\n  Até mais! 👋\n\n"; exit 0 ;;
    *) ;;
  esac
done
