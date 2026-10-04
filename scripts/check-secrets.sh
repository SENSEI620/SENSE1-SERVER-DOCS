#!/usr/bin/env bash
# =============================================================================
# check-secrets.sh — rede de segurança antes de publicar a documentação.
# Procura padrões de segredo e endereços IP públicos nos arquivos do projeto.
#
# Uso:  bash scripts/check-secrets.sh        (o GitHub Actions também roda isto)
#
# NÃO é garantia de que nada vaza: é só uma última barreira. Revise o que
# escreve — a documentação é pública no GitHub Pages.
# =============================================================================
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

TARGETS=(docs scripts mkdocs.yml README.md)
FOUND=0

warn() {
  printf '\033[1;31m✗\033[0m %s\n' "$*"
  FOUND=1
}

# 1) padrões de segredos conhecidos ---------------------------------------
PATTERNS=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'ghp_[A-Za-z0-9]{30,}'
  'github_pat_[A-Za-z0-9_]{30,}'
  'AKIA[0-9A-Z]{16}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'eyJ[A-Za-z0-9_-]{40,}'
  '(PASSWORD|SECRET|TOKEN|API_KEY|ENCRYPTION_KEY)[A-Z_]*=[^$<"[:space:]{][^[:space:]]{11,}'
)

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    warn "Possível segredo em ${hit%%:*}:$(cut -d: -f2 <<< "$hit")  (padrão: ${pattern:0:28}...)"
  done < <(grep -rEnI --exclude=check-secrets.sh -e "$pattern" "${TARGETS[@]}" 2> /dev/null | cut -d: -f1,2)
done

# 2) endereços IP que não sejam privados/documentação/DNS conhecidos --------
ALLOWED='^(0\.0\.0\.0|127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|255\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|1\.1\.1\.1$|1\.0\.0\.1$|8\.8\.8\.8$|8\.8\.4\.4$|9\.9\.9\.9$)'

while IFS=: read -r file line ip; do
  [[ -z "$ip" ]] && continue
  [[ "$ip" =~ $ALLOWED ]] && continue
  warn "IP possivelmente público ($ip) em $file:$line"
done < <(grep -rEnoI --exclude=check-secrets.sh '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "${TARGETS[@]}" 2> /dev/null)

if ((FOUND)); then
  echo
  echo "Corrija os itens acima antes de publicar (troque por um placeholder como <seu-ip>)."
  exit 1
fi

printf '\033[1;32m✓\033[0m nenhum segredo ou IP público encontrado.\n'
