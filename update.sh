#!/usr/bin/env bash
# Nuvem PIX — atualiza para a última versão das imagens. Mantém .env e dados.
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

echo "== Atualizando Nuvem PIX =="
# Atualiza os arquivos do instalador (compose/config), se for um clone git.
git pull --ff-only 2>/dev/null || true

# Regenera a config do EMQX (token do .env).
if [ -f .env ]; then
  EMQX_TOKEN=$(grep '^EMQX_AUTH_TOKEN=' .env | cut -d= -f2)
  sed "s/<EMQX_AUTH_TOKEN>/${EMQX_TOKEN}/g" emqx/emqx.prod.conf > emqx/emqx.runtime.conf
fi

docker compose pull
docker compose up -d
echo "== Atualizado. =="
docker compose ps
