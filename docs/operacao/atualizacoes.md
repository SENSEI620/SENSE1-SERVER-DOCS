# Atualizações

## Sistema operacional

As correções de **segurança** entram sozinhas (unattended-upgrades). O resto, uma vez por mês:

```bash
sudo apt update
apt list --upgradable                  # veja o que vai mudar
sudo apt full-upgrade -y
sudo apt autoremove -y
ls /var/run/reboot-required 2>/dev/null && echo "Precisa reiniciar"
```

Reinicie numa hora tranquila: `sudo reboot`. Depois confira:

```bash
uptime
docker ps
systemctl --failed
```

Os containers têm `restart: unless-stopped` e sobem sozinhos. Se algum não subir,
vá para [Troubleshooting](troubleshooting.md).

## Containers

Procedimento completo em [Dia a dia com os containers](../servicos/gerenciamento.md#atualizar-um-servico-com-seguranca):
backup → `pull` → `up -d` → testar → anotar no changelog.

## Troca de versão do Ubuntu (a cada ~2 anos)

Duas rotas:

| Rota | Quando |
|---|---|
| `sudo do-release-upgrade` | Atualização "no lugar". Funciona, mas arrasta o histórico de anos de mudanças |
| **Instalação limpa + restore** (recomendada) | Você ganha um sistema novo e testa seu backup de verdade |

A segunda rota é exatamente o procedimento de [migração](../migracao/passo-a-passo.md), só que na
mesma máquina. Quem pratica migração a cada versão nunca se assusta com ela.

## Checklist mensal

- [ ] `apt full-upgrade` e reinício se pedido
- [ ] `stackeach docker compose pull` e atualizar serviços com calma (um de cada vez)
- [ ] `docker image prune -a --filter "until=720h"`
- [ ] Último backup conferido, restauração de um arquivo testada
- [ ] Uma linha no [changelog](../referencia/changelog.md)
