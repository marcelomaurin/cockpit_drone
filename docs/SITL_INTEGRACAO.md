# Preparação da integração ArduPilot SITL (sem controle físico)

Este guia prepara a próxima etapa do Cockpit Drone. **Nenhuma conexão MAVLink está implementada neste documento.** O adaptador atual em `src/mavlink_vehicle_adapter.pas` apenas valida pré-condições e não transmite pacotes.

## Ambiente isolado

1. Instalar ArduPilot SITL em ambiente de desenvolvimento separado, seguindo a documentação oficial.
2. Iniciar um veículo simulado (por exemplo, ArduCopter) e configurar saída MAVLink exclusivamente em loopback, como `127.0.0.1:14550`.
3. Confirmar que não existe rota de saída para rádio, serial ou IP de equipamento real.
4. Observar heartbeat e identificar tipo de autopiloto e veículo antes de permitir qualquer teste de comando.
5. Registrar log da sessão, versão do simulador, parâmetros de modo e resultado esperado/obtido.

## Camadas de integração previstas

- **Transporte**: UDP loopback, sem endereço remoto configurável na primeira versão.
- **Decodificador**: parser MAVLink v2 com validação de checksum e identificação de sistema/componente.
- **Estado**: heartbeat, modo, armamento e idade monotônica da última mensagem.
- **Validação**: `ValidateMavlinkDispatch` e contrato `TVehicleCommand`.
- **Tradutor**: mapeamento por veículo e modo, inicialmente desativado; nunca reutilizar eixos de uma classe em outra.
- **Saída**: somente simulação, após testes de recepção, autenticação/controle de origem conforme arquitetura escolhida e autorização explícita.

## Cenários de teste

| Cenário | Resultado exigido |
| --- | --- |
| Sem heartbeat | Comandos rejeitados |
| Heartbeat obsoleto | Comandos rejeitados |
| Classe incompatível | Comandos rejeitados |
| Modo não aprovado | Comandos rejeitados |
| Estado de armamento divergente | Comandos rejeitados |
| Entrada obsoleta | Comandos rejeitados |
| Destino diferente de loopback | Conexão recusada |
| Reconexão após perda de sinal | Permanecer desarmado até nova autorização |

## Critérios de aceite

- [ ] Compilação do adaptador e testes Pascal.
- [ ] Recepção de heartbeat MAVLink v2 validada em SITL.
- [ ] Rejeição de mensagens inválidas e origem inesperada.
- [ ] Ensaios de timeout e reconexão com logs reproduzíveis.
- [ ] Mapeamento específico por classe de veículo testado em simulador.
- [ ] Nenhuma transmissão para hardware real.

Documentação: https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html e https://mavlink.io/en/
