# Comandos úteis

Cola rápida. Para a lista completa de um comando: `man comando` ou `comando --help`.

=== "Sistema"

    | Quero… | Comando |
    |---|---|
    | Versão do sistema e kernel | `lsb_release -a` · `uname -r` |
    | Há quanto tempo está ligado | `uptime -p` |
    | Reiniciar / desligar | `sudo reboot` · `sudo poweroff` |
    | Processos (interativo) | `htop` |
    | Memória | `free -h` |
    | Temperaturas | `sensors` |
    | Hardware | `lscpu` · `lsblk` · `sudo dmidecode -t system` |
    | Precisa reiniciar? | `ls /var/run/reboot-required` |
    | Atualizar tudo | `sudo apt update && sudo apt full-upgrade -y` |
    | Fuso e hora | `timedatectl` |

=== "Disco"

    | Quero… | Comando |
    |---|---|
    | Espaço livre | `df -h` |
    | O que ocupa espaço | `sudo ncdu -x /` |
    | Maiores pastas | `sudo du -xh / --max-depth=2 2>/dev/null \| sort -rh \| head -15` |
    | Discos e partições | `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT` |
    | Saúde do disco | `sudo smartctl -H /dev/sda` · `sudo smartctl -a /dev/sda` |
    | Estender o volume LVM | `sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv` |
    | Limpar logs do sistema | `sudo journalctl --vacuum-size=500M` |

=== "Rede"

    | Quero… | Comando |
    |---|---|
    | IPs e interfaces | `ip -br addr` · `ip -br link` |
    | Rota padrão | `ip route` |
    | Portas em escuta | `sudo ss -tulpn` |
    | Testar internet / DNS | `ping -c3 1.1.1.1` · `getent hosts exemplo.com` |
    | Testar uma URL | `curl -i https://exemplo.com` |
    | Testar uma porta | `nc -vz IP PORTA` |
    | Aplicar netplan com rede de segurança | `sudo netplan try` |
    | Status do Tailscale | `tailscale status` · `tailscale ip -4` |
    | Ligar o servidor (de outra máquina) | `wakeonlan AA:BB:CC:DD:EE:FF` |

=== "Docker"

    | Quero… | Comando |
    |---|---|
    | Containers rodando | `docker ps` (todos: `docker ps -a`) |
    | Estado de um serviço | `docker compose ps` |
    | Logs ao vivo | `docker compose logs -f --tail=100` |
    | Aplicar mudança | `docker compose up -d` |
    | Reiniciar | `docker compose restart` |
    | Parar / remover | `docker compose stop` · `docker compose down` |
    | Atualizar imagens | `docker compose pull && docker compose up -d` |
    | Entrar no container | `docker compose exec NOME sh` |
    | Consumo | `docker stats --no-stream` |
    | Espaço usado pelo Docker | `docker system df` |
    | Ver a config final | `docker compose config` |
    | Todos os serviços | `stackeach docker compose ps` ([função](../servicos/gerenciamento.md#todos-os-servicos-de-uma-vez)) |

=== "Logs e diagnóstico"

    | Quero… | Comando |
    |---|---|
    | Erros do sistema neste boot | `journalctl -p err -b --no-pager \| tail -50` |
    | Log de um serviço | `journalctl -u ssh -n 100 --no-pager` |
    | Mensagens do kernel | `sudo dmesg -T \| tail -50` |
    | Serviços com falha | `systemctl --failed` |
    | Estado de um serviço | `systemctl status NOME` |
    | Tentativas de login | `sudo journalctl -u ssh \| grep -i 'failed\|invalid' \| tail` |
    | Quem está logado | `w` · `last -n 10` |

=== "Segurança"

    | Quero… | Comando |
    |---|---|
    | Estado do firewall | `sudo ufw status verbose` |
    | Liberar uma porta (na LAN) | `sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp` |
    | IPs banidos | `sudo fail2ban-client status sshd` |
    | Desbanir um IP | `sudo fail2ban-client set sshd unbanip IP` |
    | Configuração efetiva do SSH | `sudo sshd -T \| grep -Ei 'passwordauth\|permitroot'` |
    | Gerar segredo aleatório | `openssl rand -hex 32` |

=== "Backup"

    | Quero… | Comando |
    |---|---|
    | Rodar o backup agora | `sudo /opt/stack/scripts/backup.sh` |
    | Ver os backups locais | `ls -lh /srv/backups` |
    | Conferir integridade | `cd /srv/backups && sha256sum -c ARQUIVO.tar.gz.sha256` |
    | Listar o conteúdo | `sudo tar -tzf ARQUIVO.tar.gz \| head` |
    | Ver os da nuvem | `sudo rclone ls backup-crypt:` |
    | Restaurar tudo | `sudo /opt/stack/scripts/restore.sh ARQUIVO.tar.gz` |
    | Saúde do servidor | `sudo /opt/stack/scripts/healthcheck.sh --verbose` |

=== "tmux (sessão que não cai)"

    | Quero… | Comando |
    |---|---|
    | Nova sessão | `tmux new -s trabalho` |
    | Sair sem encerrar | ++ctrl+b++ depois ++d++ |
    | Voltar | `tmux attach -t trabalho` |
    | Listar | `tmux ls` |
