# n8n (PostgreSQL + túnel)

Automação de workflows com banco PostgreSQL, pronto para ficar atrás do Cloudflare Tunnel.

!!! danger "A chave de criptografia é insubstituível"
    O n8n guarda as credenciais dos seus workflows (APIs, bots, contas) criptografadas com a
    `N8N_ENCRYPTION_KEY`. **Sem essa chave, o backup do banco vira credenciais ilegíveis.**
    Guarde-a no gerenciador de senhas, além de ela estar no `.env` do servidor.

## Arquivos

```bash
mkdir -p /opt/stack/n8n/data/n8n /opt/stack/n8n/data/postgres
cd /opt/stack/n8n
```

=== "compose.yaml"

    ```yaml
    name: n8n

    services:
      postgres:
        image: postgres:16-alpine
        restart: unless-stopped
        environment:
          POSTGRES_USER: ${POSTGRES_USER}
          POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
          POSTGRES_DB: ${POSTGRES_DB}
        volumes:
          - ./data/postgres:/var/lib/postgresql/data
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
          interval: 10s
          timeout: 5s
          retries: 10
        networks: [internal]
        logging: &logging
          driver: json-file
          options: { max-size: "10m", max-file: "3" }

      n8n:
        image: docker.n8n.io/n8nio/n8n:${N8N_VERSION:-latest}
        restart: unless-stopped
        depends_on:
          postgres:
            condition: service_healthy
        ports:
          - "${N8N_BIND:-127.0.0.1}:5678:5678"
        environment:
          DB_TYPE: postgresdb
          DB_POSTGRESDB_HOST: postgres
          DB_POSTGRESDB_PORT: 5432
          DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
          DB_POSTGRESDB_USER: ${POSTGRES_USER}
          DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
          N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
          N8N_HOST: ${N8N_HOST}
          N8N_PORT: 5678
          N8N_PROTOCOL: https
          WEBHOOK_URL: https://${N8N_HOST}/
          GENERIC_TIMEZONE: ${TZ}
          TZ: ${TZ}
        volumes:
          - ./data/n8n:/home/node/.n8n
        networks: [internal, proxy]
        logging: *logging

    networks:
      internal:
      proxy:
        external: true
    ```

=== ".env (gerar no servidor)"

    O comando abaixo cria o `.env` **já com segredos aleatórios**, direto no servidor:

    ```bash
    cat > .env <<EOF
    N8N_VERSION=latest
    N8N_HOST=n8n.seudominio.com
    N8N_BIND=127.0.0.1
    TZ=America/Sao_Paulo
    POSTGRES_USER=n8n
    POSTGRES_DB=n8n
    POSTGRES_PASSWORD=$(openssl rand -hex 24)
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
    EOF
    chmod 600 .env
    grep -E 'ENCRYPTION|PASSWORD' .env     # copie estes dois valores para o gerenciador de senhas
    ```

## Subir

```bash
sudo chown -R 1000:1000 data/n8n          # o n8n roda como usuário 1000 dentro do container
docker compose up -d
docker compose ps                          # postgres deve estar "healthy"
docker compose logs -f n8n                 # Ctrl+C para sair
```

Primeiro acesso, sem expor nada: crie um túnel SSH no seu computador e abra o navegador em
`http://localhost:5678`:

```bash
ssh -L 5678:127.0.0.1:5678 SEU_USUARIO@IP_DO_SERVIDOR
```

Crie a conta de dono quando o n8n pedir. Depois, para acesso público, mapeie o hostname no
[Cloudflare Tunnel](../instalacao/rede.md#cloudflare-tunnel-acesso-publico-ao-n8n-e-a-sites)
para `n8n:5678`.

## Já tenho um n8n rodando — como encaixo?

1. Descubra a chave atual (se você nunca definiu `N8N_ENCRYPTION_KEY`, o n8n gerou uma sozinha):

    ```bash
    docker exec NOME_DO_CONTAINER cat /home/node/.n8n/config
    ```

2. Use **esse mesmo valor** como `N8N_ENCRYPTION_KEY` no `.env` novo.
3. Faça um backup do que existe e só então migre os dados.
   Com SQLite, a forma mais simples é exportar e importar:

    ```bash
    docker exec NOME_DO_CONTAINER n8n export:workflow --all --output=/home/node/.n8n/workflows.json
    ```

    e, na instalação nova, `n8n import:workflow --input=...`. As credenciais acompanham
    a pasta de dados e a chave.

!!! note "SQLite em vez de PostgreSQL?"
    Funciona para pouco uso: remova o serviço `postgres` e as variáveis `DB_*`; o banco vira um
    arquivo em `data/n8n/`. O PostgreSQL é melhor para backup consistente, e é o que o
    [script de backup](../operacao/backup.md) trata automaticamente.

## Onde ficam as coisas

| O quê | Onde | Entra no backup? |
|---|---|---|
| Workflows, execuções, credenciais (criptografadas) | Banco PostgreSQL | Sim, via `pg_dumpall` |
| Arquivos do n8n (config, nós da comunidade) | `/opt/stack/n8n/data/n8n/` | Sim |
| Segredos (senha do banco, chave de criptografia) | `/opt/stack/n8n/.env` | Sim (o pacote é `chmod 600`) **e** no gerenciador de senhas |

## Atualizar o n8n

1. Faça um backup agora: `sudo /opt/stack/scripts/backup.sh`.
2. Leia as notas de versão do n8n (mudanças que quebram workflows existem).
3. Troque a versão no `.env` (`N8N_VERSION=...`) e:

    ```bash
    docker compose pull
    docker compose up -d
    docker compose logs --tail=50 n8n
    ```

4. **Voltar atrás:** coloque a versão anterior em `N8N_VERSION` e rode `docker compose up -d`.
   Se a versão nova já migrou o banco, restaure o backup do passo 1.

## Problemas comuns

??? failure "Webhooks chegam com URL errada ou não funcionam"
    O `WEBHOOK_URL` precisa ser o endereço **público** com `https` (ex.: `https://n8n.seudominio.com/`)
    e terminar com `/`. Confira com `docker compose exec n8n env | grep WEBHOOK`. Lembre também que
    a URL de **teste** só vale enquanto o workflow está em modo de teste; a de **produção** exige o
    workflow ativado.

??? failure "Aviso de 'secure cookie' ao abrir por http://IP:5678"
    O n8n exige HTTPS fora do `localhost`. Acesse pelo hostname do túnel (https) ou pelo túnel SSH em
    `localhost`. Só para testes em rede local, é possível colocar `N8N_SECURE_COOKIE: "false"` no
    `compose.yaml` — remova depois.

??? failure "Erro de permissão em /home/node/.n8n"
    A pasta de dados precisa pertencer ao usuário 1000: `sudo chown -R 1000:1000 /opt/stack/n8n/data/n8n`.

??? failure "Horários dos agendamentos errados"
    Confira `TZ` no `.env` (e `GENERIC_TIMEZONE`). Depois `docker compose up -d` para recriar.
