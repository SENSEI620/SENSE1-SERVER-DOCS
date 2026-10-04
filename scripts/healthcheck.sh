#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh — verifica a saúde do servidor e avisa só quando há problema
#
# Uso:     /opt/stack/scripts/healthcheck.sh [--verbose]
# Agenda:  */15 * * * *  root  /opt/stack/scripts/healthcheck.sh >> /var/log/healthcheck.log 2>&1
#
# Variáveis (ambiente ou /etc/server-docs.env):
#   DISK_WARN            % de uso de disco que gera alerta        (padrão: 85)
#   MEM_WARN             % de memória em uso que gera alerta      (padrão: 90)
#   TEMP_WARN            temperatura máxima em °C                 (padrão: 85)
#   BACKUP_DIR           onde procurar o último backup            (padrão: /srv/backups)
#   BACKUP_MAX_AGE_H     idade máxima do último backup, em horas  (padrão: 36)
#   PING_TARGET          alvo para testar a internet              (padrão: 1.1.1.1)
#   ALERT_WEBHOOK        URL que recebe o alerta (ex.: webhook do n8n)
#   ALERT_COOLDOWN_MIN   minutos sem repetir o mesmo alerta       (padrão: 360)
# =============================================================================
set -uo pipefail

# shellcheck source=/dev/null
[[ -f /etc/server-docs.env ]] && source /etc/server-docs.env

DISK_WARN="${DISK_WARN:-85}"
MEM_WARN="${MEM_WARN:-90}"
TEMP_WARN="${TEMP_WARN:-85}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"
BACKUP_MAX_AGE_H="${BACKUP_MAX_AGE_H:-36}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_COOLDOWN_MIN="${ALERT_COOLDOWN_MIN:-360}"
STATE=/var/tmp/healthcheck.state
HOST="$(hostname -s)"
VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

PROBLEMS=()
say() { ((VERBOSE)) && printf '%s\n' "$*"; return 0; }

# 1. disco ------------------------------------------------------------------
while read -r pct mount; do
  say "disco $mount: ${pct}%"
  ((pct >= DISK_WARN)) && PROBLEMS+=("Disco $mount com ${pct}% de uso")
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 {gsub("%","",$5); print $5, $6}')

# 2. memória ----------------------------------------------------------------
mem_pct="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%d", (1-a/t)*100}' /proc/meminfo)"
say "memória: ${mem_pct}%"
((mem_pct >= MEM_WARN)) && PROBLEMS+=("Memória com ${mem_pct}% de uso")

# 3. carga ------------------------------------------------------------------
cores="$(nproc)"
load1="$(cut -d' ' -f1 /proc/loadavg)"
say "carga (1 min): $load1 em $cores núcleos"
if awk -v l="$load1" -v c="$cores" 'BEGIN {exit !(l > c*2)}'; then
  PROBLEMS+=("Carga alta: $load1 em $cores núcleos")
fi

# 4. temperatura ------------------------------------------------------------
max_temp=0
for z in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "$z" ]] || continue
  t=$(($(cat "$z") / 1000))
  ((t > max_temp)) && max_temp=$t
done
say "temperatura máxima: ${max_temp}°C"
((max_temp >= TEMP_WARN)) && PROBLEMS+=("Temperatura em ${max_temp}°C")

# 5. SMART dos discos -------------------------------------------------------
if command -v smartctl > /dev/null 2>&1; then
  for d in $(lsblk -dno NAME,TYPE | awk '$2=="disk" {print $1}'); do
    out="$(smartctl -H "/dev/$d" 2> /dev/null || true)"
    if grep -q 'overall-health' <<< "$out"; then
      say "SMART /dev/$d: $(grep -o 'PASSED\|FAILED[^ ]*' <<< "$out" | head -1)"
      grep -q 'PASSED' <<< "$out" || PROBLEMS+=("SMART do disco /dev/$d NÃO está PASSED")
    fi
  done
fi

# 6. containers Docker ------------------------------------------------------
if command -v docker > /dev/null 2>&1; then
  while IFS='|' read -r name state status; do
    [[ -z "$name" ]] && continue
    [[ "$state" == "running" ]] && continue
    [[ "$state" == "exited" && "$status" == "Exited (0)"* ]] && continue
    PROBLEMS+=("Container $name: $status")
  done < <(docker ps -a --filter label=com.docker.compose.project --format '{{.Names}}|{{.State}}|{{.Status}}' 2> /dev/null)

  while read -r name; do
    [[ -n "$name" ]] && PROBLEMS+=("Container $name está unhealthy")
  done < <(docker ps --filter health=unhealthy --format '{{.Names}}' 2> /dev/null)
fi

# 7. serviços do systemd com falha -----------------------------------------
while read -r unit; do
  [[ -n "$unit" ]] && PROBLEMS+=("Serviço systemd com falha: $unit")
done < <(systemctl --failed --no-legend --plain 2> /dev/null | awk '{print $1}')

# 8. idade do último backup -------------------------------------------------
if [[ -d "$BACKUP_DIR" ]]; then
  last="$(find "$BACKUP_DIR" -maxdepth 1 -name "${HOST}-*.tar.gz" -printf '%T@\n' 2> /dev/null | sort -n | tail -1)"
  if [[ -z "$last" ]]; then
    PROBLEMS+=("Nenhum backup encontrado em $BACKUP_DIR")
  else
    age_h=$((($(date +%s) - ${last%.*}) / 3600))
    say "último backup: há ${age_h}h"
    ((age_h > BACKUP_MAX_AGE_H)) && PROBLEMS+=("Último backup tem ${age_h}h (limite ${BACKUP_MAX_AGE_H}h)")
  fi
fi

# 9. internet ---------------------------------------------------------------
if ! ping -c1 -W3 "$PING_TARGET" > /dev/null 2>&1; then
  PROBLEMS+=("Sem resposta de $PING_TARGET (internet fora?)")
fi

# 10. informativo -----------------------------------------------------------
[[ -f /var/run/reboot-required ]] && say "aviso: reinício pendente (atualização de kernel/bibliotecas)"

# --- alertas ----------------------------------------------------------------
send_alert() {
  local msg="$1"
  logger -t healthcheck "$msg"
  printf '[%s] %s\n' "$(date '+%F %T')" "$msg"
  if [[ -n "$ALERT_WEBHOOK" ]]; then
    curl -fsS -m 10 --data-urlencode "host=$HOST" --data-urlencode "message=$msg" \
      "$ALERT_WEBHOOK" > /dev/null || true
  fi
}

now="$(date +%s)"
if ((${#PROBLEMS[@]} > 0)); then
  msg="[$HOST] ${#PROBLEMS[@]} problema(s):"
  for p in "${PROBLEMS[@]}"; do msg+=$'\n'"- $p"; done
  hash="$(printf '%s' "$msg" | sha1sum | cut -d' ' -f1)"
  last_hash=""
  last_ts=0
  [[ -f "$STATE" ]] && read -r last_hash last_ts < "$STATE"
  if [[ "$hash" != "$last_hash" ]] || ((now - ${last_ts:-0} > ALERT_COOLDOWN_MIN * 60)); then
    send_alert "$msg"
    echo "$hash $now" > "$STATE"
  fi
  exit 1
fi

if [[ -s "$STATE" ]]; then
  send_alert "✅ [$HOST] tudo normalizado"
  : > "$STATE"
fi
say "tudo certo."
exit 0
