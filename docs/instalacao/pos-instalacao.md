# 3. Pós-instalação e segurança

Esta página explica cada passo e o porquê. Se preferir não digitar nada, o
[script de bootstrap](bootstrap.md) faz tudo isto de uma vez.

## 1. Atualizar tudo

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot        # se atualizou o kernel
```

## 2. Nome, fuso horário e pacotes

```bash
sudo hostnamectl set-hostname lenovo-srv
sudo timedatectl set-timezone America/Sao_Paulo
timedatectl                       # procure: System clock synchronized: yes

sudo apt install -y curl wget git htop ncdu tmux vim unzip rsync jq \
  ufw fail2ban unattended-upgrades smartmontools lm-sensors ethtool net-tools dnsutils
```

| Pacote | Para quê |
|---|---|
| `htop`, `ncdu` | Ver processos e descobrir o que está ocupando disco |
| `tmux` | Sessão que continua rodando se o SSH cair |
| `ufw`, `fail2ban` | Firewall e bloqueio de quem tenta adivinhar senha |
| `smartmontools`, `lm-sensors` | Saúde do disco e temperatura |
| `rsync`, `jq` | Copiar arquivos e ler JSON |

## 3. Entrar por chave SSH (no seu computador)

=== "Linux / macOS"

    ```bash
    ssh-keygen -t ed25519 -C "meu-computador"
    ssh-copy-id SEU_USUARIO@IP_DO_SERVIDOR
    ```

=== "Windows (PowerShell)"

    ```powershell
    ssh-keygen -t ed25519 -C "meu-computador"
    type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh SEU_USUARIO@IP_DO_SERVIDOR "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    ```

Teste: `ssh SEU_USUARIO@IP_DO_SERVIDOR` deve entrar **sem pedir a senha do servidor**.

Para digitar menos, crie `~/.ssh/config` no seu computador:

```text
Host lenovo
    HostName 192.168.1.50
    User SEU_USUARIO
    IdentityFile ~/.ssh/id_ed25519
```

Depois basta `ssh lenovo`.

## 4. Desligar a senha no SSH

!!! warning "Mantenha uma sessão aberta enquanto testa"
    Só feche a janela atual depois de confirmar, em **outra janela**, que o login por chave funciona.
    Se errar aqui, você só volta com monitor e teclado.

```bash
sudo tee /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
EOF

sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -Ei 'passwordauthentication|permitrootlogin|maxauthtries'
```

!!! info "Por que o arquivo começa com 00-"
    No SSH, **o primeiro valor lido vence**, e os arquivos de `sshd_config.d` são lidos em ordem
    alfabética. O Ubuntu costuma ter um `50-cloud-init.conf` com `PasswordAuthentication yes`;
    se o seu arquivo fosse `99-...`, perderia. O comando `sshd -T` mostra o valor que vale de verdade.

## 5. Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
# ou, só a sua rede local:  sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw enable
sudo ufw status verbose
```

!!! danger "O Docker ignora o UFW"
    Portas publicadas por containers (`ports: "8080:8080"`) passam **por fora** das regras do UFW.
    Por isso, nesta documentação, todo serviço publica a porta em `127.0.0.1` (só o próprio
    servidor enxerga) e o acesso externo vem por túnel. Veja [Docker](../servicos/docker.md).

## 6. fail2ban

```bash
sudo tee /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
EOF
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## 7. Atualizações automáticas de segurança

```bash
sudo tee /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
```

Só correções de segurança entram sozinhas, e o servidor **não reinicia sozinho**.
Quando houver o arquivo `/var/run/reboot-required`, reinicie numa hora conveniente.

## 8. Se o Lenovo for notebook

Para não suspender ao fechar a tampa:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl kill -s HUP systemd-logind
```

Notebook ligado 24 horas na tomada: mantenha as saídas de ar limpas e, se a BIOS permitir,
limite a carga da bateria a 60–80%.

## 9. Saúde do disco

```bash
lsblk -d -o NAME,SIZE,MODEL               # nome do disco (ex.: sda ou nvme0n1)
sudo smartctl -H /dev/sda                 # esperado: PASSED
sudo systemctl enable --now smartmontools
```

## Checklist final

- [ ] Sistema atualizado e com o horário certo
- [ ] Login por chave funcionando em outra janela
- [ ] Senha do SSH desligada (`sshd -T` confirma)
- [ ] `ufw status` mostra **active**
- [ ] `fail2ban-client status sshd` responde
- [ ] `smartctl -H` mostra **PASSED**

Próximo passo: [rede e acesso remoto](rede.md).
