# Hardware de servidor

Quando o Lenovo chegar ao fim — ou quando você quiser mais conforto — o que olhar na hora de escolher.
Esta página é de **critérios**, não de modelos: o mercado muda, os critérios não.

## Opções, do mais simples ao mais "de servidor"

| Opção | Vantagens | Cuidados |
|---|---|---|
| **Mini PC** (usado ou novo) | Pequeno, silencioso, gasta pouca energia (10–25 W) | Poucos discos, sem ECC, às vezes sem 2ª placa de rede |
| **Outro notebook/PC usado** | Barato, o notebook tem "nobreak" embutido (bateria) | Mesmos limites do Lenovo atual: calor e desgaste |
| **Workstation / servidor torre usado** | Muita RAM e discos, ECC comum, peças baratas no usado | Consome mais (60–150 W), faz barulho |
| **Placa de servidor** (ex.: linhas voltadas a servidores) | **IPMI**, ECC, duas placas de rede, feita para ficar ligada | Você monta tudo; é o mais caro em peças e energia |
| **VPS na nuvem** | Zero hardware, IP fixo, sem queda de energia | Mensalidade, e seus dados ficam com terceiros |

## O que uma "placa de servidor" traz de diferente

| Recurso | Por que importa |
|---|---|
| **IPMI / BMC** | Um mini-computador dentro da placa: você vê a tela, usa teclado virtual e liga/desliga o servidor **pela rede**, mesmo travado ou sem sistema. Acaba o "preciso ir lá com monitor e teclado". |
| **Memória ECC** | Corrige erros de memória sozinha. Em máquina que fica ligada anos, evita corrupção silenciosa. |
| **Duas placas de rede (Intel)** | Redundância e separação de redes; drivers confiáveis no Linux. |
| **Fonte e componentes de uso contínuo** | Feitos para 24×7. |
| **Boot e firmware estáveis** | Menos surpresas com o sistema novo. |

## Critérios de decisão

- **Energia:** servidor ligado 24 h gasta `watts × 24 × 30 ÷ 1000` kWh por mês.
  Exemplo: 60 W → 43,2 kWh/mês; com a tarifa de R$ 1,00/kWh são ~R$ 43/mês. Use a **sua** tarifa.
  Uma máquina de 150 W custa 2,5 vezes isso.
- **Barulho e calor:** servidores torre e rack são barulhentos. Pense em onde ele vai ficar.
- **Nobreak:** no Brasil, queda e oscilação de energia são realidade. Um nobreak (ou o próprio
  notebook, com bateria) protege disco e dados. Dimensione para **desligar com segurança** (10–15 min),
  não para ficar horas ligado.
- **Disco:** prefira **SSD** (confiável, silencioso, rápido). Para guardar muita coisa, HDD como
  segundo disco. Acompanhe sempre o SMART.
- **Mais de um disco:** espelhamento (RAID 1, ZFS mirror) segura a falha de um disco, mas
  **continua sem ser backup**.
- **Memória:** 8 GB bastam para n8n e alguns serviços; 16–32 GB se for rodar máquinas virtuais.
- **Virtualização:** confirme VT-x/AMD-V na BIOS. Docker funciona sem, mas Proxmox e VMs exigem.
- **Rede por cabo:** sempre.

## Estratégia de longo prazo: Proxmox

Em vez de instalar o Ubuntu direto na máquina, instale o **Proxmox VE** (hipervisor gratuito) e rode o
Ubuntu Server como uma **máquina virtual**.

| Ganho | Como |
|---|---|
| Migrar de hardware vira restaurar uma VM | Backup da VM inteira (`vzdump`), sem reinstalar nada |
| Experimentar sem medo | *Snapshot* antes de uma atualização; voltou? é só reverter |
| Vários servidores isolados | Uma VM para produção, outra para testar |
| Mesma documentação | Dentro da VM, tudo continua igual a este site |

Custo: uma camada a mais para aprender e um pouco de memória. Vale a pena quando você tem mais de
um serviço importante ou migra com frequência.

## Antes de comprar

- [ ] Memória testada (memtest) e SMART do disco **antes** de colocar em produção
- [ ] Ficha de consumo real (use um medidor de tomada)
- [ ] Onde vai ficar: ventilação, barulho, nobreak
- [ ] Plano de backup para o equipamento novo funcionando no **dia 1**
- [ ] Hardware suportado pelo Linux (placas de rede Intel são a escolha segura)

Pronto para trocar? Siga o [passo a passo de migração](passo-a-passo.md).
