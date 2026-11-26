// Sons ElevenLabs existants (transcodés en AAC par tools/build_phaser_nemesis.py) joués en Web Audio.
// Chargement progressif après le premier toucher (exigence iOS) ; tant qu'un son manque, on retombe sur la synthèse.
const KEYS = [
  'rifle', 'harpoon', 'pistol', 'alien', 'acid', 'psi', 'hit', 'hit_alien', 'miss', 'step1', 'step2', 'step3', 'water',
  'sonar', 'explosion', 'heal', 'reload', 'click', 'confirm', 'deny', 'turn', 'alarm', 'pulse', 'terminal', 'objective',
  'nereide', 'carapace', 'spectre', 'airlock', 'cover', 'v_start', 'v_artifact', 'v_contact', 'v_ack', 'v_moving',
  'v_down', 'v_wounded', 'v_extract', 'v_success',
] as const;
export type SampleKey = (typeof KEYS)[number];

/** Volume relatif de chaque famille (mixage simple : armes devant, voix nettes, pas de saturation). */
const GAIN: Partial<Record<SampleKey, number>> = {
  step1: 0.35, step2: 0.35, step3: 0.35, water: 0.4, click: 0.5, confirm: 0.6, deny: 0.6, turn: 0.6,
  miss: 0.55, hit: 0.8, hit_alien: 0.8, alarm: 0.55, pulse: 0.8, sonar: 0.6,
};

export class Samples {
  private ctx: AudioContext | null = null;
  private fx!: GainNode;
  private voice!: GainNode;
  private amb!: GainNode;
  private buffers = new Map<string, AudioBuffer>();
  private lastVoice = 0;
  private ambSrc: AudioBufferSourceNode | null = null;
  private musBus!: GainNode;
  private mus = new Map<string, { el: HTMLAudioElement; g: GainNode }>();
  private curMusic = '';
  private wantMusic = '';
  fxVolume = 0.8;
  ambVolume = 0.5;

  constructor(private base: string) {}

  unlock(): void {
    if (this.ctx) { void this.ctx.resume(); return; }
    const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    const c = (this.ctx = new AC());
    const comp = c.createDynamicsCompressor(); // évite la saturation quand tirs, impacts et voix se superposent
    comp.threshold.value = -14; comp.ratio.value = 4; comp.connect(c.destination);
    this.fx = c.createGain(); this.fx.connect(comp);
    this.voice = c.createGain(); this.voice.connect(comp);
    this.amb = c.createGain(); this.amb.connect(comp);
    this.musBus = c.createGain(); this.musBus.connect(comp);
    this.setVolumes(this.fxVolume, this.ambVolume);
    if (this.wantMusic) this.music(this.wantMusic);
    void this.loadAll();
    // interruption (appel, verrouillage) : on coupe proprement et on reprend au retour
    document.addEventListener('visibilitychange', () => {
      if (!this.ctx) return;
      if (document.hidden) void this.ctx.suspend(); else void this.ctx.resume();
    });
  }

  private async loadAll() {
    const c = this.ctx!;
    await this.load('amb');
    this.startAmbience();
    for (const k of KEYS) {
      if (this.buffers.has(k)) continue;
      await this.load(k);
    }
    void c;
  }

  private async load(k: string) {
    try {
      const r = await fetch(`${this.base}sfx/${k}.m4a`);
      if (!r.ok) return;
      const data = await r.arrayBuffer();
      const buf = await new Promise<AudioBuffer>((ok, ko) => this.ctx!.decodeAudioData(data, ok, ko));
      this.buffers.set(k, buf);
    } catch { /* son absent ou format refusé : la synthèse prend le relais */ }
  }

  private startAmbience() {
    const b = this.buffers.get('amb');
    if (!b || !this.ctx || this.ambSrc) return;
    const s = this.ctx.createBufferSource();
    s.buffer = b; s.loop = true; s.connect(this.amb); s.start();
    this.ambSrc = s;
  }

  setVolumes(fx: number, amb: number): void {
    this.fxVolume = fx; this.ambVolume = amb;
    if (!this.ctx) return;
    this.fx.gain.value = fx; this.voice.gain.value = Math.min(1, fx * 1.1); this.amb.gain.value = amb * 0.7; this.musBus.gain.value = amb * 0.55;
  }

  has(k: string) { return this.buffers.has(k); }

  /** Musique en boucle (public/nemesis/music/<nom>.m4a), fondu enchaîné ; attend le premier toucher (iOS). */
  music(name: string): void {
    this.wantMusic = name;
    const c = this.ctx;
    if (!c || this.curMusic === name) return;
    const t = c.currentTime;
    for (const [k, m] of this.mus) if (k !== name) {
      m.g.gain.setTargetAtTime(0, t, 0.7);
      setTimeout(() => { if (this.curMusic !== k) m.el.pause(); }, 4000);
    }
    let m = this.mus.get(name);
    if (!m) {
      const el = new Audio(`${this.base}music/${name}.m4a`);
      el.loop = true; el.preload = 'auto';
      const g = c.createGain(); g.gain.value = 0;
      c.createMediaElementSource(el).connect(g); g.connect(this.musBus);
      m = { el, g }; this.mus.set(name, m);
    }
    this.curMusic = name;
    void m.el.play().catch(() => { /* lecture refusée : réessai au prochain appel */ this.curMusic = ''; });
    m.g.gain.setTargetAtTime(1, t, 0.9);
  }

  /** Joue un son ; renvoie false s'il n'est pas (encore) chargé. Les voix ne se chevauchent pas. */
  play(k: SampleKey, opts: { vol?: number; rate?: number; delay?: number } = {}): boolean {
    const b = this.buffers.get(k);
    if (!b || !this.ctx) return false;
    const voice = k.startsWith('v_');
    const now = this.ctx.currentTime;
    if (voice) {
      if (now < this.lastVoice) return true;
      this.lastVoice = now + b.duration + 0.4;
    }
    const s = this.ctx.createBufferSource(), g = this.ctx.createGain();
    s.buffer = b;
    s.playbackRate.value = opts.rate ?? 1;
    g.gain.value = (opts.vol ?? 1) * (GAIN[k] ?? 1);
    s.connect(g); g.connect(voice ? this.voice : this.fx);
    s.start(now + (opts.delay ?? 0));
    return true;
  }
}
