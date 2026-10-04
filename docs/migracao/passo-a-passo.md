# Migração: passo a passo

Método A (instalação limpa + restore). Tempo parado típico: de 30 a 60 minutos.
Marque cada etapa conforme avança.

## Fase 1 — Preparar a máquina nova (o servidor antigo continua no ar)

- [ ] Rode [Preparação](../instalacao/preparacao.md) e [Ubuntu Server](../instalacao/ubuntu-server.md) na máquina nova
  (use o mesmo nome de usuário do antigo para manter os donos dos arquivos iguais; o primeiro usuário é o `1000`).
- [ ] Use o **mesmo nome de máquina** se quiser manter tudo igual na documentação, ou um nome novo — mas então ajuste a documentação.
- [ ] Rode o [bootstrap](../instalacao/bootstrap.md) (sem `HARDEN_SSH` por enquanto), e depois copie sua chave SSH e rode de novo com `HARDEN_SSH=1`.
- [ ] Conecte o Tailscale **neste servidor novo** e ative *Disable key expiry*.
- [ ] No roteador: reserve um IP para o **MAC novo** (pode ser temporariamente outro número).

Neste momento a máquina nova está pronta e vazia. **Não suba o `cloudflared` com o token ainda.**

## Fase 2 — Ensaio (não derruba nada)

Faça um backup do antigo e restaure no novo **sem desligar o antigo**. Serve para descobrir problemas
com calma:

```bash
# no servidor ANTIGO
sudo /opt/stack/scripts/backup.sh
ls -lh /srv/backups | tail -3

# traga o arquivo para o NOVO (rode no novo)
rsync -avP SEU_USUARIO@ANTIGO:/srv/backups/NOME-AAAAMMDD-HHMMSS.tar.gz* ~/
```

Se os dois estiverem na mesma rede, o `rsync` serve. Pela internet, use a cópia da nuvem
(`rclone copy backup-crypt:... ~/`).

```bash
# no servidor NOVO
sudo /opt/stack/scripts/restore.sh ~/NOME-AAAAMMDD-HHMMSS.tar.gz
docker ps
docker compose -f /opt/stack/n8n/compose.yaml logs --tail=50 n8n
```

!!! warning "O ensaio já sobe os containers"
    O n8n novo, com os mesmos workflows, **também vai tentar rodar os agendamentos** (cron, bots).
    Se isso importa (envio de mensagens, cobranças), dê `docker compose stop n8n` no novo logo após
    o ensaio, ou faça o ensaio sem o `cloudflared`. Ele só começa a receber tráfego público quando o
    túnel dele estiver rodando.

Verifique no novo: abre o n8n por túnel SSH, os workflows estão lá, as credenciais **abrem** (isso prova que a chave de criptografia veio certa).

- [ ] Workflows aparecem
- [ ] Uma credencial abre sem erro
- [ ] Um workflow de teste roda (sem efeito colateral)

Se algo deu errado, **corrija agora**, no ensaio, não no dia da virada. Anote o que aprendeu no
[changelog](../referencia/changelog.md).

## Fase 3 — A virada

Escolha um horário de pouco uso. Do começo ao fim:

### 1. Congele o antigo

```bash
# no ANTIGO
for d in /opt/stack/*/; do [ -f "$d/compose.yaml" ] && (cd "$d" && docker compose stop); done
sudo /opt/stack/scripts/backup.sh          # backup final, com tudo parado e consistente
```

### 2. Traga o backup final

```bash
# no NOVO
rsync -avP SEU_USUARIO@ANTIGO:/srv/backups/NOME-AAAAMMDD-HHMMSS.tar.gz* ~/
sha256sum -c ~/NOME-AAAAMMDD-HHMMSS.tar.gz.sha256
```

### 3. Restaure

```bash
sudo /opt/stack/scripts/restore.sh ~/NOME-AAAAMMDD-HHMMSS.tar.gz
docker ps
```

### 4. Passe o tráfego

- [ ] **Desligue o `cloudflared` no antigo** (`docker compose stop` na pasta dele — já está parado se você parou tudo).
- [ ] Suba o túnel no novo: `docker compose up -d` em `/opt/stack/cloudflared` (o token veio no restore).
- [ ] Se usa IP fixo/reserva: atualize a reserva do roteador para o MAC novo, com o IP definitivo.
- [ ] Se o nome da interface mudou e o IP é fixo no sistema: ajuste o netplan (`ip -br link`; `sudo netplan try`).

### 5. Confirme

- [ ] `curl -i https://n8n.seudominio.com/healthz` responde `200`
- [ ] Um webhook real chega e o workflow roda
- [ ] `sudo /opt/stack/scripts/healthcheck.sh --verbose` sem problemas
- [ ] **Um backup novo** roda no servidor novo: `sudo /opt/stack/scripts/backup.sh`
- [ ] Conferiu que `RCLONE_REMOTE` e `HC_PING_URL` estão em `/etc/server-docs.env` no novo (copie do `etc/` do restore — fica em `/root/restore-etc-*`)

## Fase 4 — Depois

- [ ] Remova o aparelho antigo do painel do **Tailscale**
- [ ] Atualize o [inventário](../referencia/inventario.md) (`inventario.sh`) e o [changelog](../referencia/changelog.md)
- [ ] Mantenha o antigo **desligado, mas intacto**, por 1–2 semanas
- [ ] Depois: apague o disco com segurança antes de vender ou descartar (veja abaixo)

## Plano de volta (rollback)

Se algo der errado depois da virada e você precisar voltar:

1. Desligue o `cloudflared` na máquina nova.
2. Ligue o antigo, suba os containers (`docker compose up -d`) e o túnel dele.
3. O que o novo recebeu durante esse tempo (dados de execuções) pode se perder — por isso a janela é curta e o antigo fica intacto.

## Apagar o disco antigo antes de descartar

```bash
# boote por um pendrive Linux (modo Try) e identifique o disco com lsblk
sudo shred -vz -n 1 /dev/sdX            # HD comum
sudo nvme format /dev/nvme0n1 --ses=1   # SSD NVMe com suporte a apagamento seguro
```

!!! danger "Confira o dispositivo"
    Estes comandos apagam o disco. Errar o `/dev/sdX` apaga o disco errado.

## Método B (clonar o disco) — só se tiver certeza

Para máquinas muito parecidas e pouco tempo:

1. Boote **as duas** pelo Clonezilla (pendrive) e use *disk to disk* ou crie uma imagem e restaure.
2. Depois do primeiro boot na máquina nova: ajuste o netplan (nome da interface), confira o `fstab`
   (UUIDs), `sudo update-initramfs -u`, remova o aparelho antigo do Tailscale e reconecte.
3. Mesmo assim: rode `backup.sh` e `healthcheck.sh` no novo para confirmar que tudo funciona.
