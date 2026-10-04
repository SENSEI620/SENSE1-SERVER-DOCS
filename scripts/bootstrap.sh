#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — configuração inicial de um servidor Ubuntu/Debian recém-instalado
#
# Uso:    sudo bash bootstrap.sh
# É idempotente: pode rodar de novo sem quebrar nada.
#
# Variáveis opcionais (passe antes do comando, ex.: sudo HARDEN_SSH=1 bash bootstrap.sh):
#   NEW_HOSTNAME   novo nome da máquina                      (padrão: não altera)
#   TZ_NAME        fuso horário                               (padrão: America/Sao_Paulo)
#   ADMIN_USER     usuário administrador                      (padrão: quem chamou o sudo)
#   LAN_CIDR       rede local; se definido, SSH só dela       (ex.: 192.168.1.0/24)
#   HARDEN_SSH     1 = desliga senha no SSH (exige chave)     (padrão: 0)
#   STACK_DIR      pasta dos serviços                         (padrão: /opt/stack)
#   BACKUP_DIR     pasta dos backups locais                   (padrão: /srv/backups)
#   INSTALL_CRON   1 = agenda backup e healthcheck            (padrão: 1)
# =============================================================================
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Rode com sudo:  sudo bash $0" >&2
  exit 1
fi

NEW_HOSTNAME="${NEW_HOSTNAME:-}"
TZ_NAME="${TZ_NAME:-America/Sao_Paulo}"
ADMIN_USER="${ADMIN_USER:-${SUDO_USER:-}}"
LAN_CIDR="${LAN_CIDR:-}"
HARDEN_SSH="${HARDEN_SSH:-0}"
STACK_DIR="${STACK_DIR:-/opt/stack}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"
INSTALL_CRON="${INSTALL_CRON:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export DEBIAN_FRONTEND=noninteractive

log() { printf '\n\033[1;36m[bootstrap]\033[0m %s\n' "$*"; }

if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "root" ]]; then
  echo "Não consegui descobrir o usuário administrador. Rode com: sudo ADMIN_USER=seuusuario bash $0" >&2
  exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
case "$ID" in
  ubuntu | debian) DOCKER_DISTRO="$ID" ;;
  *) echo "Distribuição não suportada: $ID (use Ubuntu ou Debian)" >&2; exit 1 ;;
esac
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

# ---------------------------------------------------------------------------
log "1/9  Atualizando o sistema"
apt-get update -y
apt-get full-upgrade -y

# ---------------------------------------------------------------------------
log "2/9  Nome, fuso horário e pacotes essenciais"
[[ -n "$NEW_HOSTNAME" ]] && hostnamectl set-hostname "$NEW_HOSTNAME"
timedatectl set-timezone "$TZ_NAME"
apt-get install -y \
  curl wget git htop ncdu tmux vim unzip rsync jq \
  ufw fail2ban unattended-upgrades \
  smartmontools lm-sensors ethtool net-tools dnsutils \
  ca-certificates gnupg

# ---------------------------------------------------------------------------
log "3/9  Firewall (UFW)"
ufw default deny incoming
ufw default allow outgoing
if [[ -n "$LAN_CIDR" ]]; then
  ufw allow from "$LAN_CIDR" to any port 22 proto tcp
else
  ufw allow OpenSSH
fi
ufw --force enable

# ---------------------------------------------------------------------------
log "4/9  fail2ban (proteção contra tentativas de senha no SSH)"
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# ---------------------------------------------------------------------------
log "5/9  Atualizações automáticas de segurança"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# ---------------------------------------------------------------------------
log "6/9  SSH"
if [[ "$HARDEN_SSH" == "1" ]]; then
  admin_home="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  if [[ -s "$admin_home/.ssh/authorized_keys" ]]; then
    # Nome 00-: no sshd o PRIMEIRO valor lido vence, e o cloud-init cria um 50-cloud-init.conf
    cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
