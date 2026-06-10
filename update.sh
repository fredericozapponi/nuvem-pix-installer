#!/usr/bin/env bash
# Nuvem PIX — atualiza para a última versão das imagens. Mantém .env e dados.
set -euo pipefail
SELFDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELFDIR"
. "$SELFDIR/lib.sh"

logo
bold "Atualizar instalação"
N=3
LOG=/tmp/nuvempix-update.log

# ---- 1) Arquivos do instalador (compose/config), se for um clone git ----
step 1 $N "Buscando atualizações"
git pull --ff-only >"$LOG" 2>&1 || true
ok "Arquivos atualizados (.env e dados preservados)."

# ---- 2) Config do EMQX (token do .env) ----
step 2 $N "Preparando configs"
if [ -f .env ]; then
  EMQX_TOKEN=$(grep '^EMQX_AUTH_TOKEN=' .env | cut -d= -f2)
  sed "s/<EMQX_AUTH_TOKEN>/${EMQX_TOKEN}/g" emqx/emqx.prod.conf > emqx/emqx.runtime.conf
fi
ok "Configs prontas."

# ---- 3) Imagens novas + restart ----
step 3 $N "Subindo a versão nova"
note "As migrações do banco sobem sozinhas no boot."
docker compose pull >>"$LOG" 2>&1 &
spinner $! "Baixando as imagens (detalhes em $LOG)"
wait $! || { printf '\n'; tail -n 20 "$LOG"; die "Falha ao baixar as imagens."; }
docker compose up -d >>"$LOG" 2>&1 &
spinner $! "Reiniciando os serviços"
wait $! || { printf '\n'; tail -n 20 "$LOG"; die "Falha ao subir — veja o log acima."; }

services_status
printf "\n  ${GREEN}${B}✔ Atualizado!${RST} Confira o painel.\n\n"
