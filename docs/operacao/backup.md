# Backup e restauração

## A regra 3-2-1

- **3** cópias dos dados (a original + duas)
- em **2** tipos de mídia diferentes (o disco do servidor + a nuvem, por exemplo)
- **1** fora de casa

!!! warning "RAID não é backup"
    Dois discos espelhados protegem contra um disco morrer, não contra você apagar algo, um erro
    de atualização, ransomware ou um raio.

## O que entra no backup

| O quê | Como | Onde fica no pacote |
|---|---|---|
| Pasta `/opt/stack` inteira (compose, `.env`, dados) | `tar` | `stack.tar.gz` |
| Bancos PostgreSQL | `pg_dumpall` (consistente, com o banco ligado) | `db/*.sql.gz` |
| Configurações do sistema (netplan, UFW, cron, fstab…) | cópia para consulta | `etc/` |
| Lista de pacotes e de imagens Docker | texto | `etc/` |

O arquivo final se chama `NOME-AAAAMMDD-HHMMSS.tar.gz` (mais um `.sha256` ao lado).

!!! danger "O pacote contém seus segredos"
    Dentro do `stack.tar.gz` estão os `.env`. Por isso o arquivo é `chmod 600` e **só vai para a
    nuvem criptografado** (veja abaixo). O mesmo vale para qualquer pendrive ou HD externo.

## Como funciona o agendamento

O bootstrap cria `/etc/cron.d/server-docs`:

```text
0 3 * * *    root /opt/stack/scripts/backup.sh      >> /var/log/backup.log 2>&1
*/15 * * * * root /opt/stack/scripts/healthcheck.sh >> /var/log/healthcheck.log 2>&1
```

Para rodar na hora: `sudo /opt/stack/scripts/backup.sh`. Para acompanhar: `tail -f /var/log/backup.log`.

Configurações em `/etc/server-docs.env`:

| Variável | Padrão | Significado |
|---|---|---|
| `BACKUP_DIR` | `/srv/backups` | Pasta dos backups locais |
| `RETENTION_DAYS` | `14` | Dias mantidos no servidor |
| `RCLONE_REMOTE` | *(vazio)* | Destino na nuvem (vazio = só local) |
| `REMOTE_RETENTION_DAYS` | `60` | Dias mantidos na nuvem |
| `HC_PING_URL` | *(vazio)* | Healthchecks.io avisa se o backup **não** rodar |

## Enviar para a nuvem, criptografado

Usamos o [rclone](https://rclone.org) com um destino do tipo **crypt**: o arquivo é criptografado
antes de sair do servidor.

```bash
sudo apt install -y rclone
sudo rclone config
```

No assistente (como `sudo`, porque o cron roda como *root*):

1. **n** (novo) → nome `nuvem` → escolha seu provedor (Google Drive, OneDrive, Backblaze B2…) e autentique.
2. **n** (novo) → nome `backup-crypt` → tipo **crypt** → remote: `nuvem:backups-servidor`.
3. Crie as duas senhas de criptografia (a de arquivos e a de nomes) — **guarde as duas no gerenciador de senhas**.

Depois, em `/etc/server-docs.env`:

```bash
RCLONE_REMOTE=backup-crypt:
```

Teste:

```bash
sudo /opt/stack/scripts/backup.sh
sudo rclone ls backup-crypt:
```

!!! danger "Guarde o `rclone.conf` e as senhas fora do servidor"
    O arquivo `/root/.config/rclone/rclone.conf` tem o acesso à nuvem e as senhas do crypt. Se o
    servidor morrer e você não tiver isso em outro lugar, **os backups da nuvem viram lixo
    ilegível**. Guarde uma cópia no gerenciador de senhas.

## Ser avisado quando o backup falha (ou não roda)

O pior backup é o que parou de rodar sem ninguém notar. Crie um monitor grátis no
[healthchecks.io](https://healthchecks.io) com período de 1 dia e tolerância de poucas horas, e
coloque a URL do monitor em `HC_PING_URL`. O script avisa início, sucesso e falha; se o servidor
sumir, é a **ausência** do aviso que dispara o alerta.

## Restaurar

=== "Tudo (servidor novo ou desastre)"

    ```bash
    # 1. instale o sistema e rode o bootstrap (veja Instalação)
    # 2. traga o pacote (da nuvem ou de um HD)
    rclone copy backup-crypt:NOME-20260101-030000.tar.gz ~/
    rclone copy backup-crypt:NOME-20260101-030000.tar.gz.sha256 ~/

    # 3. restaure
    sudo /opt/stack/scripts/restore.sh ~/NOME-20260101-030000.tar.gz
    ```

    O script confere o checksum, pede que você digite `RESTAURAR`, recoloca `/opt/stack`, sobe os
    containers PostgreSQL, carrega os dumps e sobe o resto. Erros "already exists" durante a
    carga do banco são normais.

=== "Só um arquivo"

    ```bash
    mkdir -p /tmp/restore && cd /tmp/restore
    tar -xzf ~/NOME-20260101-030000.tar.gz ./stack.tar.gz
    tar -tzf stack.tar.gz | grep 'n8n/.env'                 # descubra o caminho
    tar -xzf stack.tar.gz stack/n8n/.env                    # extrai só ele
    ```

=== "Só um banco"

    ```bash
    mkdir -p /tmp/restore && cd /tmp/restore
    tar -xzf ~/NOME-20260101-030000.tar.gz ./db
    gunzip -c db/n8n-postgres-1.sql.gz | docker exec -i n8n-postgres-1 psql -U n8n -d postgres
    ```

    Pare o serviço que usa o banco antes (`docker compose stop n8n`) e suba de novo depois.

## Teste a restauração (todo mês)

Um backup que nunca foi restaurado é só uma esperança. Todo mês:

- [ ] `sha256sum -c` no arquivo mais recente
- [ ] `tar -tzf` lista o conteúdo sem erro
- [ ] A cópia da nuvem baixa e descriptografa
- [ ] **A cada 3 meses:** restaurar num computador ou máquina virtual qualquer e abrir o n8n com seus workflows

## Os scripts

??? abstract "backup.sh"

    ```bash title="scripts/backup.sh"
    --8<-- "scripts/backup.sh"
    ```

??? abstract "restore.sh"

    ```bash title="scripts/restore.sh"
    --8<-- "scripts/restore.sh"
    ```
