# 2. Instalando o Ubuntu Server

Conecte o cabo de rede, coloque o pendrive, ligue e aperte **F12** para escolher o pendrive.

## Telas do instalador

| # | Tela | O que escolher |
|---|---|---|
| 1 | Boot | **Try or Install Ubuntu Server** |
| 2 | Idioma | **English** (mensagens de erro em inglês são mais fáceis de pesquisar) |
| 3 | Teclado | Layout **Portuguese (Brazil)** |
| 4 | Tipo de instalação | **Ubuntu Server** (não a versão *minimized*) |
| 5 | Rede | Deixe em DHCP por enquanto e **anote o IP** que aparecer |
| 6 | Proxy / Mirror | Padrão (vazio) |
| 7 | Armazenamento | **Use an entire disk** + **Set up this disk as an LVM group** |
| 8 | Perfil | Seu nome, **nome do servidor** (ex.: `lenovo-srv`), usuário e uma senha forte |
| 9 | Ubuntu Pro | **Skip** |
| 10 | SSH | **Install OpenSSH server** marcado; importar chave do GitHub é opcional |
| 11 | Snaps | **Nenhum** |

!!! warning "Não criptografe o disco em servidor sem teclado"
    Com LUKS, a cada reinício o servidor espera você digitar a senha no teclado. Depois de uma
    queda de energia ele ficaria parado, desligado para o mundo. Em servidor doméstico acessado
    por SSH, não use criptografia de disco (proteja com acesso físico e backup criptografado).

!!! danger "A tela 7 apaga o disco"
    Na tela de resumo do armazenamento, conferir que é o disco certo. Tudo nele será apagado.

Ao final, escolha **Reboot Now** e **remova o pendrive** quando pedir.

## Primeiro login

No monitor do Lenovo, entre com seu usuário e descubra o IP:

```bash
ip -br addr
```

Do seu computador, conecte por SSH:

```bash
ssh SEU_USUARIO@IP_DO_SERVIDOR
```

## Corrija o tamanho do disco (importante)

O instalador do Ubuntu cria o volume raiz com cerca de 100 GB, mesmo que o disco seja maior.
O resto fica sem uso. Para usar o disco todo:

```bash
sudo vgs                                            # coluna VFree mostra o espaço sobrando
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
df -h /                                             # confira o novo tamanho
```

O `-r` já redimensiona o sistema de arquivos junto.

## Conferência rápida

```bash
lsb_release -a            # versão do Ubuntu
uname -r                  # versão do kernel
systemctl --failed        # deve listar 0 unidades
ping -c3 1.1.1.1          # tem internet?
```

!!! tip "Preferiu Debian?"
    O processo é parecido. Deixe a senha de *root* vazia no instalador: assim o primeiro usuário
    recebe o `sudo`. Desmarque o ambiente gráfico e marque **SSH server** e **standard system utilities**.
    O [script de bootstrap](bootstrap.md) funciona nos dois.

Próximo passo: [pós-instalação e segurança](pos-instalacao.md).
