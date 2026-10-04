#!/usr/bin/env bash
# =============================================================================
# backup.sh — backup completo do servidor (stack + bancos PostgreSQL + configs)
#
# Uso:     sudo /opt/stack/scripts/backup.sh
# Agenda:  0 3 * * *  root  /opt/stack/scripts/backup.sh >> /var/log/backup.log 2>&1
#
# Variáveis (ambiente ou /etc/server-docs.env):
#   STACK_DIR              pasta dos serviços                   (padrão: /opt/stack)
#   BACKUP_DIR             onde guardar os arquivos             (padrão: /srv/backups)
#   RETENTION_DAYS         dias de retenção local               (padrão: 14)
#   RCLONE_REMOTE          destino rclone, ex.: backup-crypt:   (vazio = só local)
#   REMOTE_RETENTION_DAYS  dias de retenção na nuvem            (padrão: 60)
#   HC_PING_URL            URL do healthchecks.io (avisa início/sucesso/falha)
#
# Extensível: qualquer script executável em $STACK_DIR/scripts/backup.d/*.sh roda
# no meio do backup e pode gravar arquivos em "$WORK" (entram no pacote final).
# =============================================================================
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Rode como root (sudo)." >&2
  exit 1
fi

# shellcheck source=/dev/null
[[ -f /etc/server-docs.env ]] && source /etc/server-docs.env

STACK_DIR="${STACK_DIR:-/opt/stack}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
REMOTE_RETENTION_DAYS="${REMOTE_RETENTION_DAYS:-60}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
HC_PING_URL="${HC_PING_URL:-}"

HOST="$(hostname -s)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/${HOST}-${STAMP}.tar.gz"
WORK="$(mktemp -d)"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

ping_hc() {
  if [[ -n "$HC_PING_URL" ]]; then
    curl -fsS -m 10 --retry 3 -o /dev/null "${HC_PING_URL}${1:-}" || true
  fi
}

fail() {
  # stderr, para que a mensagem nunca vá parar dentro de uma substituição de processo
  log "ERRO na linha $1 — backup NÃO concluído" >&2
  ping_hc "/fail"
  exit 1
}

trap 'rm -rf "$WORK"' EXIT
trap 'fail $LINENO' ERR

# impede duas execuções ao mesmo tempo
exec 9> /var/lock/server-backup.lock
if ! flock -n 9; then
  log "Outro backup já está rodando. Saindo."
  exit 0
fi

ping_hc "/start"
mkdir -p "$WORK/db" "$WORK/etc" "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# ---------------------------------------------------------------------------
log "1/4  Dump dos bancos PostgreSQL"
HAVE_DOCKER=0
if command -v docker > /dev/null 2>&1; then
  if docker info > /dev/null 2>&1; then
    HAVE_DOCKER=1
  else
    log "Docker está instalado mas não responde (daemon parado?). Abortando para não gerar backup incompleto." >&2
    false
  fi
fi

PG_CONTAINERS=()
if ((HAVE_DOCKER)); then
  mapfile -t PG_CONTAINERS < <(docker ps --format '{{.Names}}\t{{.Image}}' | awk -F'\t' '$2 ~ /postgres/ {print $1}')
fi
if ((${#PG_CONTAINERS[@]} == 0)); then
  log "     nenhum container PostgreSQL rodando (normal se você não usa)"
fi
for c in "${PG_CONTAINERS[@]}"; do
  user="$(docker exec "$c" printenv POSTGRES_USER 2> /dev/null || echo postgres)"
  log "     -> $c (usuário $user)"
  docker exec "$c" pg_dumpall -U "$user" | gzip -9 > "$WORK/db/${c}.sql.gz"
done

if [[ -d "$STACK_DIR/scripts/backup.d" ]]; then
  for hook in "$STACK_DIR"/scripts/backup.d/*.sh; do
    [[ -x "$hook" ]] || continue
    log "     hook: $(basename "$hook")"
    WORK="$WORK" "$hook"
  done
fi

# ---------------------------------------------------------------------------
log "2/4  Compactando $STACK_DIR (sem os arquivos 'vivos' do Postgres: eles vão pelo dump)"
# código de saída 1 do tar = "algum arquivo mudou durante a leitura" (não é erro grave)
tar --warning=no-file-changed \
  --exclude='*/data/postgres' --exclude='*/node_modules' --exclude='*.log' \
  -czf "$WORK/stack.tar.gz" -C "$(dirname "$STACK_DIR")" "$(basename "$STACK_DIR")" || [[ $? -eq 1 ]]

# ---------------------------------------------------------------------------
log "3/4  Configurações do sistema (para consulta ao migrar)"
for p in /etc/netplan /etc/ssh/sshd_config.d /etc/ufw /etc/fail2ban/jail.local \
  /etc/docker/daemon.json /etc/fstab /etc/hosts /etc/cron.d /etc/server-docs.env \
  /etc/systemd/logind.conf.d /etc/apt/apt.conf.d/20auto-upgrades /etc/cloudflared; do
  if [[ -e "$p" ]]; then cp -a --parents "$p" "$WORK/etc/" || true; fi
done
crontab -l -u root > "$WORK/etc/crontab-root.txt" 2> /dev/null || true
dpkg --get-selections > "$WORK/etc/pacotes.txt"
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' > "$WORK/etc/docker-ps.txt" 2> /dev/null || true
docker images --digests --format '{{.Repository}}:{{.Tag}}\t{{.Digest}}' > "$WORK/etc/docker-images.txt" 2> /dev/null || true

# ---------------------------------------------------------------------------
log "4/4  Gerando $OUT"
tar -czf "$OUT" -C "$WORK" .
chmod 600 "$OUT"
(cd "$BACKUP_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")
log "     ok — $(du -h "$OUT" | cut -f1)"

# retenção local
find "$BACKUP_DIR" -maxdepth 1 -name "${HOST}-*.tar.gz*" -mtime +"$RETENTION_DAYS" -delete

# ---------------------------------------------------------------------------
if [[ -n "$RCLONE_REMOTE" ]]; then
  log "Enviando para $RCLONE_REMOTE"
  rclone copy "$OUT" "$RCLONE_REMOTE" --transfers 1 --retries 3
  rclone copy "$OUT.sha256" "$RCLONE_REMOTE" --transfers 1 --retries 3
  rclone delete "$RCLONE_REMOTE" --min-age "${REMOTE_RETENTION_DAYS}d" --include "${HOST}-*"
fi

log "Backup concluído."
ping_hc ""
