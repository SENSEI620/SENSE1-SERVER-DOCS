# Migração: visão geral e checklist

Mudar o servidor de máquina — do Lenovo antigo para outro, para uma placa de servidor, para um mini PC
ou para uma VPS — sem perder nada e com um plano de volta.

## A ideia central

> **Não se "move" um servidor. Instala-se um novo e restaura-se o backup nele.**

Isso só é simples porque a documentação inteira foi desenhada para isso:

| Peça do desenho | O que ela resolve na migração |
|---|---|
| Tudo em `/opt/stack` | Os serviços e seus dados estão num lugar só |
| `backup.sh` + `restore.sh` | Empacotar e desempacotar, com bancos consistentes |
| Segredos no `.env` e no gerenciador de senhas | A chave do n8n e as senhas vão junto |
| Cloudflare Tunnel e Tailscale | O acesso segue o token, não o IP nem a máquina |
| Bootstrap | O sistema novo fica igual ao antigo em minutos |

## Dois métodos

| | **A. Instalação limpa + restore** (recomendado) | B. Clonar o disco |
|---|---|---|
| Como | Instala o sistema, roda o bootstrap, restaura o backup | Copia o disco inteiro (Clonezilla, `dd`) para o novo |
| Hardware diferente | Funciona sempre | Pode dar problema (drivers, nome da interface de rede) |
| Leva "sujeira" antiga | Não | Sim, tudo |
| Testa seu backup | **Sim** (e esse é um bônus enorme) | Não |
| Tempo parado | 30–60 minutos | Depende do tamanho do disco |
| Use quando | Quase sempre; sempre que mudar de hardware | Máquinas idênticas e muita pressa |

!!! success "Dica de ouro"
    Mesmo que o método B pareça mais rápido, o **A** deixa você com a certeza de que o backup
    funciona. Se a migração der certo pelo A, o dia em que o Lenovo morrer você já sabe o caminho.

## O que muda entre máquinas

| Item | O que muda | O que fazer |
|---|---|---|
| Nome da interface de rede | `eno1` → `enp3s0` | `ip -br link` e ajuste o netplan (se usar IP fixo no sistema) |
| Endereço MAC | Novo | Atualize a **reserva no roteador** e o Wake-on-LAN |
| UUIDs dos discos | Novos | **Não copie** o `/etc/fstab` às cegas |
| Arquitetura de CPU | x86 → ARM (ex.: Raspberry Pi) | Confira se cada imagem Docker tem versão `arm64` |
| Tailscale | A máquina nova é um novo aparelho | Remova o antigo no painel; ative "disable key expiry" no novo |
| Túnel Cloudflare | Dois conectores com o mesmo token **dividem o tráfego** | Desligue o antigo antes de virar a chave |
| IP local | Pode mudar | Resolvido pela reserva no roteador |
| Hostname | Pode manter o nome | Ao manter, fica igual na documentação |

## Cenários

=== "Outro Lenovo / mini PC / PC usado"

    Mesmo caminho do passo a passo. Provavelmente é a mudança mais simples.

=== "Placa de servidor"

    Mesmo passo a passo, com um bônus: ganha IPMI (acesso remoto à "tela" e ao botão de ligar), ECC e
    mais conforto. Veja [hardware de servidor](hardware.md).

=== "VPS na nuvem"

    O passo a passo vale igual, trocando o pendrive pela imagem da VPS. Atenção: IP público fixo e
    exposto desde o primeiro minuto — ative o firewall e a chave SSH **antes** de subir qualquer serviço.

=== "Proxmox (virtualização)"

    Instale o Proxmox na máquina nova e rode o Ubuntu Server como uma **VM**. Daí em diante, mudar
    de hardware vira restaurar o backup da VM. Veja [hardware](hardware.md#estrategia-de-longo-prazo-proxmox).

## Checklist de preparação

Antes de começar a migração:

- [ ] Um **backup recente** feito e **testado** (`sha256sum -c`, `tar -tzf`)
- [ ] Uma **cópia do backup fora do servidor** (nuvem criptografada ou HD externo)
- [ ] `N8N_ENCRYPTION_KEY` e senhas no gerenciador de senhas (e conferidas)
- [ ] Token do Cloudflare Tunnel e `rclone.conf` guardados fora do servidor
- [ ] [Inventário](../referencia/inventario.md) atualizado (`inventario.sh`)
- [ ] Hardware novo testado: memória (memtest), disco (SMART), temperaturas
- [ ] Pendrive de instalação pronto e BIOS da máquina nova acertada
- [ ] Janela de manutenção avisada para quem usa os serviços
- [ ] Lenovo antigo **não será apagado** até a máquina nova rodar bem por alguns dias

Próximo: [passo a passo](passo-a-passo.md).
