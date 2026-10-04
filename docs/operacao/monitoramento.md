# Monitoramento e saúde

Duas camadas: olhar na mão quando você entra no servidor, e um *healthcheck* que olha sozinho e
avisa no celular só quando algo está errado.

## Olhada rápida (1 minuto)

```bash
uptime                          # carga: 3 números; compare com o nº de núcleos (nproc)
free -h                         # memória (olhe a coluna "available")
df -h /                         # espaço em disco
sensors                         # temperaturas (precisa de lm-sensors)
docker ps                       # containers de pé?
systemctl --failed              # serviços do sistema com falha
sudo smartctl -H /dev/sda       # saúde do disco: PASSED
```

Ou rode o healthcheck em modo detalhado, que faz tudo isso e mais:

```bash
sudo /opt/stack/scripts/healthcheck.sh --verbose
```

## O que o healthcheck vigia

| Verificação | Alerta quando |
|---|---|
| Disco | uso ≥ 85% em qualquer partição |
| Memória | uso ≥ 90% |
| Carga | 1 min acima de 2× o número de núcleos |
| Temperatura | ≥ 85 °C |
| SMART | disco não está `PASSED` |
| Containers | algum está parado, reiniciando ou `unhealthy` |
| systemd | alguma unidade falhou |
| Backup | o mais recente tem mais de 36 h (ou não existe) |
| Internet | sem resposta do `1.1.1.1` |

Os limites ficam em `/etc/server-docs.env` (`DISK_WARN`, `MEM_WARN`, `TEMP_WARN`, `BACKUP_MAX_AGE_H`…).

## Receber o alerta no celular

O healthcheck envia um `POST` (campos `host` e `message`) para a URL em `ALERT_WEBHOOK`. Com o n8n é
simples: um workflow com nó **Webhook** → nó **Telegram** (ou e-mail, WhatsApp…).

```bash
# /etc/server-docs.env
ALERT_WEBHOOK=https://n8n.seudominio.com/webhook/alerta-servidor
```

Teste forçando um alerta:

```bash
sudo DISK_WARN=1 /opt/stack/scripts/healthcheck.sh
```

Para não te encher de mensagens, o mesmo alerta só se repete a cada 6 horas
(`ALERT_COOLDOWN_MIN`), e você recebe um "tudo normalizado" quando o problema passa.

!!! warning "Quem vigia o vigia?"
    Se o servidor inteiro cair, o n8n cai junto e **nenhum alerta sai**. Cubra isso com um monitor
    **externo**: o [healthchecks.io](https://healthchecks.io) (já usado no backup) avisa pela
    ausência do sinal, e o UptimeRobot (grátis) consegue testar a URL pública do n8n de fora.

## Rotinas de manutenção

| Quando | O que fazer |
|---|---|
| Toda semana | Ver `docker ps`, `df -h` e o último backup (um olhar de 1 minuto) |
| Todo mês | [Atualizações](atualizacoes.md), teste de restauração, limpar imagens do Docker |
| A cada 3 meses | Restaurar o backup numa máquina de teste |
| Todo ano | Limpar o pó (principalmente em notebook), conferir SMART completo (`smartctl -a`) |

## O script

??? abstract "healthcheck.sh"

    ```bash title="scripts/healthcheck.sh"
    --8<-- "scripts/healthcheck.sh"
    ```
