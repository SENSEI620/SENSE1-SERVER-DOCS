# Dia a dia com os containers

Entre na pasta do serviço (`cd /opt/stack/NOME`) e use `docker compose`. Os comandos abaixo valem
para qualquer serviço.

## Os comandos de todo dia

| Quero… | Comando |
|---|---|
| Ver o que está rodando | `docker compose ps` |
| Ver os logs ao vivo | `docker compose logs -f --tail=100` |
| Logs de um serviço só | `docker compose logs -f --tail=100 n8n` |
| Reiniciar | `docker compose restart` (ou `restart n8n`) |
| Parar sem apagar nada | `docker compose stop` |
| Subir / aplicar mudança no compose ou `.env` | `docker compose up -d` |
| Desligar e remover containers (os dados em `data/` ficam) | `docker compose down` |
| Entrar dentro do container | `docker compose exec n8n sh` |
| Ver consumo de CPU e memória | `docker stats` |
| Ver o que mudou na configuração final | `docker compose config` |

!!! info "`restart` não relê o `.env`"
    Mudou o `.env` ou o `compose.yaml`? Use `docker compose up -d`: ele recria o container com a
    configuração nova. O `restart` só reinicia o processo.

## Todos os serviços de uma vez

Coloque esta função no `~/.bashrc` do servidor:

```bash
stackeach() {
  for d in /opt/stack/*/; do
    [ -f "$d/compose.yaml" ] || continue
    echo "== $(basename "$d")"
    (cd "$d" && "$@")
  done
}
```

Depois de `source ~/.bashrc`:

```bash
stackeach docker compose ps            # estado de tudo
stackeach docker compose pull          # baixar imagens novas
stackeach docker compose up -d         # aplicar
```

## Atualizar um serviço com segurança

1. **Backup:** `sudo /opt/stack/scripts/backup.sh`
2. Veja a versão atual: `docker compose images`
3. Baixe e aplique:

    ```bash
    docker compose pull
    docker compose up -d
    docker compose logs --tail=50
    ```

4. Teste de verdade (abra o serviço, rode um workflow).
5. Anote no [changelog](../referencia/changelog.md).

**Voltar atrás:** fixe a versão anterior no `.env` (ex.: `N8N_VERSION=1.x.y`) e rode `docker compose up -d`.

## Limpar espaço

```bash
docker system df                       # quanto cada coisa ocupa
docker image prune -a --filter "until=720h"    # imagens sem uso há mais de 30 dias
docker builder prune                   # cache de builds
```

!!! danger "Cuidado com `docker system prune --volumes`"
    Ele apaga volumes que não estão em uso naquele instante — um serviço parado pode perder dados.
    Como os dados estão em `./data`, o risco é menor, mas prefira os comandos específicos acima.

## Container reiniciando em loop?

```bash
docker compose ps                      # procure "Restarting"
docker compose logs --tail=100 NOME    # a causa quase sempre está nas últimas linhas
docker inspect --format '{{.State.ExitCode}} {{.State.OOMKilled}}' NOME_DO_CONTAINER
```

`OOMKilled true` significa falta de memória. Mais casos em [Troubleshooting](../operacao/troubleshooting.md).
