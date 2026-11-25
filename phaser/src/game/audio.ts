// AudioManager : sons synthétisés en Web Audio (aucun fichier). Deux volumes indépendants : effets et ambiance.
// Les sons ElevenLabs remplaceront ces synthèses après validation du gameplay (GDD §11).
export type Sfx =
  | 'rifle' | 'pistol' | 'harpoon' | 'alien' | 'acid' | 'psi' | 'hit' | 'miss' | 'step' | 'sonar'
  | 'explosion' | 'heal' | 'click' | 'confirm' | 'death' | 'alarm' | 'reload' | 'turn' | 'deny';

export class AudioManager {
  private ctx: AudioContext | null = null;
  private fx!: GainNode;
  private amb!: GainNode;
  private noise!: AudioBuffer;
  fxVolume = 0.8;
  ambVolume = 0.5;

  /** À appeler dans un geste utilisateur (iOS exige un toucher pour démarrer l'audio). */
  unlock(): void {
    if (this.ctx) { void this.ctx.resume(); return; }
    const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    const c = (this.ctx = new AC());
    this.fx = c.createGain(); this.fx.gain.value = this.fxVolume; this.fx.connect(c.destination);
    this.amb = c.createGain(); this.amb.gain.value = this.ambVolume; this.amb.connect(c.destination);
    this.noise = c.createBuffer(1, c.sampleRate, c.sampleRate);
    const d = this.noise.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; // bruit audio, hors simulation
    this.ambience();
  }

  setVolumes(fx: number, amb: number): void {
    this.fxVolume = fx; this.ambVolume = amb;
    if (this.ctx) { this.fx.gain.value = fx; this.amb.gain.value = amb; }
  }

  /** Grondement sourd des profondeurs + craquements de coque lents. */
  private ambience(): void {
    const c = this.ctx!;
    const o = c.createOscillator(), g = c.createGain(), f = c.createBiquadFilter(), lfo = c.createOscillator(), lg = c.createGain();
    o.type = 'sawtooth'; o.frequency.value = 42;
    f.type = 'lowpass'; f.frequency.value = 140;
    g.gain.value = 0.12;
    lfo.frequency.value = 0.07; lg.gain.value = 0.06; lfo.connect(lg); lg.connect(g.gain);
    o.connect(f); f.connect(g); g.connect(this.amb);
    o.start(); lfo.start();
    const n = c.createBufferSource(); n.buffer = this.noise; n.loop = true;
    const nf = c.createBiquadFilter(); nf.type = 'bandpass'; nf.frequency.value = 320; nf.Q.value = 0.6;
    const ng = c.createGain(); ng.gain.value = 0.05;
    n.connect(nf); nf.connect(ng); ng.connect(this.amb); n.start();
  }

  private tone(type: OscillatorType, f0: number, f1: number, dur: number, vol: number, delay = 0): void {
    const c = this.ctx!, t = c.currentTime + delay;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur);
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.fx); o.start(t); o.stop(t + dur + 0.02);
  }

  private burst(freq: number, q: number, dur: number, vol: number, type: BiquadFilterType = 'bandpass', delay = 0): void {
    const c = this.ctx!, t = c.currentTime + delay;
    const n = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain();
    n.buffer = this.noise; f.type = type; f.frequency.value = freq; f.Q.value = q;
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    n.connect(f); f.connect(g); g.connect(this.fx); n.start(t, Math.random() * 0.5); n.stop(t + dur + 0.02);
  }

  play(s: Sfx): void {
    if (!this.ctx) return;
    switch (s) {
      case 'rifle': this.burst(2200, 0.8, 0.12, 0.5); this.tone('square', 220, 60, 0.08, 0.15); break;
      case 'pistol': this.burst(3000, 1, 0.08, 0.4); break;
      case 'harpoon': this.tone('sawtooth', 160, 40, 0.25, 0.3); this.burst(800, 1, 0.2, 0.3); break;
      case 'alien': this.tone('sine', 900, 300, 0.22, 0.25); this.tone('triangle', 1350, 500, 0.18, 0.12); break;
      case 'acid': this.burst(600, 0.5, 0.35, 0.4, 'lowpass'); this.tone('sine', 140, 70, 0.3, 0.2); break;
      case 'psi': this.tone('sine', 200, 1200, 0.45, 0.2); this.tone('sine', 203, 1190, 0.45, 0.2); break;
      case 'hit': this.burst(400, 1, 0.15, 0.5, 'lowpass'); break;
      case 'miss': this.burst(5000, 2, 0.1, 0.15, 'highpass'); break;
      case 'step': this.burst(250, 3, 0.05, 0.12); break;
      case 'sonar': this.tone('sine', 1400, 1380, 0.6, 0.25); this.tone('sine', 1400, 1380, 0.4, 0.08, 0.35); break;
      case 'explosion': this.burst(180, 0.4, 1.1, 0.9, 'lowpass'); this.tone('sine', 80, 30, 0.8, 0.5); break;
      case 'heal': [660, 880, 1100].forEach((f, i) => this.tone('sine', f, f, 0.18, 0.15, i * 0.08)); break;
      case 'click': this.tone('square', 1200, 1100, 0.03, 0.06); break;
      case 'confirm': this.tone('triangle', 700, 1000, 0.08, 0.12); break;
      case 'deny': this.tone('square', 220, 180, 0.12, 0.08); break;
      case 'death': this.tone('sawtooth', 300, 40, 0.6, 0.25); break;
      case 'alarm': for (let i = 0; i < 3; i++) this.tone('square', 520, 380, 0.25, 0.12, i * 0.3); break;
      case 'reload': this.burst(1500, 4, 0.05, 0.3); this.burst(900, 4, 0.06, 0.3, 'bandpass', 0.12); break;
      case 'turn': this.tone('sine', 330, 330, 0.25, 0.12); this.tone('sine', 495, 495, 0.3, 0.1, 0.12); break;
    }
  }
}

export const audio = new AudioManager();
