# SERVER//DOCS

Documentação viva do servidor: instalação do zero, serviços, backup, monitoramento,
troubleshooting e migração para outro hardware. Site em **MkDocs Material**, publicado
no **GitHub Pages**.

## Rodar localmente

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
mkdocs serve                       # http://127.0.0.1:8000
```

## Publicar

1. Suba para um repositório no GitHub (branch `main`).
2. Em **Settings → Pages**, escolha **Source: GitHub Actions**.
3. A cada `git push`, o workflow `.github/workflows/deploy.yml` confere segredos,
   compila o site e publica.

Passo a passo completo: `docs/publicar.md`.

## Estrutura

```
docs/                 páginas em Markdown (é aqui que você edita)
docs/stylesheets/     tema futurista (CSS)
scripts/              scripts reais usados no servidor (a documentação os inclui)
mkdocs.yml            configuração e menu do site
.github/workflows/    publicação automática
```

## Regra número 1

O site é **público**. Nada de senha, token, chave, `.env`, IP público ou domínio que você
não queira expor. O `scripts/check-secrets.sh` ajuda, mas não substitui o seu cuidado.
