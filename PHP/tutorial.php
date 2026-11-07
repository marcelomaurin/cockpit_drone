<?php
declare(strict_types=1);
?>
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tutorial Cockpit Drone & Simulador de Voo</title>
<style>
:root{color-scheme:dark;--bg:#0b1420;--panel:#142131;--ink:#eef4fa;--muted:#b3c3d3;--line:#304257;--accent:#64e3bd;--accent-hover:#84f0ce;--warning:#ffd166;--danger:#ff6b6b}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:24px}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 system-ui,-apple-system,Segoe UI,sans-serif}
a{color:var(--accent);text-underline-offset:4px}
a:focus-visible,summary:focus-visible{outline:3px solid var(--accent);outline-offset:5px}
.wrap{max-width:1100px;margin:auto;padding:0 24px}
header{border-bottom:1px solid var(--line);background:rgba(11,20,32,0.85);backdrop-filter:blur(8px);position:sticky;top:0;z-index:100}
nav{display:flex;align-items:center;justify-content:space-between;gap:24px;flex-wrap:wrap;padding:18px 0}
.brand{font-size:18px;font-weight:750;color:var(--ink);text-decoration:none}
.brand span{color:var(--accent)}
.links{display:flex;gap:20px;flex-wrap:wrap;font-size:14px}
.links a{color:var(--muted);text-decoration:none;transition:color .2s}
.links a:hover{color:var(--ink)}
.hero{padding:54px 0 36px}
.eyebrow{font-size:12px;text-transform:uppercase;letter-spacing:.16em;color:var(--accent);font-weight:750}
h1{font-size:clamp(30px,5vw,52px);line-height:1.15;letter-spacing:-.04em;max-width:860px;margin:16px 0 20px}
h2{font-size:26px;line-height:1.25;letter-spacing:-.02em;margin:0 0 16px;color:var(--ink)}
h3{font-size:18px;line-height:1.35;margin:0 0 10px;color:var(--ink)}
p{margin:0 0 16px}
.lead{font-size:18px;color:var(--muted);max-width:800px}
.actions{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}
.button{display:inline-flex;align-items:center;gap:8px;padding:11px 18px;border:1px solid var(--line);border-radius:8px;text-decoration:none;font-weight:650;color:var(--ink);transition:all .2s}
.button:hover{border-color:var(--accent);color:#fff}
.primary{background:var(--accent);color:#08251c;border-color:var(--accent)}
.primary:hover{background:var(--accent-hover);color:#08251c}
section{padding:38px 0;border-top:1px solid var(--line)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:22px}
.grid-3{display:grid;grid-template-columns:repeat(auto-fit, minmax(280px, 1fr));gap:20px}
.card{padding:24px;background:var(--panel);border:1px solid var(--line);border-radius:12px}
.card h3{display:flex;align-items:center;gap:8px}
.muted,li{color:var(--muted)}
li{margin:8px 0;padding-left:4px}
strong{color:var(--ink)}
ol,ul{padding-left:22px;margin:12px 0}
code{font:14px/1.6 ui-monospace,Consolas,monospace;color:#c1f9e7;background:#09111c;padding:2px 6px;border-radius:4px;overflow-wrap:anywhere}
pre{margin:16px 0;padding:16px;background:#09111c;border:1px solid var(--line);border-radius:8px;overflow:auto;max-width:100%}
pre code{padding:0;background:transparent;white-space:pre}
.note{border-left:4px solid var(--accent);padding:14px 18px;background:rgba(100,227,189,0.06);color:var(--muted);margin:20px 0;border-radius:0 8px 8px 0}
.note-warning{border-left-color:var(--warning);background:rgba(255,209,102,0.06)}
.badge{font-size:11px;padding:3px 7px;border-radius:4px;font-weight:700;text-transform:uppercase;letter-spacing:.05em}
.badge-joy{background:#1b4d3e;color:var(--accent);border:1px solid var(--accent)}
.badge-key{background:#2a3b50;color:#94b8db;border:1px solid #4a6382}
.table-wrap{overflow-x:auto;margin:18px 0;border:1px solid var(--line);border-radius:10px}
table{width:100%;border-collapse:collapse;font-size:15px;background:var(--panel)}
th,td{text-align:left;vertical-align:top;padding:12px 16px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600;background:#0f1a26}
tr:last-child td{border-bottom:none}
tr:hover td{background:rgba(255,255,255,0.02)}
footer{padding:30px 0 44px;color:var(--muted);font-size:14px;border-top:1px solid var(--line)}
@media(max-width:768px){.grid{grid-template-columns:1fr}.hero{padding-top:36px}}
.lang-picker{display:inline-flex;align-items:center;gap:6px;background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:5px 9px;font-size:13px}
.lang-picker select{background:transparent;color:var(--ink);border:none;outline:none;font:inherit;cursor:pointer}
.lang-picker select option{background:var(--panel);color:var(--ink)}
</style>
</head>
<body>
<header>
  <div class="wrap">
    <nav aria-label="Navegação principal">
      <a class="brand" href="index.php">Cockpit<span>Drone</span> / tutorial</a>
      <div class="links">
        <a href="index.php" data-i18n="tut_nav_home">Início / Servidor</a>
        <a href="#download" data-i18n="tut_nav_download">Onde Baixar</a>
        <a href="#joystick-vs-teclado" data-i18n="tut_nav_joy">Joystick vs Teclado</a>
        <a href="#mapa-teclas" data-i18n="tut_nav_keys">Mapa de Teclas</a>
        <a href="#passo-a-passo" data-i18n="tut_nav_steps">Passo a Passo</a>
        <a href="#multiplayer" data-i18n="tut_nav_multi">Mundo Compartilhado</a>
        <a href="https://github.com/marcelomaurin/cockpit_drone/tree/master/bin" target="_blank" rel="noopener" data-i18n="tut_nav_gh_bin">GitHub bin/</a>
      </div>
    <div class="lang-picker">
<label for="lang-select" title="Idioma / Language">🌐</label>
<select id="lang-select" onchange="changeLanguage(this.value)" aria-label="Selecione o idioma">
<option value="pt-BR" selected>Português (Brasil)</option>
<option value="en">English</option>
<option value="es">Español</option>
<option value="fr">Français</option>
<option value="de">Deutsch</option>
<option value="ru">Русский</option>
<option value="zh-CN">中文 (简体)</option>
<option value="ja">日本語</option>
<option value="ar">العربية</option>
<option value="hi">हिन्दी (Hindi)</option>
</select>
</div>
    </nav>
  </div>
</header>

<main class="wrap">
  <div class="hero">
    <div class="eyebrow" data-i18n="tut_hero_eyebrow">Guia Oficial &bull; Simulação e Voo</div>
    <h1 data-i18n="tut_hero_title">Tutorial do Simulador de Drone e do Cockpit</h1>
    <p class="lead" data-i18n="tut_hero_lead">Aprenda a baixar, configurar e pilotar drones com o Cockpit Drone e seu simulador físico 3D integrado. Conecte-se localmente ou participe do mundo compartilhado online.</p>
    <div class="actions">
      <a class="button primary" href="https://github.com/marcelomaurin/cockpit_drone/tree/master/bin" target="_blank" rel="noopener" data-i18n="tut_btn_download_bin">📥 Baixar Simulação na pasta bin/ do GitHub</a>
      <a class="button" href="#joystick-vs-teclado" data-i18n="tut_btn_controls">Controles (Joystick & Teclado)</a>
      <a class="button" href="#passo-a-passo" data-i18n="tut_btn_start_flight">Como Iniciar o Voo</a>
      <a class="button" href="index.php" data-i18n="tut_btn_back_server">Voltar ao Servidor</a>
    </div>
  </div>

  <section id="download">
    <div class="eyebrow" data-i18n="tut_sec1_eyebrow">1. Instalação</div>
    <h2 data-i18n="tut_sec1_title">Onde Baixar a Simulação e o Cockpit</h2>
    <p data-i18n="tut_sec1_intro">Todos os binários compilados, instaladores e arquivos de suporte estão disponíveis na pasta oficial <code>bin/</code> do repositório no GitHub:</p>
    
    <div class="grid">
      <div class="card">
        <h3 data-i18n="tut_card_setup_title">📦 Instalador Completo para Windows</h3>
        <p data-i18n="tut_card_setup_desc">A forma mais rápida de começar. O instalador configura o Cockpit Drone, o Simulador e todos os recursos necessários:</p>
        <p><strong data-i18n="tut_card_setup_file">Arquivo:</strong> <code>setup_cockpit_drone_0.41.exe</code></p>
        <p><a class="button primary" href="https://github.com/marcelomaurin/cockpit_drone/raw/master/bin/setup_cockpit_drone_0.41.exe" target="_blank" rel="noopener" data-i18n="tut_card_setup_btn">Baixar Instalador Oficial (.exe)</a></p>
        <p class="muted" style="font-size:13px" data-i18n="tut_card_setup_note">Localizado dentro da pasta <code>bin/</code> no GitHub.</p>
      </div>

      <div class="card">
        <h3 data-i18n="tut_card_bin_title">📁 Pasta bin/ no GitHub</h3>
        <p data-i18n="tut_card_bin_desc">Você pode navegar diretamente pela pasta de binários e documentação do projeto:</p>
        <ul>
          <li data-i18n="tut_card_bin_drone"><strong>drone.exe:</strong> Aplicativo principal do Cockpit com instrumentos de voo, HUD tático e GPS duplo.</li>
          <li data-i18n="tut_card_bin_sim"><strong>simulador.exe:</strong> Simulador de física e modelo de dinâmica de voo.</li>
          <li data-i18n="tut_card_bin_data"><strong>data/:</strong> Catálogo de modelos de drones e rotas.</li>
        </ul>
        <p><a class="button" href="https://github.com/marcelomaurin/cockpit_drone/tree/master/bin" target="_blank" rel="noopener" data-i18n="tut_card_bin_btn">Acessar pasta bin/ no GitHub</a></p>
      </div>
    </div>
  </section>

  <section id="joystick-vs-teclado">
    <div class="eyebrow" data-i18n="tut_sec2_eyebrow">2. Experiência de Controle</div>
    <h2 data-i18n="tut_sec2_title">Joystick vs. Teclado: Qual Usar?</h2>
    
    <div class="note" data-i18n="tut_tip_desc">
      <strong>💡 Dica de Pilotagem:</strong> O simulador opera com <strong>resposta contínua nos 4 eixos de voo</strong> (arfagem, rolagem, guinada e aceleração vertical). Por essa razão, <strong>o simulador é melhor rodado com um joystick analógico</strong>, permitindo modulação precisa e voo suave, <em>apesar de também poder ser perfeitamente pilotado via teclado</em>.
    </div>

    <div class="grid">
      <div class="card">
        <h3><span class="badge badge-joy" data-i18n="tut_joy_badge">Recomendado</span> <span data-i18n="tut_joy_title">Pilotando com Joystick</span></h3>
        <p data-i18n="tut_joy_desc">Utilize qualquer controle analógico compatível com Windows:</p>
        <ul>
          <li data-i18n="tut_joy_li1"><strong>Manches de Voo (Flight Sticks):</strong> Ideal para resposta realista dos eixos.</li>
          <li data-i18n="tut_joy_li2"><strong>Controles de Videogame (Xbox, PlayStation, etc.):</strong> Sticks analógicos proporcionam controle milimétrico do acelerador e curvas.</li>
          <li data-i18n="tut_joy_li3"><strong>Rádios Transmissores RC (via USB / VJoy):</strong> Excelente para quem já pilota drones de corrida (FPV) ou aeromodelos.</li>
        </ul>
        <p class="muted" data-i18n="tut_joy_note">Basta conectar o controle USB e ativar a opção <em>Joystick</em> nas Configurações do Cockpit.</p>
      </div>

      <div class="card">
        <h3><span class="badge badge-key" data-i18n="tut_key_badge">Acessível</span> <span data-i18n="tut_key_title">Pilotando com Teclado</span></h3>
        <p data-i18n="tut_key_desc">Se você não tiver um joystick conectado, pode pilotar normalmente pelo teclado:</p>
        <ul>
          <li data-i18n="tut_key_li1"><strong>Retorno Seguro:</strong> Ao soltar a tecla de subir, o sistema recua suavemente em direção ao patamar de pairar (<em>hover</em>), evitando que o drone suba descontrolado.</li>
          <li data-i18n="tut_key_li2"><strong>Corte Imediato de Pânico:</strong> A tecla <code>Espaço</code> zera o motor imediatamente em qualquer emergência.</li>
          <li data-i18n="tut_key_li3"><strong>Tecla de Centralização:</strong> A tecla <code>R</code> ou <code>5</code> centraliza arfagem e rolagem na posição neutra.</li>
        </ul>
        <p class="muted" data-i18n="tut_key_note">Consulte a aba <strong>Teclado</strong> na janela de Configurações para praticar com o teste de teclas em tempo real.</p>
      </div>
    </div>
  </section>

  <section id="mapa-teclas">
    <div class="eyebrow" data-i18n="tut_sec3_eyebrow">3. Referência de Comandos</div>
    <h2 data-i18n="tut_sec3_title">Mapa Completo de Teclas</h2>
    <p data-i18n="tut_sec3_desc">Mapeamento de teclas implementado no Cockpit Drone para orientação durante a navegação e pilotagem:</p>

    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th data-i18n="tut_tbl_cmd">Comando / Função</th>
            <th data-i18n="tut_tbl_key1">Tecla Principal</th>
            <th data-i18n="tut_tbl_key2">Tecla Alternativa</th>
            <th data-i18n="tut_tbl_effect">Efeito na Aeronave</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td data-i18n="tut_cmd_pitch_p"><strong>Frente (Pitch +)</strong></td>
            <td><code>W</code></td>
            <td data-i18n="tut_key_up"><code>Seta Acima</code></td>
            <td data-i18n="tut_eff_pitch_p">Inclina o drone para a frente (arfagem)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_pitch_m"><strong>Trás (Pitch -)</strong></td>
            <td><code>S</code></td>
            <td data-i18n="tut_key_down"><code>Seta Abaixo</code></td>
            <td data-i18n="tut_eff_pitch_m">Inclina o drone para trás</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_roll_m"><strong>Esquerda (Roll -)</strong></td>
            <td><code>A</code></td>
            <td data-i18n="tut_key_left"><code>Seta Esquerda</code></td>
            <td data-i18n="tut_eff_roll_m">Inclina o drone para a esquerda (rolagem)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_roll_p"><strong>Direita (Roll +)</strong></td>
            <td><code>D</code></td>
            <td data-i18n="tut_key_right"><code>Seta Direita</code></td>
            <td data-i18n="tut_eff_roll_p">Inclina o drone para a direita</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_throt_p"><strong>Subir (Throttle +)</strong></td>
            <td><code>E</code></td>
            <td><code>Page Up</code></td>
            <td data-i18n="tut_eff_throt_p">Aumenta aceleração dos motores e altitude</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_throt_m"><strong>Descer (Throttle -)</strong></td>
            <td><code>Q</code></td>
            <td><code>Page Down</code></td>
            <td data-i18n="tut_eff_throt_m">Reduz aceleração e desce o drone</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_yaw_m"><strong>Girar Esquerda (Yaw -)</strong></td>
            <td><code>1</code></td>
            <td><code>Z</code></td>
            <td data-i18n="tut_eff_yaw_m">Gira no próprio eixo à esquerda (Botão 1)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_yaw_p"><strong>Girar Direita (Yaw +)</strong></td>
            <td><code>2</code></td>
            <td><code>X</code></td>
            <td data-i18n="tut_eff_yaw_p">Gira no próprio eixo à direita (Botão 2)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_takeoff"><strong>Decolar / Armar</strong></td>
            <td><code>3</code></td>
            <td><code>Insert</code></td>
            <td data-i18n="tut_eff_takeoff">Arma motores ou decolagem automática (Botão 3)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_land"><strong>Pousar / Desarmar</strong></td>
            <td><code>4</code></td>
            <td><code>Delete</code></td>
            <td data-i18n="tut_eff_land">Inicia pouso automático ou desarma (Botão 4)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_hover"><strong>Pairar / Centralizar</strong></td>
            <td><code>5</code></td>
            <td><code>R</code> ou <code>Home</code></td>
            <td data-i18n="tut_eff_hover">Zera inclinações e mantém voo estabilizado (Botão 5)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_flip"><strong>Manobra / Flip 360°</strong></td>
            <td><code>6</code></td>
            <td><code>F</code></td>
            <td data-i18n="tut_eff_flip">Acrobacia aérea ou função especial (Botão 6)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_panic"><strong>PÂNICO / Corte Imediato</strong></td>
            <td data-i18n="tut_key_space"><code>Barra de Espaço</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_panic">Corte total e imediato dos motores (Z = 0)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_conn"><strong>Iniciar / Parar Conexão</strong></td>
            <td><code>Enter</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_conn">Liga/desliga a comunicação (Start / Stop)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_hud"><strong>Alternar HUD Tático</strong></td>
            <td><code>T</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_hud">Exibe ou oculta o Head-Up Display (visão militar)</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_cam"><strong>Alternar Janela Câmera</strong></td>
            <td><code>C</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_cam">Abre/fecha o feed de vídeo em tempo real</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_map"><strong>Alternar Janela Mapa</strong></td>
            <td><code>M</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_map">Abre/fecha o mapa tático de navegação</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_gps"><strong>Alternar Janela GPS</strong></td>
            <td><code>G</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_gps">Exibe o painel de telemetria GPS da Central e do Drone</td>
          </tr>
          <tr>
            <td data-i18n="tut_cmd_exit"><strong>Sair</strong></td>
            <td><code>Esc</code></td>
            <td>—</td>
            <td data-i18n="tut_eff_exit">Fecha a janela do cockpit</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <section id="passo-a-passo">
    <div class="eyebrow" data-i18n="tut_sec4_eyebrow">4. Operação Prática</div>
    <h2 data-i18n="tut_sec4_title">Passo a Passo: Como Rodar a Simulação</h2>

    <div class="grid-3">
      <div class="card">
        <h3 data-i18n="tut_step1_h3">1. Abra o Simulador</h3>
        <p data-i18n="tut_step1_p">Inicie o <code>simulador.exe</code>. Na janela do simulador:</p>
        <ul>
          <li data-i18n="tut_step1_li1">Selecione o drone desejado (ex: Cheerson CX-10W, DJI Tello, MAVLink).</li>
          <li data-i18n="tut_step1_li2">Verifique que o status de escuta de rede local está ativo (endereço <code>127.0.0.1</code>).</li>
        </ul>
      </div>

      <div class="card">
        <h3 data-i18n="tut_step2_h3">2. Configure o Cockpit</h3>
        <p data-i18n="tut_step2_p">Inicie o <code>drone.exe</code> e clique no botão <strong>Config</strong>:</p>
        <ul>
          <li data-i18n="tut_step2_li1">Na aba <em>Tipo Equipamento</em>, selecione o mesmo modelo/protocolo escolhido no simulador.</li>
          <li data-i18n="tut_step2_li2">Ative a opção <strong>Simulado (127.0.0.1)</strong>.</li>
          <li data-i18n="tut_step2_li3">Verifique seu dispositivo na aba <em>Joystick</em> ou consulte a aba <em>Teclado</em>.</li>
        </ul>
      </div>

      <div class="card">
        <h3 data-i18n="tut_step3_h3">3. Voe!</h3>
        <p data-i18n="tut_step3_p">Volte à tela principal e clique no botão <strong>Start</strong> (ou tecle <code>Enter</code>):</p>
        <ul>
          <li data-i18n="tut_step3_li1">Os LEDs acenderão confirmando o fluxo de telemetria.</li>
          <li data-i18n="tut_step3_li2">Decole pressionando <code>3</code> ou acelerando suavemente em <code>E</code>.</li>
          <li data-i18n="tut_step3_li3">Abra o HUD Tático teclando <code>T</code> e o Mapa teclando <code>M</code>.</li>
        </ul>
      </div>
    </div>
  </section>

  <section id="multiplayer">
    <div class="eyebrow" data-i18n="tut_sec5_eyebrow">5. Conectividade Online</div>
    <h2 data-i18n="tut_sec5_title">Mundo Compartilhado (Multiplayer)</h2>
    <p data-i18n="tut_sec5_desc">O Cockpit Drone suporta o compartilhamento de espaço aéreo em tempo real. Vários pilotos podem se conectar ao mesmo servidor para visualizar os drones uns dos outros no mapa e nas telas de telemetria.</p>
    
    <div class="card">
      <h3 data-i18n="tut_multi_h3">Configuração da API de Mundo</h3>
      <p data-i18n="tut_multi_p1">Tanto o simulador quanto o cockpit podem apontar para o servidor oficial de simulação:</p>
      <pre><code>URL da API de Mundo: https://maurinsoft.com.br/cockpit/api.php</code></pre>
      <p data-i18n="tut_multi_p2">Quando ativado:</p>
      <ul>
        <li data-i18n="tut_multi_li1">Drones em um raio de até <strong>2 km</strong> da sua posição geográfica aparecem automaticamente marcados no seu mapa tático.</li>
        <li data-i18n="tut_multi_li2">Informações de altitude, rumo e velocidade de cada participante são sincronizadas.</li>
        <li data-i18n="tut_multi_li3">O servidor conta com proteção automática de limites de sessão e persistência de dados.</li>
      </ul>
    </div>
  </section>
</main>

<footer>
  <div class="wrap">
    <p data-i18n="tut_footer_p1">Cockpit Drone &bull; Projeto de código aberto para telemetria, simulação e pilotagem de drones.</p>
    <p class="muted"><span data-i18n="tut_footer_p2">Disponível no GitHub:</span> <a href="https://github.com/marcelomaurin/cockpit_drone" target="_blank" rel="noopener">github.com/marcelomaurin/cockpit_drone</a></p>
  </div>
</footer>
<script src="i18n.js"></script>
</body>
</html>