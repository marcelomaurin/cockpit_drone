# Simulador de veículos — integração Cockpit Drone e servidor

Status: especificação inicial; **não implementado**.

## Finalidade
Aplicação independente que emula veículo e telemetria para o Cockpit Drone, sem necessidade de equipamento físico. Pode participar de ambiente virtual compartilhado via servidor PHP documentado em [SERVIDOR_MULTIPLAYER_PHP.md](SERVIDOR_MULTIPLAYER_PHP.md).

## Módulos
1. Catálogo de perfis: multirrotor, avião, helicóptero, barco e outros modelos extensíveis. Cada perfil define massa, propulsão, autonomia, bateria, limites e sensores disponíveis.
2. Dinâmica: posição, velocidade, aceleração, atitude, vento, consumo energético e eventos de simulação; modelos simplificados inicialmente e refinamento por veículo.
3. Adaptador Cockpit: conexão IP local, emulação de telemetria e heartbeat no protocolo acordado (preferir MAVLink v2 quando o adaptador estiver validado). O Cockpit deve identificar claramente **SIMULAÇÃO**.
4. Mapa e câmera: coordenadas geográficas, visualização de mapa OpenStreetMap ou serviço licenciado e câmera virtual aproximada. Imagens cartográficas 2D não fornecem, por si, visão fotorealista de câmera aérea; exigem dados de elevação/3D e licenças adequadas.
5. Multiplayer: cliente HTTP JSON com connect, telemetry, nearby, events, disconnect; token novo em **toda conexão**; renovar a sessão após falha, sem reaproveitar credenciais anteriores.
6. Entidades remotas: interpolação visual de estados recebidos, indicação de atraso, descarte de dados expirados; mostrar apenas entidades a <= 2 km conforme filtro do servidor.
7. Eventos virtuais: o servidor só retransmite estados e eventos; **o simulador** resolve interações e colisões no mundo virtual. Eventos de projéteis, se previstos, são apenas representações de jogo, sem integração com sistemas de armas reais.

## Fluxo
Iniciar perfil -> iniciar simulação local -> conectar Cockpit via IP -> solicitar token ao servidor -> publicar telemetria -> consultar vizinhos -> renderizar entidades -> simular interações -> desconectar e revogar token.

## Critérios de aceite
- Funcionar inteiramente offline em modo local, sem hardware.
- Telemetria coerente com perfil e bateria decrescente segundo carga simulada.
- Conexão IP e estado de heartbeat reproduzíveis em teste.
- Tokens diferentes em conexões sucessivas.
- Vizinho dentro de 2 km visível; fora do raio não recebido.
- Reconnect, timeouts, atraso e perda de rede tratados sem travar simulação.
- Nenhuma ação em hardware real.
