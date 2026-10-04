# Adicionando um novo serviço

Receita para qualquer coisa nova — um bot, um painel, um banco — seguindo as
[regras da casa](docker.md#regras-da-casa).

## Checklist

- [ ] Criei a pasta `/opt/stack/NOME` com `compose.yaml`, `.env` e `data/`
- [ ] O `compose.yaml` tem `name:` fixo no topo
- [ ] A porta está em `127.0.0.1` (ou nem é publicada)
- [ ] Segredos só no `.env` (`chmod 600`)
- [ ] Tem `restart: unless-stopped` e limite de logs
- [ ] Se usa PostgreSQL: serviço com "postgres" no nome e dados em `./data/postgres`
- [ ] Se tem página pública: apontei o hostname no Cloudflare Tunnel para `NOME:PORTA`
- [ ] Rodei o backup e conferi que o serviço entrou no pacote
- [ ] Registrei no [inventário](../referencia/inventario.md) e no [changelog](../referencia/changelog.md)

## Modelo de compose

```yaml
name: meu-servico

services:
  app:
    image: usuario/imagem:1.2.3          # sempre uma versão fixa
    restart: unless-stopped
    env_file: .env
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - ./data/app:/data
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
    mem_limit: 512m                      # um serviço com defeito não derruba o servidor
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }
    networks: [proxy]

networks:
  proxy:
    external: true
```

## Bot ou script próprio (Python)

Estrutura:

```text
/opt/stack/meu-bot/
├── compose.yaml
├── .env
├── Dockerfile
├── requirements.txt
└── app/
    └── main.py
```

```dockerfile
# Dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .
CMD ["python", "main.py"]
```

```yaml
# compose.yaml
name: meu-bot

services:
  bot:
    build: .
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./data:/data
    mem_limit: 256m
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }
```

```bash
cd /opt/stack/meu-bot
docker compose up -d --build            # --build reconstrói a imagem quando o código muda
docker compose logs -f --tail=50
```

## Banco de dados que não é PostgreSQL

O backup automático só entende PostgreSQL. Para MySQL, MariaDB, Redis etc., crie um *hook*:
qualquer script executável em `/opt/stack/scripts/backup.d/*.sh` roda dentro do backup e pode gravar
arquivos em `$WORK`, que entram no pacote final.

```bash
sudo tee /opt/stack/scripts/backup.d/50-mariadb.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$WORK/db"
docker exec meu-servico-db-1 sh -c 'mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" --all-databases' \
  | gzip -9 > "$WORK/db/meu-servico-db-1.mariadb.sql.gz"
EOF
sudo chmod +x /opt/stack/scripts/backup.d/50-mariadb.sh
```

Teste rodando o backup e conferindo o pacote:

```bash
sudo /opt/stack/scripts/backup.sh
sudo tar -tzf "$(ls -t /srv/backups/*.tar.gz | head -1)" | head -20
```

!!! warning "Restauração também precisa de um passo"
    O `restore.sh` só carrega os dumps do PostgreSQL. Para outros bancos, anote aqui o comando de
    restauração e **teste uma vez** — um backup que nunca foi restaurado é só uma esperança.
