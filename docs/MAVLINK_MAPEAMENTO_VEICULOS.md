# Mapeamento MAVLink por classe de veículo

Estado: **especificação inicial, não integrada nem homologada**.

O contrato em `src/vehicle_control_contract.pas` descreve eixos normalizados; ele **não** autoriza transmissão de comandos. Um adaptador MAVLink precisa confirmar tipo de veículo, modo, suporte ao comando e estado de segurança antes de enviar qualquer mensagem.

| Classe | Entradas do contrato | Integração prevista |
| --- | --- | --- |
| Multirrotor | roll, pitch, yaw, throttle | Adaptador ArduCopter; avaliar MANUAL_CONTROL e modos suportados |
| Avião | roll, pitch, rudder, throttle | ArduPlane; conferir semântica de controle manual, superfícies e modo |
| Helicóptero | roll, pitch, yaw, collective, throttle | ArduCopter heli; **não** tratar coletivo como throttle sem tradução específica |
| Barco | rudder, forward | ArduRover/Boat; mapear direção e propulsão com reversão explícita |
| Submersível | forward, lateral, vertical, roll, pitch, yaw | ArduSub; mapear eixos de movimento e modos suportados |

## Regras para adaptadores

1. Iniciar em estado desarmado, sem saída de movimento.
2. Exigir identificação do autopiloto, heartbeat recente e classe de veículo compatível.
3. Rejeitar valores não finitos, eixos incompatíveis, comandos fora de faixa e entradas obsoletas.
4. Não confundir conexão de transporte com confirmação de controle ativo.
5. Não rearmar automaticamente após perda de conexão, joystick ou troca de modo.
6. Definir e testar política de perda de sinal por classe; não presumir que enviar zero substitui failsafe do firmware.
7. Confirmar por telemetria o estado de armamento; não deduzir de pedido enviado.
8. Separar adaptação de eixos de codificação/transporte MAVLink, com testes unitários e SITL antes de hardware.

## Etapas

- [x] Contrato de dados por classe de veículo criado.
- [x] Matriz inicial de mapeamento e regras de segurança documentadas.
- [ ] Implementar interface de adaptador MAVLink e serialização validada.
- [ ] Validar modos e mensagens em ArduPilot SITL para cada classe.
- [ ] Criar testes de timeout, perda de joystick, mudança de modo e desarme.
- [ ] Compilar em Windows/Linux e executar testes físicos controlados.

Referências: https://mavlink.io/en/ ; https://ardupilot.org/ ; https://ardupilot.org/sub/
