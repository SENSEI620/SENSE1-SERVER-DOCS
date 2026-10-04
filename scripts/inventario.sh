#!/usr/bin/env bash
# =============================================================================
# inventario.sh — gera um inventário do servidor em Markdown (sem senhas).
#
# Uso:  sudo ./inventario.sh > inventario-privado.md
#
# ATENÇÃO: a saída contém IPs da sua rede local, MACs, nomes de containers e
# portas. REVISE antes de colar em qualquer lugar público.
# =============================================================================
set -uo pipefail

STACK_DIR="${STACK_DIR:-/opt/stack}"

section() { printf '\n## %s\n\n' "$1"; }
run() {
  printf '```text\n'
  bash -c "$1" 2>&1 || true
  printf '```\n'
}

printf '# Inventário de %s\n\nGerado em %s\n' "$(hostname)" "$(date '+%F %T %Z')"

section "Sistema"
run "hostnamectl; echo; uname -r; echo; uptime -p"

section "Hardware"
run "lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Virtualization'; echo; free -h; echo; dmidecode -s system-manufacturer 2>/dev/null; dmidecode -s system-product-name 2>/dev/null; dmidecode -s bios-version 2>/dev/null"

section "Discos"
run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL; echo; df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay"

section "Saúde dos discos (SMART)"
run "for d in \$(lsblk -dno NAME,TYPE | awk '\$2==\"disk\" {print \$1}'); do echo \"== /dev/\$d\"; smartctl -H /dev/\$d 2>/dev/null | grep -i 'overall-health\|SMART Health'; done"

section "Rede"
run "ip -br link; echo; ip -br addr; echo; ip route | head -5; echo; resolvectl status 2>/dev/null | grep -E 'DNS Servers|Link'"

section "Portas em escuta"
run "ss -tulpn | awk 'NR==1 || /LISTEN|UNCONN/'"

section "Firewall"
run "ufw status verbose"

section "Docker — containers"
run "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"

section "Docker — imagens"
run "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"

section "Serviços (pastas em $STACK_DIR)"
run "ls -la $STACK_DIR 2>/dev/null; echo; ls $STACK_DIR/*/compose.yaml 2>/dev/null"

section "Serviços systemd habilitados"
run "systemctl list-unit-files --state=enabled --type=service --no-legend | awk '{print \$1}'"

section "Agendamentos (cron)"
run "crontab -l 2>/dev/null; echo '--- /etc/cron.d'; cat /etc/cron.d/* 2>/dev/null"

section "Usuários com acesso privilegiado"
run "getent group sudo docker"

section "Acesso remoto"
run "systemctl is-active ssh tailscaled 2>/dev/null; tailscale status 2>/dev/null | head -5"
