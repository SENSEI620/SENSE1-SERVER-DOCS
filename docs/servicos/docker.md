# Docker e a pasta /opt/stack

Todos os serviços rodam em containers, organizados numa única pasta. Essa organização é o que
torna o backup simples e a migração previsível.

## Instalar o Docker

!!! tip "Já rodou o bootstrap?"
    Então o Docker já está instalado. Pule para [A pasta /opt/stack](#a-pasta-optstack).

Instalação oficial pelo repositório da Docker (Ubuntu; no Debian troque `ubuntu` por `debian` e use `$VERSION_CODENAME`):

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER      # saia e entre de novo no SSH
docker run --rm hello-world
```

!!! warning "Quem está no grupo `docker` é, na prática, administrador"
    Quem controla o Docker consegue virar *root* na máquina. Coloque nesse grupo só você.

### Limitar o tamanho dos logs

Sem isto, o log de um container que dá erro em loop pode encher o disco:

```bash
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
sudo systemctl restart docker
```

## A pasta /opt/stack

```text
/opt/stack/
├── n8n/
│   ├── compose.yaml
│   ├── .env                  # segredos: NUNCA vai para o Git
│   └── data/
│       ├── n8n/              # arquivos do n8n
│       └── postgres/         # banco (copiado via dump, não direto)
├── cloudflared/
│   ├── compose.yaml
│   └── .env
└── scripts/
    ├── backup.sh
    ├── restore.sh
    ├── healthcheck.sh
    └── backup.d/             # scripts extras de backup (opcional)
```

### Regras da casa

| Regra | Por quê |
|---|---|
| **Um serviço = uma pasta** com `compose.yaml`, `.env` e `data/` | Tudo do serviço fica junto: backup e migração viram "copiar a pasta" |
| **Sempre `name:` fixo** no topo do `compose.yaml` | Os nomes dos containers não dependem do nome da pasta; o restore conta com isso |
| **Dados em `./data/...`** (bind mount), não em volumes nomeados | Você enxerga e copia os arquivos |
| **Postgres em `./data/postgres`**, serviço com "postgres" no nome | O backup para de copiar esses arquivos e faz `pg_dumpall` |
| **Portas em `127.0.0.1`** (ex.: `"127.0.0.1:8080:8080"`) | O Docker ignora o UFW; assim nada fica exposto sem querer |
| **Versão da imagem fixada** quando o serviço estiver estável | Atualizar vira decisão sua, não surpresa |
| **`restart: unless-stopped`** | O serviço volta sozinho depois de queda ou reinício |
| **Segredos só no `.env`** com `chmod 600` | Nunca dentro do `compose.yaml` |

### Rede compartilhada `proxy`

O túnel (cloudflared) precisa enxergar os serviços. Uma rede externa chamada `proxy` liga os dois
(o bootstrap já cria; sem ele, rode uma vez):

```bash
docker network create proxy
```

## Conferir

```bash
docker --version
docker compose version
docker ps
docker system df               # quanto espaço o Docker usa
```

Próximo passo: [n8n](n8n.md).
