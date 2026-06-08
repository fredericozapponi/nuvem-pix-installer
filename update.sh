#!/usr/bin/env bash
# Nuvem PIX — atualiza para a última versão das imagens. Mantém .env e dados.
set -euo pipefail
SELFDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELFDIR"
. "$SELFDIR/lib.sh"

logo
bold "Atualizar instalação"
printf '\n'

# Atualiza os arquivos do instalador (compose/config), se for um clone git.
info "Buscando atualizações dos arquivos..."
git pull --ff-only 2>/dev/null || true

# Regenera a config do EMQX (token do .env).
if [ -f .env ]; then
  EMQX_TOKEN=$(grep '^EMQX_AUTH_TOKEN=' .env | cut -d= -f2)
  sed "s/<EMQX_AUTH_TOKEN>/${EMQX_TOKEN}/g" emqx/emqx.prod.conf > emqx/emqx.runtime.conf
fi

info "Baixando imagens novas..."
docker compose pull
docker compose up -d
printf '\n'
ok "Atualizado."
docker compose ps
