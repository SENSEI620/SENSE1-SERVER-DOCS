# Troubleshooting

"Se X quebrar, faça Y". Clique no sintoma para abrir.

## Comece por aqui (30 segundos)

```bash
uptime && free -h && df -h /     # carga, memória, disco
docker ps                        # containers de pé?
systemctl --failed               # serviços com falha
journalctl -p err -b --no-pager | tail -30     # erros do sistema desde o último boot
```

## Acesso

??? failure "Não consigo entrar por SSH"
    1. **O servidor está ligado e na rede?** `ping IP_DO_SERVIDOR`. Sem resposta: cabo, roteador, energia.
    2. **O IP mudou?** Veja no painel do roteador a lista de dispositivos (e reserve o IP — veja [Rede](../instalacao/rede.md)).
    3. **`Connection refused`:** o SSH não está rodando ou o firewall bloqueou. No monitor/teclado: `sudo systemctl status ssh` e `sudo ufw status`.
    4. **`Permission denied (publickey)`:** a chave errada ou `authorized_keys` com permissão errada:
       `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`.
    5. **Fail2ban te baniu** (errou a senha várias vezes): `sudo fail2ban-client set sshd unbanip SEU_IP`.
    6. **Trancado depois de mexer no SSH ou no UFW:** só com monitor e teclado. Revise
       `/etc/ssh/sshd_config.d/` e `sudo ufw status`.

??? failure "Perdi o acesso remoto pelo Tailscale"
    Provavelmente a chave do servidor expirou. Em casa, rode `sudo tailscale up` de novo e, no painel
    do Tailscale, use **Disable key expiry** nesse aparelho.

??? failure "Depois de um reinício, o servidor não volta sozinho"
    - Queda de energia e ele ficou desligado: na BIOS, **After Power Loss = Power On**.
    - Parou na tela de senha do disco: ele foi instalado com criptografia (LUKS); veja [Instalação](../instalacao/ubuntu-server.md).
    - Pendrive de instalação esquecido na frente na ordem de boot: remova-o.

## Disco

??? failure "Disco cheio (`No space left on device`)"
    ```bash
    df -h                                              # qual partição?
    sudo du -xh / --max-depth=2 2>/dev/null | sort -rh | head -15
    sudo ncdu -x /                                     # navegar pelo uso
    docker system df                                   # Docker?
    sudo journalctl --disk-usage                       # logs do sistema?
    ```
    Causas comuns e saídas:

    - **Logs de container enormes:** configure o limite (`daemon.json`) e recrie os containers (`docker compose up -d --force-recreate`).
    - **Imagens antigas:** `docker image prune -a --filter "until=720h"`.
    - **Backups locais acumulados:** reduza `RETENTION_DAYS`.
    - **Volume LVM pequeno:** o instalador usa só parte do disco. Veja [a correção](../instalacao/ubuntu-server.md#corrija-o-tamanho-do-disco-importante).
    - **Logs do journal:** `sudo journalctl --vacuum-size=500M`.

??? failure "Disco com erros ou SMART falhando"
    ```bash
    sudo smartctl -a /dev/sda | less           # procure Reallocated, Pending, Uncorrectable
    sudo dmesg | grep -iE 'i/o error|ata[0-9]|nvme'
    ```
    Aumento de setores realocados ou pendentes = **o disco está morrendo**. Faça um backup
    **agora**, copie para fora do servidor e planeje a troca (veja [Migração](../migracao/visao-geral.md)).

## Containers

??? failure "Container reiniciando em loop"
    ```bash
    docker compose ps
    docker compose logs --tail=100 NOME
    docker inspect --format 'exit={{.State.ExitCode}} oom={{.State.OOMKilled}}' NOME_DO_CONTAINER
    ```
    - `oom=true`: falta de memória. Aumente `mem_limit`, reduza o uso ou adicione RAM/swap.
    - Erro de permissão em pasta de dados: ajuste o dono (`chown`) — o n8n usa o usuário 1000.
    - Variável do `.env` faltando ou com erro: `docker compose config` mostra o resultado final.

??? failure "PostgreSQL não sobe"
    ```bash
    docker compose logs --tail=50 postgres
    ```
    - `database files are incompatible with server`: mudou a versão **maior** da imagem (ex.: 15 → 16)
      sobre dados antigos. Volte à versão anterior ou faça dump/restore para a versão nova.
    - `could not write ... No space left`: disco cheio (veja acima).
    - `data directory has wrong ownership/permissions`: não mexa nessa pasta com `chown`/`chmod`
      por fora; se foi restaurada de um `tar` por outro usuário, rode o restore como `root`.

??? failure "Perdi a N8N_ENCRYPTION_KEY"
    Sem a chave, as credenciais salvas no n8n **não podem ser lidas**. Procure em ordem: o `.env` do
    servidor, o gerenciador de senhas, o pacote de backup (`stack.tar.gz` → `stack/n8n/.env`).
    Se não existir em lugar nenhum, os workflows continuam, mas você precisará recriar as
    credenciais (tokens, senhas de API) uma a uma.

??? failure "Webhook do n8n não recebe nada"
    1. O túnel está de pé? `docker compose -f /opt/stack/cloudflared/compose.yaml logs --tail=30`.
    2. O hostname no Cloudflare aponta para `n8n:5678`? E o `WEBHOOK_URL` está com `https` e `/` no fim?
    3. O workflow está **ativado**? (A URL de teste só funciona no modo de teste.)
    4. Teste de fora: `curl -i https://n8n.seudominio.com/healthz`.

??? failure "Não consigo baixar imagens (`pull`)"
    ```bash
    ping -c3 1.1.1.1
    getent hosts registry-1.docker.io
    ```
    Sem ping: internet fora. Ping sim, nome não: DNS (veja [Rede](../instalacao/rede.md#se-o-docker-nao-baixa-imagens-dns)).

## Desempenho e hardware

??? failure "Servidor lento ou carga alta"
    ```bash
    htop                       # F6 ordena por CPU/MEM
    docker stats --no-stream
    sudo iotop -oPa            # (apt install iotop) quem usa o disco
    ```
    - Memória cheia e swap em uso intenso: algum container consome demais.
    - `wa` (I/O wait) alto no `top`: disco lento ou morrendo.
    - Temperatura alta (`sensors`): limpe o ventilador e as saídas de ar; troque a pasta térmica (máquina antiga).

??? failure "Hora do servidor errada"
    ```bash
    timedatectl
    sudo timedatectl set-ntp true
    ```
    Hora errada quebra HTTPS, tokens e agendamentos. Confira o fuso: `sudo timedatectl set-timezone America/Sao_Paulo`.

??? failure "Disco com erro ao ligar (tela preta ou `initramfs`)"
    Pode ser sistema de arquivos corrompido depois de queda de energia. Boote pelo pendrive do
    instalador (modo *Try*), e rode `fsck` no volume (`sudo fsck -f /dev/ubuntu-vg/ubuntu-lv` — com
    o volume **desmontado**). Se o disco estiver falhando, não insista: restaure o backup num disco novo.
    **Nobreak** evita a maior parte desses casos.

## Última opção

Se nada resolve e o servidor não é recuperável: reinstale seguindo [Instalação](../instalacao/preparacao.md)
e use o [restore](backup.md#restaurar). É para isso que o backup existe.
