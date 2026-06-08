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
warn() { printf "  ${GOLD}%s${RST}\n" "$1"; }
gen()  { openssl rand -hex "${1:-24}"; }
ask()  { local p="$1" d="${2:-}" v; read -r -p "  $p${d:+ [$d]}: " v; echo "${v:-$d}"; }
asks() { local p="$1" v; read -r -s -p "  $p: " v; echo "" >&2; echo "$v"; }

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
