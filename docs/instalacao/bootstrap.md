# 5. Script de bootstrap (tudo de uma vez)

O `bootstrap.sh` aplica de uma vez o que as páginas anteriores explicam passo a passo: atualização,
pacotes, firewall, fail2ban, atualizações automáticas, Docker, pasta `/opt/stack`, scripts de operação
e agendamento de backup e healthcheck. Ele é **idempotente**: pode rodar de novo sem estragar nada.

## Como usar

Leve a pasta `scripts/` para o servidor — por Git ou por cópia direta:

=== "Via Git"

    ```bash
    sudo apt update && sudo apt install -y git
    git clone https://github.com/SEU_USUARIO/NOME_DO_REPO.git ~/servidor-docs
    cd ~/servidor-docs
    ```

=== "Via scp (do seu computador)"

    ```bash
    scp -r scripts SEU_USUARIO@IP_DO_SERVIDOR:~/
    ssh SEU_USUARIO@IP_DO_SERVIDOR
    cd ~
    ```

Depois rode:

```bash
sudo NEW_HOSTNAME=lenovo-srv LAN_CIDR=192.168.1.0/24 bash scripts/bootstrap.sh
```

Sem `HARDEN_SSH`, o login por senha continua ligado. Depois de copiar sua chave
(veja [Pós-instalação](pos-instalacao.md#3-entrar-por-chave-ssh-no-seu-computador)), rode de novo:

```bash
sudo HARDEN_SSH=1 LAN_CIDR=192.168.1.0/24 bash scripts/bootstrap.sh
```

!!! success "Proteção contra se trancar fora"
    Com `HARDEN_SSH=1`, o script **só** desliga a senha se o seu usuário já tiver uma chave em
    `~/.ssh/authorized_keys`. Se não tiver, ele avisa e pula esse passo.

## Variáveis

| Variável | Padrão | O que faz |
|---|---|---|
| `NEW_HOSTNAME` | *(não altera)* | Define o nome da máquina |
| `TZ_NAME` | `America/Sao_Paulo` | Fuso horário |
| `ADMIN_USER` | quem chamou o `sudo` | Usuário que entra no grupo `docker` |
| `LAN_CIDR` | *(vazio)* | Se definido, o SSH só é aceito dessa rede (ex.: `192.168.1.0/24`) |
| `HARDEN_SSH` | `0` | `1` = desliga a senha no SSH (exige chave) |
| `STACK_DIR` | `/opt/stack` | Pasta dos serviços |
| `BACKUP_DIR` | `/srv/backups` | Pasta dos backups locais |
| `INSTALL_CRON` | `1` | Agenda backup (03:00) e healthcheck (a cada 15 min) |

## Depois de rodar

1. Saia e entre de novo no SSH, para o grupo `docker` valer.
2. Teste: `docker run --rm hello-world`.
3. Edite `/etc/server-docs.env` para configurar envio de backup à nuvem e alertas
   (veja [Backup](../operacao/backup.md) e [Monitoramento](../operacao/monitoramento.md)).
4. Se mexeu em kernel ou rede, reinicie: `sudo reboot`.

## O script

O código abaixo é o arquivo `scripts/bootstrap.sh` do repositório, incluído automaticamente.
Leia antes de rodar: nunca execute com `sudo` um script que você não entendeu.

```bash title="scripts/bootstrap.sh"
--8<-- "scripts/bootstrap.sh"
```
