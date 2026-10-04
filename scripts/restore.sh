#!/usr/bin/env bash
# =============================================================================
# restore.sh — restaura um backup gerado pelo backup.sh
#
# Uso:  sudo ./restore.sh /caminho/servidor-AAAAMMDD-HHMMSS.tar.gz
#
# O que faz:
#   1. confere o checksum (se houver .sha256 ao lado)
#   2. desliga os serviços atuais e substitui o conteúdo de $STACK_DIR
#   3. sobe só os containers PostgreSQL e carrega os dumps
#   4. sobe todo o resto
#   5. guarda as configs do sistema em /root/restore-etc-* para você consultar
#      (netplan, fstab etc. NÃO são aplicados: dependem do hardware)
# =============================================================================
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Rode com sudo." >&2
  exit 1
fi

ARCHIVE="${1:-}"
if [[ ! -f "$ARCHIVE" ]]; then
  echo "Uso: sudo $0 /caminho/arquivo-de-backup.tar.gz" >&2
  exit 1
fi

# shellcheck source=/dev/null
[[ -f /etc/server-docs.env ]] && source /etc/server-docs.env
STACK_DIR="${STACK_DIR:-/opt/stack}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log() { printf '\n\033[1;36m[restore]\033[0m %s\n' "$*"; }

if [[ -f "$ARCHIVE.sha256" ]]; then
  log "Conferindo checksum"
  (cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE").sha256")
else
  log "Aviso: sem arquivo .sha256 ao lado — não deu para conferir a integridade."
fi

echo
echo "Isto vai SUBSTITUIR o conteúdo de $STACK_DIR neste servidor."
read -r -p "Digite RESTAURAR para continuar: " ans
if [[ "$ans" != "RESTAURAR" ]]; then
  echo "Cancelado."
  exit 1
fi

log "Extraindo o pacote"
tar -xzf "$ARCHIVE" -C "$WORK"
if [[ ! -f "$WORK/stack.tar.gz" ]]; then
  echo "Pacote inválido: stack.tar.gz não encontrado." >&2
  exit 1
fi

# --- 2. desliga o que existir e restaura os arquivos -----------------------
if [[ -d "$STACK_DIR" ]]; then
  log "Desligando serviços atuais"
  for dir in "$STACK_DIR"/*/; do
    if [[ -f "$dir/compose.yaml" ]]; then
      (cd "$dir" && docker compose down) || true
    fi
  done
fi

log "Restaurando arquivos em $STACK_DIR"
mkdir -p "$STACK_DIR"
tar -xzf "$WORK/stack.tar.gz" --strip-components=1 -C "$STACK_DIR"

# --- 3. bancos de dados ----------------------------------------------------
log "Subindo os containers PostgreSQL"
for dir in "$STACK_DIR"/*/; do
  [[ -f "$dir/compose.yaml" ]] || continue
  mapfile -t dbs < <(cd "$dir" && docker compose config --services | grep -i postgres || true)
  if ((${#dbs[@]} > 0)); then
    (cd "$dir" && docker compose up -d "${dbs[@]}")
  fi
done

shopt -s nullglob
for dump in "$WORK"/db/*.sql.gz; do
  c="$(basename "$dump" .sql.gz)"
  if ! docker inspect "$c" > /dev/null 2>&1; then
    log "Container '$c' não existe aqui — pulei esse dump (confira o 'name:' do compose)."
    continue
  fi
  log "Carregando o dump em $c"
  for _ in {1..60}; do
    docker exec "$c" pg_isready -q && break
    sleep 2
  done
  user="$(docker exec "$c" printenv POSTGRES_USER 2> /dev/null || echo postgres)"
  errlog="/root/restore-$c-$STAMP.err"
  gunzip -c "$dump" | docker exec -i "$c" psql -q -U "$user" -d postgres > /dev/null 2> "$errlog" || true
  # erros "already exists" são esperados (o container novo já criou o usuário e o banco)
  other_errors="$(grep ERROR "$errlog" | grep -vc 'already exists' || true)"
  log "     concluído; erros inesperados: ${other_errors:-0} (detalhes em $errlog)"
done

# --- 4. sobe o resto -------------------------------------------------------
log "Subindo todos os serviços"
for dir in "$STACK_DIR"/*/; do
  if [[ -f "$dir/compose.yaml" ]]; then
    (cd "$dir" && docker compose up -d)
  fi
done

# --- 5. configs do sistema para consulta -----------------------------------
if [[ -d "$WORK/etc" ]]; then
  cp -a "$WORK/etc" "/root/restore-etc-$STAMP"
  log "Configs do servidor antigo guardadas em /root/restore-etc-$STAMP (consulte, não aplique às cegas)."
fi

log "Pronto. Confira:  docker ps   e   docker compose logs --tail=50  em cada serviço."
