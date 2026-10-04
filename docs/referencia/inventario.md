# Inventário

O mapa do seu servidor: o que existe, onde está e como mexer. Preencha o modelo abaixo
(**sem senhas e sem IP público**) e mantenha atualizado.

!!! warning "Dados reais ficam fora do site público"
    O `inventario.sh` gera um relatório com IPs da rede local, MACs, portas e nomes de containers.
    Salve em `inventario-privado.md` (que o `.gitignore` ignora) e **não** cole aqui sem revisar.

## Gerar o inventário automático

```bash
sudo /opt/stack/scripts/inventario.sh > ~/inventario-privado.md
less ~/inventario-privado.md
```

Use a saída para preencher as tabelas abaixo com os dados que forem seguros de publicar.

## Modelo para preencher

### Hardware

| Item | Valor |
|---|---|
| Equipamento | *(modelo do Lenovo)* |
| CPU | |
| Memória | |
| Disco(s) | *(tipo, tamanho, data de instalação)* |
| Nobreak | *(sim/não e modelo)* |
| Local físico | *(onde fica; ventilação)* |
| Data de aquisição / idade | |

### Rede

| Item | Valor |
|---|---|
| Nome da máquina | `lenovo-srv` |
| IP local | `192.168.1.50` *(reservado no roteador)* |
| Interface | `enp3s0` |
| Wake-on-LAN | sim / não |
| Acesso remoto | Tailscale (nome da máquina: `lenovo-srv`) |
| Acesso público | Cloudflare Tunnel → `n8n.seudominio.com` *(domínio opcional aqui)* |

### Serviços

| Serviço | Pasta | Imagem / versão | Porta (local) | Dados | Observações |
|---|---|---|---|---|---|
| n8n | `/opt/stack/n8n` | `n8n` / `latest` | `127.0.0.1:5678` | `data/n8n`, PostgreSQL | Chave em gerenciador de senhas |
| PostgreSQL | `/opt/stack/n8n` | `postgres:16-alpine` | interna | `data/postgres` | Backup via dump |
| cloudflared | `/opt/stack/cloudflared` | `cloudflared` | — | — | Token em gerenciador de senhas |

### Onde estão os segredos (apenas o lugar, nunca o valor)

| Segredo | Onde está guardado |
|---|---|
| Senha do usuário do servidor | Gerenciador de senhas → item *Servidor / usuário* |
| `N8N_ENCRYPTION_KEY` | Gerenciador de senhas → item *n8n* |
| Senha do PostgreSQL | `.env` do n8n + gerenciador de senhas |
| Token do Cloudflare Tunnel | Gerenciador de senhas → item *Cloudflare* |
| `rclone.conf` e senhas do crypt | Gerenciador de senhas → item *rclone / backups* |
| Chave SSH privada | Só no seu computador (com senha) |

### Rotinas

| O quê | Quando | Onde |
|---|---|---|
| Backup | Todo dia 03:00 | `/etc/cron.d/server-docs` |
| Healthcheck | A cada 15 min | `/etc/cron.d/server-docs` |
| Atualização de segurança | Automática | unattended-upgrades |
| Atualização geral e testes | Todo mês | [Atualizações](../operacao/atualizacoes.md) |

## O script

??? abstract "inventario.sh"

    ```bash title="scripts/inventario.sh"
    --8<-- "scripts/inventario.sh"
    ```
