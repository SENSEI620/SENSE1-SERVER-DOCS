# 1. Preparação (pendrive e BIOS)

Antes de instalar qualquer coisa: escolher o sistema, preparar o pendrive e acertar a BIOS do Lenovo.

## Checklist

- [ ] Um pendrive de 8 GB ou mais (será apagado)
- [ ] Cabo de rede (evite Wi-Fi em servidor)
- [ ] **Backup do que existe no Lenovo** — a instalação apaga o disco inteiro
- [ ] Acesso ao roteador (para reservar um IP fixo)
- [ ] Monitor e teclado só para a instalação (depois tudo é por SSH)

## Escolha do sistema

| Opção | Quando escolher |
|---|---|
| **Ubuntu Server LTS** (recomendado) | Documentação farta, suporte de 5 anos por versão, o que esta documentação assume |
| Debian | Mais enxuto e estável; os scripts daqui funcionam igual |
| Ubuntu Desktop | Evite: gasta memória com interface que o servidor não usa |

!!! note "Baixe sempre a versão LTS mais recente"
    Em [ubuntu.com/download/server](https://ubuntu.com/download/server). Os comandos desta documentação são os mesmos entre as versões LTS recentes.

## Baixar e verificar a ISO

Compare o checksum com o publicado na página de download para garantir que a ISO não veio corrompida:

```bash
sha256sum ubuntu-*-live-server-amd64.iso
```

## Criar o pendrive

=== "Windows (Rufus)"

    1. Baixe o [Rufus](https://rufus.ie) e abra com o pendrive conectado.
    2. **Seleção de boot:** a ISO do Ubuntu Server.
    3. **Esquema de partição:** GPT. **Sistema de destino:** UEFI.
    4. Clique em **Iniciar** (se perguntar, use o modo "Imagem ISO").

=== "Linux / macOS (dd)"

    ```bash
    lsblk                        # descubra o pendrive (ex.: /dev/sdb) — confira o TAMANHO
    sudo dd if=ubuntu-server.iso of=/dev/sdX bs=4M status=progress conv=fsync
    ```

    !!! danger "Cuidado com o dispositivo"
        Trocar `/dev/sdX` pelo disco errado **apaga o disco errado**. Confira com `lsblk` duas vezes.

=== "Qualquer sistema (balenaEtcher)"

    Baixe o [balenaEtcher](https://etcher.balena.io), escolha a ISO, escolha o pendrive, **Flash**.

## BIOS do Lenovo

Ligue o Lenovo e aperte a tecla no logo:

| Para… | Tecla (varia por modelo) |
|---|---|
| Entrar na BIOS | **F1** ou **F2** (ThinkPad: **Enter** e depois **F1**) |
| Menu de boot (escolher o pendrive) | **F12** |

Ajustes recomendados (os nomes mudam de modelo para modelo):

| Ajuste | Valor | Por quê |
|---|---|---|
| Boot mode | **UEFI** | Padrão moderno; o instalador espera isso |
| Secure Boot | Pode ficar ligado | Ubuntu e Debian suportam; desligue só se algum driver reclamar |
| Virtualization (VT-x / AMD-V) | **Enabled** | Docker, máquinas virtuais, Proxmox no futuro |
| After Power Loss / AC Recovery | **Power On** | O servidor volta sozinho depois de uma queda de energia |
| Wake on LAN | **Enabled** | Ligar o servidor pela rede |
| Boot order | USB primeiro (só na instalação) | Depois volte o disco para primeiro |
| Limite de carga da bateria (notebook, se existir) | 60–80% | Bateria dura mais ligada na tomada o tempo todo |

## Anote antes de seguir

Preencha na página de [inventário](../referencia/inventario.md):

- Modelo do Lenovo, tamanho do disco e da memória
- Nome da interface de rede e **endereço MAC** (você usa o MAC para reservar IP no roteador)

Próximo passo: [instalando o Ubuntu Server](ubuntu-server.md).
