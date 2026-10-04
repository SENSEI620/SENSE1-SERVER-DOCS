# 4. Rede e acesso remoto

Três objetivos: o servidor ter sempre o mesmo endereço em casa, poder ser ligado pela rede, e
você acessá-lo de fora **sem abrir portas no roteador**.

## IP fixo

### Opção A (recomendada): reserva no roteador

No painel do roteador, procure por **DHCP → reserva de endereço** (ou "IP estático por MAC") e
associe o MAC do servidor a um IP, por exemplo `192.168.1.50`. O servidor continua em DHCP, mas
recebe sempre o mesmo número.

!!! success "Por que é melhor"
    Quando você migrar para outra máquina, só troca o MAC na reserva. Nada dentro do sistema muda.

### Opção B: IP fixo no próprio servidor (netplan)

```bash
ip -br link                                  # nome da interface (ex.: enp3s0)
ls /etc/netplan/                             # arquivo existente
```

```yaml
# /etc/netplan/50-cloud-init.yaml (ou o arquivo que existir)
network:
  version: 2
  ethernets:
    enp3s0:                         # troque pelo nome da sua interface
      dhcp4: false
      addresses: [192.168.1.50/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 9.9.9.9]
      wakeonlan: true
```

```bash
sudo chmod 600 /etc/netplan/*.yaml
sudo netplan try          # aplica e desfaz sozinho em 2 minutos se você perder a conexão
```

Para o cloud-init não reescrever a rede no próximo boot:

```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

## Ligar pela rede (Wake-on-LAN)

1. Na BIOS: **Wake on LAN = Enabled** (veja [Preparação](preparacao.md)).
2. No sistema:

    ```bash
    sudo ethtool enp3s0 | grep -i wake       # "Wake-on: g" é o que queremos
    ```

    O `wakeonlan: true` do netplan já cuida disso. Sem netplan fixo: `sudo ethtool -s enp3s0 wol g`
    (volta ao padrão no reinício; por isso o netplan é melhor).

3. De outro computador da rede:

    ```bash
    sudo apt install -y wakeonlan
    wakeonlan AA:BB:CC:DD:EE:FF              # o MAC do servidor
    ```

!!! note "Limitações"
    Só funciona **por cabo** (Wi-Fi quase nunca acorda). E só dentro da rede local: de fora de casa,
    acesse um aparelho que fique ligado (ex.: um Raspberry Pi) e dispare o comando de lá.

## Acesso remoto: qual usar?

| Opção | Bom para | Abre porta no roteador? | Funciona com CGNAT? |
|---|---|---|---|
| **Tailscale** | Você acessar SSH e painéis de fora | Não | Sim |
| **Cloudflare Tunnel** | Expor sites e webhooks (n8n) na internet | Não | Sim |
| Port forward + DDNS | Jeito tradicional | **Sim** | **Não** |

!!! info "CGNAT"
    Muitos provedores de internet residencial compartilham um mesmo IP público entre clientes
    (CGNAT). Nesse caso abrir porta no roteador **não adianta**. Tailscale e Cloudflare Tunnel
    funcionam do mesmo jeito, porque o servidor é quem conecta para fora.

### Tailscale (acesso seu, privado)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4                              # IP do servidor dentro da sua rede privada
sudo ufw allow in on tailscale0
```

Abra o link que o comando mostra para autenticar. Instale o Tailscale também no seu computador e
celular: depois `ssh SEU_USUARIO@lenovo-srv` funciona de qualquer lugar.

!!! warning "Desative a expiração de chave do servidor"
    No painel do Tailscale (aba **Machines**), nos três pontinhos do servidor, escolha
    **Disable key expiry**. Sem isso, a chave expira (padrão: ~6 meses) e você perde o acesso
    remoto sem aviso.

### Cloudflare Tunnel (acesso público ao n8n e a sites)

Pré-requisito: um domínio gerenciado no Cloudflare.

1. No painel Cloudflare **Zero Trust**, vá em **Networks → Tunnels → Create a tunnel** (os menus mudam de nome de vez em quando).
2. Escolha o conector **Docker** e **copie só o token**.
3. Em **Public Hostname**, mapeie `n8n.seudominio.com` para o serviço `HTTP` `n8n:5678`.
4. No servidor, guarde o token no `.env` do túnel e suba:

    ```bash
    mkdir -p /opt/stack/cloudflared && cd /opt/stack/cloudflared
    cat > compose.yaml <<'EOF'
    name: cloudflared

    services:
      cloudflared:
        image: cloudflare/cloudflared:latest
        restart: unless-stopped
        command: tunnel --no-autoupdate run
        environment:
          TUNNEL_TOKEN: ${CF_TUNNEL_TOKEN}
        networks: [proxy]

    networks:
      proxy:
        external: true
    EOF
    read -rsp 'Cole o token do túnel e aperte Enter: ' CF_TOKEN; echo
    printf 'CF_TUNNEL_TOKEN=%s\n' "$CF_TOKEN" > .env && chmod 600 .env && unset CF_TOKEN
    docker compose up -d
    docker compose logs --tail=20
    ```

    O token fica **só no servidor** (no `.env`) e no seu gerenciador de senhas. Nunca no Git.

!!! success "Ótimo para migração"
    O túnel segue o **token**, não o IP nem a máquina. Ao mudar de hardware, você sobe o mesmo
    `cloudflared` com o mesmo token e o público nem percebe.

## Se o Docker não baixa imagens (DNS)

```bash
resolvectl status | grep -i 'dns server'
getent hosts registry-1.docker.io
```

Se não resolver, confira `nameservers` no netplan ou o DNS do roteador.

Próximo passo: [script de bootstrap](bootstrap.md) (ou siga para [Docker](../servicos/docker.md)).
