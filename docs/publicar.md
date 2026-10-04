# Publicar no GitHub Pages

A documentação é só Markdown + um tema. O GitHub transforma em site sozinho a cada `git push`.

## Primeira publicação

1. **Crie o repositório** no GitHub (por exemplo `servidor-docs`).
   O GitHub Pages grátis exige repositório **público**; repositório privado com Pages é recurso de plano pago.
2. **Envie os arquivos** (de dentro da pasta do projeto, no seu computador):

    ```bash
    git init -b main
    git add .
    git commit -m "docs: primeira versão da documentação do servidor"
    git remote add origin git@github.com:SEU_USUARIO/NOME_DO_REPO.git
    git push -u origin main
    ```

3. No GitHub: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
4. Abra a aba **Actions** e espere o workflow ficar verde.
5. O site fica em `https://SEU_USUARIO.github.io/NOME_DO_REPO/`.
6. Descomente `site_url` e `repo_url` no `mkdocs.yml` e faça push de novo.

## Atualizar a documentação

Edite um arquivo em `docs/`, depois:

```bash
git add -A
git commit -m "docs: o que você mudou"
git push
```

Em 1–2 minutos o site atualiza. Dá para editar direto no GitHub (ícone de lápis no arquivo), inclusive pelo celular — útil quando o servidor quebra e você está fora de casa.

## Ver antes de publicar

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
mkdocs serve                       # abre em http://127.0.0.1:8000
```

## O que nunca entra no site

!!! danger "O site é público"
    - Senhas, tokens (Cloudflare, GitHub, n8n), chaves SSH, a `N8N_ENCRYPTION_KEY`
    - Conteúdo real de `.env`
    - IP público da sua casa e domínios que você não queira expor
    - Saída do `inventario.sh` sem revisar

O que fica no lugar: o **procedimento** ("o token fica no gerenciador de senhas, item *Cloudflare Tunnel*").

### Rede de segurança automática

O workflow roda `scripts/check-secrets.sh` antes de compilar: se achar um padrão de segredo
(chave privada, token do GitHub, `SENHA=valor-real`...) ou um IP público, **o deploy falha**
e nada é publicado. Rode também antes de cada commit:

```bash
bash scripts/check-secrets.sh
```

Ele é uma última barreira, não uma garantia.

### Vazou algo? Nesta ordem

1. **Troque o segredo** (gere outro token/senha e revogue o antigo). Isso vem primeiro.
2. Remova do arquivo e faça push.
3. Lembre: apagar o commit não apaga cópias, forks nem caches. Por isso o item 1 é o que resolve.

## Alternativa: documentação privada

Se quiser colocar IPs e detalhes reais, mantenha o repositório **privado** e leia o site localmente:

```bash
mkdocs build                       # gera a pasta site/
mkdocs serve                       # ou use o servidor local
```

!!! tip "A documentação precisa existir fora do servidor"
    Se a única cópia estiver dentro do servidor que quebrou, ela não ajuda. Mantenha uma cópia
    no GitHub (mesmo privado) e, de tempos em tempos, um PDF ou a pasta `site/` no seu computador.
