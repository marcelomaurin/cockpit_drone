# Testes

Todos rodam sem o equipamento real. Os scripts Python fazem o papel do cockpit, com os mesmos pacotes que os componentes da suíte CHATGPT enviam.

## Servidor de mundo (PHP)

```
php simulador/servidor_mundo/testes/teste_api.php
```

São 32 verificações, com SQLite em memória e relógio controlado. Elas cobrem o token (só o hash vai para o banco), o filtro de 2 km (1.990 m aparece, 2.010 m não, e nada revela quem está fora), o `id` alheio ignorado, os eventos só dentro do círculo, os limites (429), o salto de posição, a validade de 30 s e a saída.

## Emuladores (Lazarus + Python)

```
cd simulador
fpc -Mobjfpc -Sh -Fusrc/nucleo -Fusrc/protocolos -Fusrc/mapa -Fusrc/mundo -FUtestes -FEtestes testes/sim_console.lpr
testes/sim_console tello 13 &      python3 testes/cockpit_tello.py
testes/sim_console mavlink 60 &    python3 testes/cockpit_mavlink.py     # precisa de: pip install pymavlink
testes/sim_console ardrone 12 &    python3 testes/cockpit_outros.py ardrone
testes/sim_console fq777 12 &      python3 testes/cockpit_outros.py fq777
testes/sim_console esp32 12 &      python3 testes/cockpit_outros.py esp32
testes/sim_console espdrone 12 &   python3 testes/cockpit_outros.py espdrone
```

`sim_console` imprime a fase, a posição e a bateria a cada 0,5 s, e as mensagens do emulador. O roteiro MAVLink faz GUIDED, arma, decola a 10 m, envia uma rota de 4 itens, executa a rota e volta (RTL).

## Mundo de ponta a ponta

```
cd simulador/servidor_mundo/public && php -S 127.0.0.1:8099 &
cd simulador && fpc ... testes/mundo_console.lpr && testes/mundo_console http://127.0.0.1:8099/api.php
```

Dois clientes (o mesmo código do simulador) entram no mundo: A no ponto inicial e B a 1.990 m. B precisa ver A e receber a mensagem dele. Depois B vai para 2.010 m e A some da lista. O teste termina com `RESULTADO OK`.

## Integração contínua

O fluxo `.github/workflows/simulador.yml` roda os testes do servidor, compila o simulador com `lazbuild` e roda os testes dos emuladores Tello, AR.Drone, FQ777, ESP32 e ESP-Drone. O fluxo `lazarus-build.yml` também compila `simulador.lpi`, junto com os outros projetos.
