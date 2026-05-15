// All audio is generated procedurally via WebAudio so the game is fully self-contained.

export class AudioEngine {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.musicGain = null;
    this.sfxGain = null;
    this.heartbeatGain = null;
    this.whisperGain = null;
    this.started = false;
    this.heartbeatRate = 0.7; // beats/sec target
    this._heartbeatTimer = 0;
    this._whisperTimer = 4 + Math.random() * 6;
  }

  start() {
    if (this.started) return;
    this.started = true;
    const AC = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.8;
    this.master.connect(this.ctx.destination);

    this.musicGain = this.ctx.createGain();
    this.musicGain.gain.value = 0.0;
    this.musicGain.connect(this.master);

    this.sfxGain = this.ctx.createGain();
    this.sfxGain.gain.value = 0.7;
    this.sfxGain.connect(this.master);

    this.heartbeatGain = this.ctx.createGain();
    this.heartbeatGain.gain.value = 0.0;
    this.heartbeatGain.connect(this.master);

    this.whisperGain = this.ctx.createGain();
    this.whisperGain.gain.value = 0.0;
    this.whisperGain.connect(this.master);

    this._buildAmbient();
    this._fadeIn(this.musicGain, 0.55, 4);
  }

  resume() { if (this.ctx && this.ctx.state === "suspended") this.ctx.resume(); }
  suspend() { if (this.ctx && this.ctx.state === "running") this.ctx.suspend(); }

  // Dark drone: detuned sine + saw + filtered noise.
  _buildAmbient() {
    const ctx = this.ctx;
    const out = this.musicGain;

    // Deep drone
    const droneFreqs = [55, 55.4, 82.5, 110.2, 36.71];
    for (const f of droneFreqs) {
      const osc = ctx.createOscillator();
      osc.type = Math.random() > 0.5 ? "sine" : "triangle";
      osc.frequency.value = f;
      const g = ctx.createGain();
      g.gain.value = 0.06 + Math.random() * 0.05;
      // slow LFO on amp for swelling
      const lfo = ctx.createOscillator();
      lfo.frequency.value = 0.05 + Math.random() * 0.1;
      const lfoG = ctx.createGain();
      lfoG.gain.value = 0.04;
      lfo.connect(lfoG).connect(g.gain);
      osc.connect(g).connect(out);
      osc.start(); lfo.start();
    }

    // Filtered noise pad
    const noise = this._noiseBuffer(4);
    const src = ctx.createBufferSource();
    src.buffer = noise;
    src.loop = true;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = 250;
    lp.Q.value = 1.2;
    const ng = ctx.createGain();
    ng.gain.value = 0.18;
    src.connect(lp).connect(ng).connect(out);
    src.start();

    // Slow random "metallic tings" — kept rare to stay tense
    const tingTimer = () => {
      const delay = 6 + Math.random() * 14;
      setTimeout(() => { if (this.ctx) { this._ting(); tingTimer(); } }, delay * 1000);
    };
    tingTimer();
  }

  _noiseBuffer(seconds = 1) {
    const len = this.ctx.sampleRate * seconds;
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    return buf;
  }

  _ting() {
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const freqs = [880, 1175, 1318, 1567, 1760];
    const f = freqs[Math.floor(Math.random() * freqs.length)] * (0.4 + Math.random() * 0.3);
    const osc = ctx.createOscillator();
    osc.type = "sine";
    osc.frequency.value = f;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.18, now + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, now + 1.4);
    osc.connect(g).connect(this.musicGain);
    osc.start(now); osc.stop(now + 1.6);
  }

  footstep() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this._noiseBuffer(0.18);
    const bp = ctx.createBiquadFilter();
    bp.type = "lowpass";
    bp.frequency.value = 600 + Math.random() * 250;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.5, now + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);
    src.connect(bp).connect(g).connect(this.sfxGain);
    src.start(now); src.stop(now + 0.2);
  }

  pickup() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    [330, 247, 165].forEach((f, i) => {
      const o = ctx.createOscillator();
      o.type = "sawtooth";
      o.frequency.value = f;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, now + i * 0.08);
      g.gain.exponentialRampToValueAtTime(0.18, now + i * 0.08 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, now + i * 0.08 + 0.4);
      const lp = ctx.createBiquadFilter();
      lp.type = "lowpass";
      lp.frequency.value = 1400;
      o.connect(lp).connect(g).connect(this.sfxGain);
      o.start(now + i * 0.08); o.stop(now + i * 0.08 + 0.45);
    });
  }

  flashlightClick() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this._noiseBuffer(0.06);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.4, now);
    g.gain.exponentialRampToValueAtTime(0.0001, now + 0.06);
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 1500;
    src.connect(hp).connect(g).connect(this.sfxGain);
    src.start(now); src.stop(now + 0.08);
  }

  // Heartbeat: triggered every frame; rate depends on monster proximity.
  setHeartbeatIntensity(intensity) {
    // intensity 0..1
    if (!this.ctx) return;
    this.heartbeatRate = 0.7 + intensity * 1.8; // up to ~2.5/sec
    const target = Math.min(0.9, intensity * 1.2);
    this.heartbeatGain.gain.setTargetAtTime(target, this.ctx.currentTime, 0.4);
  }

  updateHeartbeat(dt) {
    if (!this.ctx) return;
    this._heartbeatTimer += dt;
    const interval = 1 / this.heartbeatRate;
    if (this._heartbeatTimer >= interval) {
      this._heartbeatTimer = 0;
      this._heartbeat();
    }
  }

  _heartbeat() {
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const beat = (t) => {
      const o = ctx.createOscillator();
      o.type = "sine";
      o.frequency.setValueAtTime(70, t);
      o.frequency.exponentialRampToValueAtTime(30, t + 0.18);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.9, t + 0.015);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);
      o.connect(g).connect(this.heartbeatGain);
      o.start(t); o.stop(t + 0.25);
    };
    beat(now);
    beat(now + 0.18);
  }

  updateWhispers(dt) {
    if (!this.ctx) return;
    this._whisperTimer -= dt;
    if (this._whisperTimer <= 0) {
      this._whisper();
      this._whisperTimer = 7 + Math.random() * 12;
    }
  }

  setWhisperIntensity(intensity) {
    if (!this.ctx) return;
    const target = Math.min(0.5, intensity * 0.7);
    this.whisperGain.gain.setTargetAtTime(target, this.ctx.currentTime, 1.0);
  }

  _whisper() {
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const dur = 1.4 + Math.random() * 2.2;
    const src = ctx.createBufferSource();
    src.buffer = this._noiseBuffer(dur);
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.value = 900 + Math.random() * 600;
    bp.Q.value = 8;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 6 + Math.random() * 8;
    const lfoG = ctx.createGain();
    lfoG.gain.value = 300;
    lfo.connect(lfoG).connect(bp.frequency);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.55, now + 0.3);
    g.gain.setValueAtTime(0.55, now + dur - 0.4);
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    // Pan random
    const panner = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
    if (panner) panner.pan.value = (Math.random() * 2 - 1);
    src.connect(bp).connect(g);
    if (panner) { g.connect(panner); panner.connect(this.whisperGain); }
    else g.connect(this.whisperGain);
    lfo.start(now); src.start(now);
    lfo.stop(now + dur); src.stop(now + dur);
  }

  // The big scream — designed to be very loud and unpleasant.
  scream() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const dur = 1.4;

    // Distorted noise burst
    const noise = ctx.createBufferSource();
    noise.buffer = this._noiseBuffer(dur);
    const ws = ctx.createWaveShaper();
    ws.curve = (() => {
      const n = 256, c = new Float32Array(n);
      for (let i = 0; i < n; i++) {
        const x = i / n * 2 - 1;
        c[i] = Math.tanh(x * 6);
      }
      return c;
    })();
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 400;
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.setValueAtTime(800, now);
    bp.frequency.exponentialRampToValueAtTime(2400, now + 0.4);
    bp.frequency.exponentialRampToValueAtTime(400, now + dur);
    bp.Q.value = 5;
    const ng = ctx.createGain();
    ng.gain.setValueAtTime(0.0001, now);
    ng.gain.exponentialRampToValueAtTime(1.2, now + 0.02);
    ng.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    noise.connect(hp).connect(ws).connect(bp).connect(ng).connect(this.master);
    noise.start(now); noise.stop(now + dur);

    // Pitch-bending scream tones (formants)
    [350, 700, 1050, 1500].forEach((f, i) => {
      const o = ctx.createOscillator();
      o.type = i === 0 ? "sawtooth" : "square";
      o.frequency.setValueAtTime(f * 0.5, now);
      o.frequency.exponentialRampToValueAtTime(f * 1.5, now + 0.15);
      o.frequency.exponentialRampToValueAtTime(f * 0.3, now + dur);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, now);
      g.gain.exponentialRampToValueAtTime(0.4 / (i + 1), now + 0.03);
      g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
      const lp = ctx.createBiquadFilter();
      lp.type = "lowpass";
      lp.frequency.value = 4000;
      o.connect(lp).connect(g).connect(this.master);
      o.start(now); o.stop(now + dur);
    });

    // Sub-bass "thud"
    const sub = ctx.createOscillator();
    sub.type = "sine";
    sub.frequency.setValueAtTime(80, now);
    sub.frequency.exponentialRampToValueAtTime(20, now + 0.4);
    const subG = ctx.createGain();
    subG.gain.setValueAtTime(0.0001, now);
    subG.gain.exponentialRampToValueAtTime(0.9, now + 0.01);
    subG.gain.exponentialRampToValueAtTime(0.0001, now + 0.6);
    sub.connect(subG).connect(this.master);
    sub.start(now); sub.stop(now + 0.7);
  }

  // A short, sharp "stinger" used for small jumpscares
  stinger() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const dur = 0.5;
    const noise = ctx.createBufferSource();
    noise.buffer = this._noiseBuffer(dur);
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.setValueAtTime(3000, now);
    bp.frequency.exponentialRampToValueAtTime(400, now + dur);
    bp.Q.value = 4;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.9, now + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    noise.connect(bp).connect(g).connect(this.master);
    noise.start(now); noise.stop(now + dur);
  }

  doorCreak() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const now = ctx.currentTime;
    const dur = 0.9;
    const o = ctx.createOscillator();
    o.type = "sawtooth";
    o.frequency.setValueAtTime(120, now);
    o.frequency.exponentialRampToValueAtTime(60, now + dur);
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 7;
    const lfoG = ctx.createGain();
    lfoG.gain.value = 30;
    lfo.connect(lfoG).connect(o.frequency);
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.value = 400;
    bp.Q.value = 6;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.4, now + 0.05);
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    o.connect(bp).connect(g).connect(this.sfxGain);
    o.start(now); o.stop(now + dur);
    lfo.start(now); lfo.stop(now + dur);
  }

  _fadeIn(g, target, dur) {
    if (!this.ctx) return;
    g.gain.cancelScheduledValues(this.ctx.currentTime);
    g.gain.setValueAtTime(g.gain.value, this.ctx.currentTime);
    g.gain.linearRampToValueAtTime(target, this.ctx.currentTime + dur);
  }
}
