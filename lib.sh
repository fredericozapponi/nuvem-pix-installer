#!/usr/bin/env bash
# Nuvem PIX — cores, logo e helpers compartilhados pelo instalador.

# Cores da marca (true-color; degrada bem onde não houver suporte).
GOLD=$'\033[38;2;251;204;28m'   # #FBCC1C
DGOLD=$'\033[38;2;201;152;18m'
GREEN=$'\033[1;32m'
REDC=$'\033[1;31m'
CYAN=$'\033[36m'
DIM=$'\033[2m'
B=$'\033[1m'
RST=$'\033[0m'

bold() { printf "  ${B}%s${RST}\n" "$1"; }
info() { printf "  ${CYAN}%s${RST}\n" "$1"; }
ok()   { printf "  ${GREEN}✔ %s${RST}\n" "$1"; }
warn() { printf "  ${GOLD}! %s${RST}\n" "$1"; }
note() { printf "  ${CYAN}•${RST} ${DIM}%s${RST}\n" "$1"; }
die()  { printf "\n  ${REDC}${B}✗ %s${RST}\n\n" "$1"; exit 1; }
gen()  { openssl rand -hex "${1:-24}"; }
ask()  { local p="$1" d="${2:-}" v; read -r -p "  ${B}$p${RST}${d:+ ${DIM}[$d]${RST}}: " v; echo "${v:-$d}"; }
asks() { local p="$1" v; read -r -s -p "  ${B}$p${RST}: " v; echo "" >&2; echo "$v"; }
yesno() { local p="$1" d="${2:-N}" v; v=$(ask "$p ${DIM}(s/N)${RST}" "$d"); [ "${v,,}" = "s" ]; }

# step "1" "7" "Título" — cabeçalho de etapa numerada.
step() { printf "\n  ${GOLD}${B}[%s/%s]${RST} ${B}%s${RST}\n" "$1" "$2" "$3"; }

# spinner <pid> "mensagem" — gira enquanto o processo roda; marca ✔ ao terminar.
spinner() {
  local pid=$1 msg=$2 chars='|/-\' i=0
  printf "  %s " "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 )); printf "\b%s" "${chars:$i:1}"; sleep 0.15
  done
  printf "\b${GREEN}✔${RST}\n"
}

# validações simples
is_domain() { [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; }
is_email()  { [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; }

# services_status — mostra os serviços de forma limpa (bolinha verde "no ar" / vermelha).
services_status() {
  printf "\n  ${B}Serviços${RST}\n"
  local name state status label dot st
  while IFS='|' read -r name state status; do
    [ -z "$name" ] && continue
    case "$name" in
      *backend*)  label="API / Backend" ;;
      *caddy*|*edge*) label="Site & HTTPS (Caddy)" ;;
      *emqx*)     label="Broker MQTT (EMQX)" ;;
      *postgres*) label="Banco (PostgreSQL)" ;;
      *redis*)    label="Cache (Redis)" ;;
      *)          label="$name" ;;
    esac
    if [ "$state" = "running" ]; then
      dot="${GREEN}●${RST}"
      case "$status" in
        *healthy*) st="${GREEN}no ar${RST} ${DIM}(saudável)${RST}" ;;
        *)         st="${GREEN}no ar${RST}" ;;
      esac
    else
      dot="${REDC}●${RST}"; st="${REDC}${state:-parado}${RST}"
    fi
    printf "    ${dot}  %-22s ${st}\n" "$label"
  done < <(docker ps -a --filter "name=nuvempix-" --format '{{.Names}}|{{.State}}|{{.Status}}' 2>/dev/null | sort)
}

# logo limpa a tela e desenha a marca Nuvem PIX em dourado.
logo() {
  clear 2>/dev/null || true
  printf '\n'
  printf "%s%s" "${GOLD}" "${B}"
  cat <<'ART'
     ███╗   ██╗██╗   ██╗██╗   ██╗███████╗███╗   ███╗
     ████╗  ██║██║   ██║██║   ██║██╔════╝████╗ ████║
     ██╔██╗ ██║██║   ██║██║   ██║█████╗  ██╔████╔██║
     ██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══╝  ██║╚██╔╝██║
     ██║ ╚████║╚██████╔╝ ╚████╔╝ ███████╗██║ ╚═╝ ██║
     ╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝     ╚═╝
ART
  printf "%s" "${RST}"
  printf "%s%s                  ☁   P  I  X%s\n" "${DGOLD}" "${B}" "${RST}"
  printf "%s          pagamentos por Pix · self-hosted%s\n\n" "${DIM}" "${RST}"
}
