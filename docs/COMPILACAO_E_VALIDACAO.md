# Compilação e validação do Cockpit Drone

**Estado:** compilação local Windows x86_64 e testes automatizados comprovados em 2026-11-06. Produção, Linux, interface visual e ArduPilot SITL ainda pendentes. Evidências e limites: [validação local](VALIDACAO_LOCAL_2026-11-06.md).

## 1. Pré-requisitos

- Git e Python 3.11+ para os testes de contrato.
- Lazarus e Free Pascal compatíveis com o arquivo de projeto `.lpi` do repositório.
- Pacotes de componentes usados pelo Cockpit, inclusive a Lazarus AI Suite do projeto [CHATGPT](https://github.com/marcelomaurin/CHATGPT), SdpoJoystick e dependências dos protocolos, vídeo e interface.
- Dependências nativas de vídeo/FFmpeg conforme o sistema e a configuração do FQ777.
- Para simulação MAVLink: ArduPilot SITL em ambiente separado.

Ambiente local verificado: Lazarus 4.6, FPC 3.2.2, Python 3.13.7 e pymavlink 2.4.50. Consulte o relatório de validação para pacote de mapa, hashes, logs e limites dessa comprovação.

## 2. Verificações estáticas

Na raiz do repositório:

```sh
python -m unittest discover -s tests -p 'test_*.py' -v
```

O workflow `.github/workflows/project-contracts.yml` executa esse comando em CI. A aprovação **não** demonstra compilação Pascal, conectividade nem segurança operacional.

## 3. Compilação Lazarus

1. Instalar FPC/Lazarus e registrar versões (`fpc -iV` e `lazbuild --version`).
2. Clonar o Cockpit e o framework CHATGPT e instalar os pacotes Lazarus necessários, seguindo seus arquivos `.lpk`.
3. Localizar o projeto `.lpi` no repositório e abri-lo no Lazarus. Confirmar Search Paths e pacotes registrados.
4. Compilar em modo Debug primeiro. Guardar o log integral e corrigir erros de unit, recursos `.lfm`, APIs e bibliotecas.
5. Repetir no Windows e Linux. Para builds por linha de comando usar `lazbuild <arquivo.lpi>` **somente após** confirmar o nome real e os pacotes registrados.

## 4. Checklist de evidência

| Verificação | Estado |
|---|---|
| Contratos e integração Python | 39 testes locais aprovados, sem skips |
| FPC/Lazarus Linux | Pendente |
| FPC/Lazarus Windows | Aplicativo x86_64 e 5 pacotes AI Suite compilados; 6 suítes Pascal aprovadas |
| Bibliotecas AI Suite e FFmpeg | 5 pacotes AI Suite compilados; FFmpeg não validado |
| Joystick físico e falhas | Pendente |
| FQ777 sem hélices | Pendente |
| ArduPilot SITL | Pendente; loopback UDP MAVLink/Python/Pascal aprovado |
| Releases/instaladores | A cargo de outra sessão por instrução do usuário |

Registrar em cada ensaio: data, commit, sistema operacional, versão de FPC/Lazarus, pacotes, comando executado, resultado, log e responsável.

## 5. Regras de segurança

Não conectar hélices, motores ou propulsores para verificar joystick e comandos de emergência. Antes de testes reais, confirmar mecanismos de corte, limites de comando, perda de sinal e recuperação, específicos para cada classe de veículo. O controle por Wi-Fi/UDP não garante failsafe no firmware.

## 6. Pendências imediatas

- Identificar todas as units e pacotes efetivamente usados pelo projeto.
- Configurar CI de compilação com versões e dependências verificadas.
- Revisar `TAIDroneFQ777` e a lógica de desconexão/corte no módulo `src/conectionfq777.pas`.
- Testes de limites e neutralidade já aprovados em `tests/test_input_mapping.pas`; calibração física ainda pendente.

## 7. Regressão local

`tools/test_local.ps1` executa as seis suítes Pascal e a descoberta Python. Com `-MavlinkIntegration`, exige `pymavlink` e testa tráfego UDP real, incluindo a ponte Pascal. `COCKPIT_PYTHON` escolhe o Python do monitor na aplicação. Logs e resultados remotos do novo workflow ainda não foram verificados.
