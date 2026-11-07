// Browser-side WS client. Tokens stay in memory; no polling of /nearby.
export class CockpitMultiplayer {
  constructor(url, onSnapshot, onStatus = () => {}, onEvents = () => {}) {
    this.url = url; this.onSnapshot = onSnapshot; this.onStatus = onStatus;
    this.onEvents = onEvents; this.position = null; this.socket = null;
    this.running = false; this.retry = null; this.timer = null;
  }
  start() {
    if (this.running) return;
    this.running = true;
    this.connect();
    this.timer = setInterval(() => this.sendPosition(), 500);
  }
  connect() {
    if (!this.running) return;
    let socket;
    try { socket = new WebSocket(this.url); }
    catch (error) { this.stop(); this.onStatus(error.message); return; }
    this.socket = socket;
    socket.onopen = () => { if (this.socket !== socket) return; this.onStatus('conectado'); this.sendPosition(); };
    socket.onmessage = ({data}) => {
      if (this.socket !== socket) return;
      try {
        const message = JSON.parse(data);
        if (message.type === 'snapshot') this.onSnapshot(message.participants);
        else if (message.type === 'events') this.onEvents(message.events);
        else if (message.type === 'error') this.onStatus(message.code);
      } catch { this.onStatus('mensagem invalida'); socket.close(); }
    };
    socket.onclose = () => {
      if (this.socket !== socket) return;
      this.socket = null; this.onSnapshot([]); this.onStatus('desconectado');
      if (this.running) this.retry = setTimeout(() => this.connect(), 2000);
    };
  }
  setPosition(lat, lon, altitude_m, name = '') {
    if (![lat, lon, altitude_m].every(Number.isFinite) || Math.abs(lat)>90 || Math.abs(lon)>180)
      throw new Error('Coordenadas invalidas');
    this.position = {lat, lon, altitude_m, name}; this.sendPosition();
  }
  sendPosition() {
    if (this.socket?.readyState !== WebSocket.OPEN) return;
    this.socket.send(JSON.stringify(this.position
      ? {type:'telemetry', telemetry:this.position} : {type:'heartbeat'}));
  }
  sendEvent(type, payload) {
    if (this.socket?.readyState !== WebSocket.OPEN) throw new Error('Desconectado');
    this.socket.send(JSON.stringify({type:'event', event:{type,payload}}));
  }
  stop() {
    this.running = false; clearTimeout(this.retry); clearInterval(this.timer);
    const socket = this.socket; this.socket = null;
    if (socket) socket.close(1000);
    this.onSnapshot([]); this.onStatus('desligado');
  }
}