EOF
    sshd -t
    systemctl reload ssh 2>/dev/null || systemctl restart ssh
    log "     SSH endurecido: login só com chave. Confira: sudo sshd -T | grep -i passwordauth"
  else
    log "     HARDEN_SSH=1 IGNORADO: $ADMIN_USER não tem chave em ~/.ssh/authorized_keys (você ficaria trancado fora)."
    log "     Copie sua chave com 'ssh-copy-id' e rode de novo."
  fi
else
  log "     Mantido login por senha. Depois de copiar sua chave, rode de novo com HARDEN_SSH=1."
fi

# ---------------------------------------------------------------------------
log "7/9  Notebook: não suspender ao fechar a tampa"
if [[ "$(hostnamectl chassis 2>/dev/null || true)" == "laptop" ]] || compgen -G "/sys/class/power_supply/BAT*" > /dev/null; then
  mkdir -p /etc/systemd/logind.conf.d
  cat > /etc/systemd/logind.conf.d/10-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
  systemctl kill -s HUP systemd-logind || true
else
  log "     Não parece ser notebook — nada a fazer."
fi

# ---------------------------------------------------------------------------
log "8/9  Docker + pasta $STACK_DIR"
if ! command -v docker > /dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$DOCKER_DISTRO/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$DOCKER_DISTRO
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if [[ ! -f /etc/docker/daemon.json ]]; then
  # evita que os logs dos containers encham o disco
  cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  systemctl restart docker
fi
systemctl enable --now docker
usermod -aG docker "$ADMIN_USER"

docker network inspect proxy > /dev/null 2>&1 || docker network create proxy > /dev/null

mkdir -p "$STACK_DIR/scripts" "$BACKUP_DIR"
chown -R "$ADMIN_USER":"$ADMIN_USER" "$STACK_DIR"
chmod 700 "$BACKUP_DIR"

# ---------------------------------------------------------------------------
log "9/9  Scripts de operação, configuração e agendamentos"
scripts_ok=0
for f in backup.sh restore.sh healthcheck.sh inventario.sh; do
  if [[ -f "$SCRIPT_DIR/$f" ]]; then
    install -m 0755 "$SCRIPT_DIR/$f" "$STACK_DIR/scripts/$f"
    scripts_ok=1
  fi
done

if [[ ! -f /etc/server-docs.env ]]; then
  cat > /etc/server-docs.env <<EOF
# Configuração lida pelos scripts de backup e healthcheck. NÃO versionar.
STACK_DIR=$STACK_DIR
BACKUP_DIR=$BACKUP_DIR
RETENTION_DAYS=14
# RCLONE_REMOTE=backup-crypt:
# HC_PING_URL=https://hc-ping.com/seu-uuid
# ALERT_WEBHOOK=https://n8n.seudominio.com/webhook/alerta-servidor
EOF
  chmod 600 /etc/server-docs.env
fi

if [[ "$INSTALL_CRON" == "1" && "$scripts_ok" == "1" ]]; then
  cat > /etc/cron.d/server-docs <<EOF
# Gerado pelo bootstrap.sh
0 3 * * *    root $STACK_DIR/scripts/backup.sh      >> /var/log/backup.log 2>&1
*/15 * * * * root $STACK_DIR/scripts/healthcheck.sh >> /var/log/healthcheck.log 2>&1
EOF
  chmod 644 /etc/cron.d/server-docs
  cat > /etc/logrotate.d/server-docs <<'EOF'
/var/log/backup.log /var/log/healthcheck.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
}
EOF
fi

# ---------------------------------------------------------------------------
cat <<EOF

============================================================
 Pronto!  Próximos passos:
  1. Saia e entre de novo no SSH (para o grupo 'docker' valer).
  2. Teste:           docker run --rm hello-world
  3. Sirva serviços:  veja "Serviços" na documentação ($STACK_DIR/<serviço>/compose.yaml)
  4. Configure o envio de backups para a nuvem em /etc/server-docs.env
  5. Se algo mexeu em kernel/rede, reinicie:  sudo reboot
============================================================
EOF
