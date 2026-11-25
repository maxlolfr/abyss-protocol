// Démo Phaser 4 « salle Némésis » : rendu 2.5D premium (méthode hybride, directive V2 §5) sur la simulation TS.
// Sol précalculé + normal map, coque et cloisons texturées, objets et personnages issus des planches de Max,
// Light2D de Phaser 4 (lampes, alarmes, artefact, lampes frontales), particules, filtres caméra.
// La scène ne fait que LIRE l'état et rejouer les GameEvent ; elle respecte le contrat TacticalView du HUD.
import Phaser from 'phaser';
import type { GameEvent, MovePreview, TacticalEngine, Unit, Vec } from '../sim';
import { RULES, WEAPONS, idx, visibleTiles } from '../sim';
import { NEMESIS_MAP } from '../sim/map';
import type { TacticalView, Tone } from '../game/view';
import type { Samples, SampleKey } from './sfx';

export const TW = 128, TH = 64;
const WALL_H = { tall: 176, tall_lamp: 176, tall_red: 176, mid: 96, low: 22 } as const;
type WallKey = keyof typeof WALL_H;

export const toScreen = (x: number, y: number, z = 0) => ({ sx: ((x - y) * TW) / 2, sy: ((x + y) * TH) / 2 - z });
export function toTile(px: number, py: number) {
  const a = px / (TW / 2), b = py / (TH / 2);
  return { x: Math.round((a + b) / 2), y: Math.round((b - a) / 2) };
}
const depthOf = (x: number, y: number, layer = 0) => 1000 + (x + y) * 100 + layer;
const FX = 900000;

/** Apparence de chaque unité : planche, hauteur à l'écran, lévitation. */
const LOOK: Record<string, { key: string; h: number; lift?: number; poses?: boolean }> = {
  // soldiers : planches de poses de Max (1 debout, 2 marche, 3 genou, 4 visée, 5 debout bis), tournés vers la droite
  s1: { key: 'walker', h: 152, poses: true }, s2: { key: 'okafor', h: 158, poses: true },
  s3: { key: 'lind', h: 150, poses: true }, s4: { key: 'moreau', h: 146, poses: true },
  nereide: { key: 'nereide', h: 162 }, carapace: { key: 'carapace', h: 150 }, spectre: { key: 'spectre', h: 140, lift: 34 },
};
const SHOT_COLOR: Record<string, number> = { rifle: 0x9ff3ff, pistol: 0xc8f6ff, harpoon: 0xffd27a, dart: 0x7dffc4, acid: 0xb6ff4d, psi: 0xc58bff };
const SHOT_SOUND: Record<string, SampleKey> = { rifle: 'rifle', pistol: 'pistol', harpoon: 'harpoon', dart: 'alien', acid: 'acid', psi: 'psi' };
const BLOOD: Record<string, number> = { soldier: 0x8a1010, nereide: 0x1fd6b0, carapace: 0x9b4dff, spectre: 0xc9a0ff };

/** Objets de couverture (cases basses), dans l'ordre de lecture de la carte. */
/** Cloisons internes (#) : blocs de machinerie de la station plutôt que des cubes nus (bloquent la vue). */
const MACHINES = ['k007_1', 'k008_3', 'k007_2', 'p004_s4', 'p005_s1', 'k007_5'];
const COVER_PROPS = ['p009_s1', 'k005_1', 'p007_s1', 'p009_s2', 'k005_4', 'k005_5', 'p007_s4', 'k010_1', 'p009_s4', 'k005_1', 'p009_s1', 'p007_s1'];
/** Décor adossé à la coque : [x, y, objet, largeur max]. N'occupe que des cases de coque (jamais une case jouable). */
const WALL_DECOR: [number, number, string, number][] = [
  [1, 0, 'k008_3', 92], [3, 0, 'k006_4', 92], [5, 0, 'k007_3', 120], [7, 0, 'k006_2', 110], [8, 0, 'k009_6', 80],
  [9, 0, 'k009_1', 120], [11, 0, 'k008_1', 128], [13, 0, 'k006_3', 118], [14, 0, 'p006_s2', 120],
  [0, 2, 'k009_2', 70], [0, 4, 'k007_1', 120], [0, 6, 'k010_3', 120], [0, 9, 'k007_5', 118], [0, 11, 'p003_s4', 84],
];

interface UnitView {
  id: string; body: Phaser.GameObjects.Image; shadow: Phaser.GameObjects.Image; light?: Phaser.GameObjects.Light;
  glow?: Phaser.GameObjects.Image; key: string; scale: number; lift: number; x: number; y: number;
  flip: boolean; view: string; phase: number; walk: number; kick: number; dead: boolean; kneel: boolean;
  poses: boolean; aim: boolean; stride: number; tex: string;
}

interface Occluder { img: Phaser.GameObjects.Image; x: number; y: number }

export class NemesisScene extends Phaser.Scene implements TacticalView {
  engine!: TacticalEngine;
  sfx!: Samples;
  onTap: (p: Vec) => void = () => {};
  onLowFps: () => void = () => {};
  speed = 1;
  reduceFx = false;
  pixelRatio = 1;
  quality: 'haute' | 'allegee' = 'haute';
  private views = new Map<string, UnitView>();
  private objects = new Map<number, Occluder>();
  private occluders: Occluder[] = [];
  private fog!: Phaser.GameObjects.Graphics;
  private overlay!: Phaser.GameObjects.Graphics;
  private aim!: Phaser.GameObjects.Graphics;
  private marks!: Phaser.GameObjects.Graphics;
  private ring!: Phaser.GameObjects.Image;
  private labels: Phaser.GameObjects.Text[] = [];
  private artifact!: Phaser.GameObjects.Image;
  private artifactGlow!: Phaser.GameObjects.Image;
  private artifactLight!: Phaser.GameObjects.Light;
  private alarms: { light: Phaser.GameObjects.Light; glow: Phaser.GameObjects.Image }[] = [];
  private bloom: Phaser.Types.Actions.AddEffectBloomReturn[] = [];
  private selected: string | null = null;
  private visible: Uint8Array = new Uint8Array(0);
  private pinch: { d: number; z: number } | null = null;
  private drag = { active: false, moved: false, x: 0, y: 0, sx: 0, sy: 0 };
  private perf = { t: 0, frames: 0, slow: 0, degraded: false };
  private alert = false;

  constructor() { super('nemesis'); }

  init(data: { engine: TacticalEngine; sfx: Samples; pixelRatio: number; quality: 'haute' | 'allegee' }) {
    this.engine = data.engine; this.sfx = data.sfx; this.pixelRatio = data.pixelRatio; this.quality = data.quality;
    this.views.clear(); this.objects.clear(); this.occluders = []; this.alarms = []; this.labels = []; this.alert = false;
  }

  preload() {
    if (this.textures.exists('floor')) return;
    this.load.setPath('nemesis/');
    this.load.image('floor', ['floor.webp', 'floor_n.webp']);
    for (const w of Object.keys(WALL_H)) this.load.image(`wall_${w}`, [`walls/${w}.webp`, `walls/${w}_n.webp`]);
    const props = new Set([...COVER_PROPS, ...MACHINES, ...WALL_DECOR.map(d => d[2]), 'p001_s4', 'k009_3', 'k006_4']);
    for (const p of props) this.load.image(p, `props/${p}.webp`);
    for (const k of ['walker', 'okafor', 'lind', 'moreau'])
      for (let i = 1; i <= 5; i++) this.load.image(`${k}_${i}`, `units/${k}_${i}.webp`);
    for (const k of ['nereide', 'carapace', 'spectre'])
      for (const v of ['front', 'q34', 'side', 'rear']) this.load.image(`${k}_${v}`, `units/${k}_${v}.webp`);
    for (const f of ['glow', 'spark', 'mote', 'bubble', 'shadow', 'smoke', 'muzzle', 'splat', 'ring', 'water_a', 'water_b'])
      this.load.image(`fx_${f}`, `fx/${f}.png`);
    // barre de chargement sobre (chargement progressif : la scène s'affiche dès que les images sont prêtes)
    const bar = this.add.graphics();
    this.load.on('progress', (v: number) => {
      const w = this.scale.width, h = this.scale.height;
      bar.clear().fillStyle(0x0b1a24, 1).fillRect(w * 0.3, h * 0.5, w * 0.4, 4).fillStyle(0x5cf2ff, 1).fillRect(w * 0.3, h * 0.5, w * 0.4 * v, 4);
    });
    this.load.once('complete', () => bar.destroy());
  }

  create() {
    const s = this.engine.state;
    this.cameras.main.setBackgroundColor(0x02070b);
    this.lights.enable().setAmbientColor(0x44566c);

    const f = toScreen(0, 0);
    this.add.image(f.sx - s.height * (TW / 2), f.sy - TH / 2, 'floor').setOrigin(0, 0).setDepth(0).setLighting(true);
    this.buildWater();
    this.buildWalls();
    this.buildProps();
    this.buildArtifact();
    this.buildLights();
    for (const u of s.units) this.makeUnitView(u);

    this.fog = this.add.graphics().setDepth(5);
    this.overlay = this.add.graphics().setDepth(6);
    this.ring = this.add.image(0, 0, 'fx_ring').setDepth(7).setBlendMode(Phaser.BlendModes.ADD).setTint(0x6ff6ff).setVisible(false);
    this.tweens.add({ targets: this.ring, alpha: 0.45, duration: 700, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    this.aim = this.add.graphics().setDepth(FX);
    this.marks = this.add.graphics().setDepth(FX + 1);
    this.atmosphere();
    this.setupCamera();
    this.refresh();
    this.game.canvas.addEventListener('webglcontextlost', () => this.events.emit('contextlost'));
  }

  // ---------------------------------------------------------------- construction du décor

  private buildWater() {
    const s = this.engine.state;
    s.tiles.forEach((t, i) => {
      if (t !== 'water') return;
      const x = i % s.width, y = Math.floor(i / s.width), p = toScreen(x, y);
      const a = this.add.image(p.sx, p.sy + 3, 'fx_water_a').setDepth(1).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0.8);
      const b = this.add.image(p.sx, p.sy + 3, 'fx_water_b').setDepth(1).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0);
      const d = 1800 + ((x * 7 + y * 3) % 5) * 200;
      this.tweens.add({ targets: a, alpha: 0.15, duration: d, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
      this.tweens.add({ targets: b, alpha: 0.75, duration: d, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    });
  }

  private wallKind(x: number, y: number): WallKey {
    const s = this.engine.state;
    if (y === 0) return x === 4 || x === 10 ? 'tall_lamp' : 'tall';
    if (x === 0) return y === 8 ? 'tall_red' : y === 12 ? 'tall_lamp' : 'tall';
    if (y === s.height - 1 || x === s.width - 1) return 'low';
    return 'mid';
  }

  private buildWalls() {
    const s = this.engine.state;
    for (let y = 0; y < s.height; y++)
      for (let x = 0; x < s.width; x++) {
        if (s.tiles[idx(s, x, y)] !== 'wall') continue;
        const k = this.wallKind(x, y), h = WALL_H[k], p = toScreen(x, y);
        if (k === 'mid') {
          const img = this.propImage(MACHINES[(x * 3 + y) % MACHINES.length]!, x, y, 126, 150, 50).setSelfShadow(true, 0.5, 1 / 3);
          const o = { img, x, y };
          this.objects.set(idx(s, x, y), o);
          this.occluders.push(o);
          continue;
        }
        const img = this.add.image(p.sx, p.sy, `wall_${k}`).setOrigin(0.5, (TH / 2 + h) / (TH + h)).setDepth(depthOf(x, y, 40)).setLighting(true);
        const o = { img, x, y };
        this.objects.set(idx(s, x, y), o);
      }
  }

  private propImage(key: string, x: number, y: number, maxW: number, maxH: number, layer: number, fx = 0, fy = 0) {
    const p = toScreen(x + fx, y + fy);
    const img = this.add.image(p.sx, p.sy + TH * 0.22, key).setOrigin(0.5, 0.92).setDepth(depthOf(x, y, layer)).setLighting(true);
    const src = this.textures.get(key).getSourceImage() as HTMLImageElement;
    img.setScale(Math.min(maxW / src.width, maxH / src.height));
    return img;
  }

  private buildProps() {
    const s = this.engine.state;
    let n = 0;
    NEMESIS_MAP.forEach((row, y) => [...row].forEach((ch, x) => {
      if (!'ckT'.includes(ch)) return;
      const key = ch === 'T' ? 'p001_s4' : ch === 'k' ? 'k006_4' : COVER_PROPS[n++ % COVER_PROPS.length]!;
      const img = this.propImage(key, x, y, ch === 'T' ? 110 : 112, ch === 'T' ? 150 : 118, 50);
      img.setSelfShadow(true, 0.5, 1 / 3);
      const o = { img, x, y };
      this.objects.set(idx(s, x, y), o);
      this.occluders.push(o);
    }));
    for (const [x, y, key, w] of WALL_DECOR) {
      const north = y === 0;
      const img = this.propImage(key, x, y, w, 190, 60, north ? 0 : 0.42, north ? 0.42 : 0);
      img.setSelfShadow(true, 0.6, 1 / 3);
    }
  }

  private buildArtifact() {
    const a = this.engine.state.objectives.artifact ?? { x: 7, y: 1 };
    const p = toScreen(a.x, a.y);
    this.artifactGlow = this.add.image(p.sx, p.sy - 50, 'fx_glow').setDepth(depthOf(a.x, a.y, 55)).setBlendMode(Phaser.BlendModes.ADD).setTint(0x9a5cff).setScale(1.4, 1.1).setAlpha(0.55);
    this.artifact = this.add.image(p.sx, p.sy - 56, 'k009_3').setDepth(depthOf(a.x, a.y, 60)).setScale(0.36);
    this.tweens.add({ targets: this.artifact, y: p.sy - 68, duration: 1600, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    this.tweens.add({ targets: this.artifact, angle: 6, duration: 2300, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    this.tweens.add({ targets: this.artifactGlow, alpha: 0.25, scale: 1.2, duration: 1300, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
  }

  private light(x: number, y: number, r: number, c: number, i: number, z = 120) {
    const p = toScreen(x, y);
    return this.lights.addLight(p.sx, p.sy, r, c, i, z);
  }

  private buildLights() {
    const s = this.engine.state;
    // plafonniers froids (un qui clignote : station endommagée)
    this.light(4, 4, 600, 0xa9d6ff, 1.3, 260);
    this.light(10.5, 5, 600, 0xa9d6ff, 1.2, 260);
    const flick = this.light(7, 9.5, 480, 0xbfe4ff, 1.0, 240);
    this.time.addEvent({
      delay: 140, loop: true,
      callback: () => { flick.intensity = Math.random() < 0.12 ? 0.15 : 0.9 + Math.random() * 0.2; },
    });
    // appliques le long de la coque : éclairent les murs du fond (sinon de simples silhouettes)
    for (const [x, y] of [[2, 0.7], [7, 0.7], [12.5, 0.7], [0.7, 3.5], [0.7, 7], [0.7, 10]] as const) this.light(x, y, 260, 0x8fc4e8, 0.9, 140);
    // bandeaux cyan de la coque
    for (const [x, y] of [[4, 0.6], [10, 0.6], [0.6, 12]] as const) {
      this.light(x, y, 300, 0x48dcff, 1.0, 90);
      const p = toScreen(x, y);
      this.add.image(p.sx, p.sy - 70, 'fx_glow').setDepth(depthOf(Math.floor(x), Math.floor(y), 45)).setBlendMode(Phaser.BlendModes.ADD).setTint(0x48dcff).setScale(0.9, 0.5).setAlpha(0.35);
    }
    // alarme rouge (s'intensifie à l'alerte)
    for (const [x, y] of [[0.6, 8], [14.4, 13]] as const) {
      const p = toScreen(x, y);
      const glow = this.add.image(p.sx, p.sy - 60, 'fx_glow').setDepth(FX - 10).setBlendMode(Phaser.BlendModes.ADD).setTint(0xff3020).setScale(1.2, 0.8).setAlpha(0.2);
      this.alarms.push({ light: this.light(x, y, 340, 0xff3020, 0.45, 90), glow });
    }
    // terminal, bassins, artefact
    const t = s.objectives.terminal;
    this.light(t.x, t.y + 0.4, 280, 0x40e0ff, 1.4, 80);
    this.light(1.5, 7.5, 260, 0x1fb0b0, 0.9, 50);
    this.light(13.8, 7.5, 260, 0x1fb0b0, 0.9, 50);
    const a = s.objectives.artifact ?? { x: 7, y: 1 };
    this.artifactLight = this.light(a.x, a.y, 460, 0x9a5cff, 2.0, 90);
    this.tweens.add({ targets: this.artifactLight, intensity: 1.1, duration: 1300, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
  }

  private makeUnitView(u: Unit) {
    const look = LOOK[u.faction === 'human' ? u.id : u.kind] ?? LOOK.s3!;
    const { sx, sy } = toScreen(u.x, u.y);
    const shadow = this.add.image(sx, sy + 4, 'fx_shadow').setDepth(4).setScale(u.kind === 'carapace' ? 1.5 : 0.95, u.kind === 'carapace' ? 1.4 : 0.95).setAlpha(0.75);
    const first = look.poses ? `${look.key}_1` : `${look.key}_q34`;
    const tex = this.textures.get(first).getSourceImage() as HTMLImageElement;
    const scale = look.h / tex.height;
    const body = this.add.image(sx, sy, first).setOrigin(0.5, 0.97).setScale(scale).setLighting(true);
    const v: UnitView = {
      id: u.id, body, shadow, key: look.key, scale, lift: look.lift ?? 0, x: sx, y: sy, flip: false, view: 'q34',
      phase: (u.x * 1.7 + u.y * 2.3) % 6.28, walk: 0, kick: 0, dead: !u.alive, kneel: u.kneeling,
      poses: !!look.poses, aim: false, stride: 0, tex: first,
    };
    if (u.faction === 'human') {
      v.light = this.lights.addLight(sx, sy, 230, 0xdff4ff, 0.85, 70); // lampe frontale
      this.face(v, 0, -1);
    } else {
      this.face(v, 0, 1);
      const c = u.kind === 'spectre' ? 0xb07dff : u.kind === 'nereide' ? 0x3ff0d0 : 0x8f5cff;
      v.glow = this.add.image(sx, sy - look.h * 0.5, 'fx_glow').setBlendMode(Phaser.BlendModes.ADD).setTint(c).setScale(0.55).setAlpha(u.kind === 'carapace' ? 0.18 : 0.28);
    }
    this.views.set(u.id, v);
  }

  /** Orientation à 4 vues (+ miroir) d'après le déplacement en cases. Planches : profil et 3/4 regardent vers la gauche. */
  private face(v: UnitView, dx: number, dy: number) {
    const sx = Math.sign(dx - dy), sy = Math.sign(dx + dy);
    if (v.poses) { // planches de face uniquement : on choisit le côté (pas encore de vue de dos, voir doc)
      if (sx !== 0) v.flip = sx < 0;
      return;
    }
    let view = 'q34', flip = false;
    if (sy > 0 && sx === 0) view = 'front';
    else if (sy < 0 && sx === 0) view = 'rear';
    else if (sy === 0) { view = 'side'; flip = sx > 0; }
    else if (sy > 0) { view = 'q34'; flip = sx > 0; }
    else { view = 'rear'; flip = sx > 0; }
    v.view = view; v.flip = flip;
    v.body.setTexture(`${v.key}_${view}`);
    const src = this.textures.get(`${v.key}_${view}`).getSourceImage() as HTMLImageElement;
    v.scale = (LOOK[v.key]?.h ?? 150) / src.height;
  }

  /** Pose courante d'un soldat : genou, visée (tir, surveillance), marche (2 images alternées), debout. */
  private pose(v: UnitView, u: Unit) {
    const n = v.kneel ? 3 : v.aim || (u.watching && !v.walk) ? 4 : v.walk > 0 ? (v.stride % 2 ? 2 : 1) : 1;
    const key = `${v.key}_${n}`;
    if (key !== v.tex) { v.tex = key; v.body.setTexture(key); }
  }

  private atmosphere() {
    const s = this.engine.state;
    const a = toScreen(0, s.height), b = toScreen(s.width, 0), c = toScreen(s.width, s.height);
    const zone = new Phaser.Geom.Rectangle(a.sx, -200, b.sx - a.sx, c.sy + 200);
    const lite = this.quality === 'allegee';
    // neige marine en suspension
    this.add.particles(0, 0, 'fx_mote', {
      emitZone: { type: 'random', source: zone } as never, lifespan: 11000, speedY: { min: 3, max: 9 }, speedX: { min: -5, max: 5 },
      alpha: { start: 0.55, end: 0 }, scale: { min: 0.4, max: 1.1 }, frequency: lite ? 220 : 90, quantity: 1,
    }).setDepth(FX - 20);
    // bulles des bassins
    for (const [x, y] of [[1.5, 7.5], [14, 8]] as const) {
      const p = toScreen(x, y);
      this.add.particles(p.sx, p.sy, 'fx_bubble', {
        lifespan: 2600, speedY: { min: -46, max: -26 }, speedX: { min: -6, max: 6 }, scale: { min: 0.5, max: 1.2 },
        alpha: { start: 0.85, end: 0 }, frequency: 300, x: { min: -40, max: 40 }, y: { min: -10, max: 10 },
      }).setDepth(depthOf(Math.floor(x), Math.floor(y), 80));
    }
    // vapeur qui fuit d'une conduite (coin nord-est)
    const pipe = toScreen(14, 0.5);
    this.add.particles(pipe.sx + 20, pipe.sy - 70, 'fx_smoke', {
      lifespan: 2400, speedY: { min: -30, max: -15 }, speedX: { min: -24, max: -8 }, scale: { start: 0.25, end: 1.1 },
      alpha: { start: 0.22, end: 0 }, frequency: lite ? 260 : 140,
    }).setDepth(FX - 30);
    // étincelles d'une console endommagée
    const con = toScreen(11, 0.5);
    const sparks = this.add.particles(con.sx + 10, con.sy - 60, 'fx_spark', {
      lifespan: 500, speed: { min: 60, max: 160 }, angle: { min: 200, max: 340 }, gravityY: 420, scale: { start: 0.35, end: 0 },
      tint: 0xffc070, blendMode: 'ADD', emitting: false,
    }).setDepth(FX - 30);
    const sl = this.lights.addLight(con.sx + 10, con.sy - 30, 180, 0xffb060, 0, 80);
    this.time.addEvent({
      delay: 2600, loop: true, callback: () => {
        if (this.reduceFx) return;
        sparks.explode(8);
        sl.intensity = 1.8;
        this.tweens.add({ targets: sl, intensity: 0, duration: 260 });
      },
    });
    // particules violettes autour de l'artefact
    const art = s.objectives.artifact ?? { x: 7, y: 1 }, ap = toScreen(art.x, art.y);
    this.add.particles(ap.sx, ap.sy - 40, 'fx_spark', {
      lifespan: 2200, speedY: { min: -30, max: -10 }, x: { min: -50, max: 50 }, y: { min: -10, max: 20 },
      scale: { start: 0.25, end: 0 }, alpha: { start: 0.9, end: 0 }, tint: [0xb98aff, 0x6ff6ff], blendMode: 'ADD', frequency: 160,
    }).setDepth(depthOf(art.x, art.y, 65));

    const cam = this.cameras.main;
    cam.filters.external.addVignette(0.5, 0.5, 0.9, 0.55, 0x00050a);
    if (!lite) this.bloom = Phaser.Actions.AddEffectBloom(cam, { threshold: 0.62, blurRadius: 2, blurSteps: 3, blurQuality: 0, blendAmount: 0.55 });
  }

  // ---------------------------------------------------------------- caméra et contrôles

  private setupCamera() {
    const cam = this.cameras.main, s = this.engine.state;
    const left = toScreen(0, s.height).sx - TW, right = toScreen(s.width, 0).sx + TW;
    const top = -WALL_H.tall - 60, bottom = toScreen(s.width, s.height).sy + 60;
    cam.setBounds(left - 300, top - 300, right - left + 600, bottom - top + 600);
    const fit = Math.min(this.scale.width / (right - left), this.scale.height / (bottom - top));
    this.baseZoom = Phaser.Math.Clamp(fit * 1.55, 0.35 * this.pixelRatio, 2.4 * this.pixelRatio);
    cam.setZoom(this.baseZoom);
    const start = this.engine.soldiers[0]!;
    const c = toScreen((start.x + 7.5) / 2, (start.y + 6) / 2);
    cam.centerOn(c.sx, c.sy);
    this.input.addPointer(1);
    const zmin = fit * 0.95, zmax = 2.6 * this.pixelRatio;
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      Object.assign(this.drag, { active: true, moved: false, x: p.x, y: p.y, sx: cam.scrollX, sy: cam.scrollY });
    });
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      const p1 = this.input.pointer1, p2 = this.input.pointer2;
      if (p1.isDown && p2.isDown) {
        const d = Phaser.Math.Distance.Between(p1.x, p1.y, p2.x, p2.y);
        if (!this.pinch) this.pinch = { d, z: cam.zoom };
        cam.setZoom(Phaser.Math.Clamp((this.pinch.z * d) / this.pinch.d, zmin, zmax));
        this.drag.moved = true;
        return;
      }
      if (!this.drag.active || !p.isDown) return;
      const dx = p.x - this.drag.x, dy = p.y - this.drag.y;
      if (Math.hypot(dx, dy) > 12 * this.pixelRatio) this.drag.moved = true;
      if (this.drag.moved) cam.setScroll(this.drag.sx - dx / cam.zoom, this.drag.sy - dy / cam.zoom);
    });
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => {
      if (!this.input.pointer1.isDown && !this.input.pointer2.isDown) this.pinch = null;
      if (this.drag.active && !this.drag.moved) {
        const w = cam.getWorldPoint(p.x, p.y);
        const t = this.pickTile(w.x, w.y);
        if (t) this.onTap(t);
      }
      this.drag.active = false;
    });
    this.input.on('wheel', (_p: unknown, _o: unknown, _dx: number, dy: number) => {
      cam.setZoom(Phaser.Math.Clamp(cam.zoom * (dy > 0 ? 0.9 : 1.1), zmin, zmax));
    });
  }
  private baseZoom = 1;

  /** Case touchée : d'abord une unité visible sous le doigt (les sprites sont hauts), sinon le sol. */
  private pickTile(wx: number, wy: number): Vec | null {
    const s = this.engine.state;
    let best: { u: Unit; d: number } | null = null;
    for (const u of s.units) {
      const v = this.views.get(u.id);
      if (!v || !v.body.visible || v.dead) continue;
      const top = v.y - v.lift - v.body.displayHeight, w = Math.abs(v.body.displayWidth) * 0.4;
      if (wx > v.x - w && wx < v.x + w && wy > top && wy < v.y + 8) {
        const d = Math.abs(wy - (v.y - v.body.displayHeight * 0.5));
        if (!best || d < best.d) best = { u, d };
      }
    }
    if (best) return { x: best.u.x, y: best.u.y };
    const t = toTile(wx, wy);
    return t.x >= 0 && t.y >= 0 && t.x < s.width && t.y < s.height ? t : null;
  }

  centerOn(p: Vec, ms = 350) {
    const { sx, sy } = toScreen(p.x, p.y);
    if (ms === 0) this.cameras.main.centerOn(sx, sy - 40);
    else this.cameras.main.pan(sx, sy - 40, ms, 'Sine.easeInOut');
  }

  worldOf(p: Vec) { return toScreen(p.x, p.y); }

  select(id: string | null) { this.selected = id; this.drawMarks(); }

  // ---------------------------------------------------------------- état -> affichage

  refresh() {
    const s = this.engine.state;
    this.visible = visibleTiles(s, 'human');
    this.drawFog();
    for (const u of s.units) {
      const v = this.views.get(u.id)!;
      const shown = !u.evacuated && (u.faction === 'human' || this.visible[idx(s, u.x, u.y)] === 1 || !u.alive);
      if (!v.dead && u.alive) {
        const p = toScreen(u.x, u.y);
        v.x = p.sx; v.y = p.sy;
      }
      v.kneel = u.kneeling;
      v.body.setVisible(shown && (u.alive || v.dead));
      v.shadow.setVisible(shown && u.alive);
      v.glow?.setVisible(shown && u.alive);
      v.light?.setVisible(u.alive && !u.evacuated);
    }
    const art = s.objectives.artifact;
    this.artifact.setVisible(!!art);
    this.artifactGlow.setVisible(!!art);
    if (art) {
      const p = toScreen(art.x, art.y);
      this.artifact.setDepth(depthOf(art.x, art.y, 60));
      this.artifactGlow.setPosition(p.sx, p.sy - 50);
      this.artifactLight.setPosition(p.sx, p.sy);
    }
    this.drawMarks();
  }

  /** Brouillard : sombre sur l'inexploré, voile léger sur ce qui n'est plus vu. */
  private drawFog() {
    const s = this.engine.state, g = this.fog;
    g.clear();
    s.tiles.forEach((t, i) => {
      if (this.visible[i] || t === 'wall') return;
      const x = i % s.width, y = Math.floor(i / s.width), p = toScreen(x, y);
      g.fillStyle(0x01040a, s.explored[i] ? 0.42 : 0.82);
      this.diamond(g, p.sx, p.sy, 1.0);
    });
    for (const o of this.objects.values()) {
      const seen = this.visible[idx(s, o.x, o.y)] || s.explored[idx(s, o.x, o.y)];
      o.img.setTint(seen ? 0xffffff : 0x3a4048);
    }
  }

  /** Barres de vie, anneau de sélection, états. */
  private drawMarks() {
    const g = this.marks;
    g.clear();
    for (const l of this.labels) l.destroy();
    this.labels = [];
    const s = this.engine.state;
    this.ring.setVisible(false);
    for (const u of s.units) {
      const v = this.views.get(u.id)!;
      if (!v.body.visible || !u.alive) continue;
      const x = v.x, y = v.y - v.lift - v.body.displayHeight - 14;
      const w = 46, frac = u.hp / u.maxHp;
      g.fillStyle(0x000000, 0.65).fillRoundedRect(x - w / 2 - 2, y - 2, w + 4, 9, 3);
      g.fillStyle(u.faction === 'human' ? (frac > 0.35 ? 0x5cf2ff : 0xffa63d) : 0xff5a4a, 1).fillRoundedRect(x - w / 2, y, w * frac, 5, 2);
      if (u.id === this.selected) {
        this.ring.setVisible(true).setPosition(x, v.y + 2).setScale(u.kind === 'carapace' ? 1.2 : 0.75);
      }
      const icons = (u.watching ? '◉' : '') + (u.kneeling ? '▼' : '') + (u.carrying ? '◆' : '') + (u.wounds ? '✚' : '');
      if (icons) this.labels.push(this.add.text(x, y - 16, icons, { fontFamily: 'system-ui', fontSize: '18px', color: '#ffd27a', stroke: '#000', strokeThickness: 4, resolution: 2 }).setOrigin(0.5).setDepth(FX + 2));
    }
  }

  showReach(u: Unit | null) {
    const g = this.overlay;
    g.clear();
    if (!u || !u.alive) return;
    const s = this.engine.state, r = this.engine.reach(u);
    const keep = WEAPONS[u.weapon]!.snap.tu;
    for (const [i, c] of r.cost) {
      if (c === 0) continue;
      const x = i % s.width, y = Math.floor(i / s.width), p = toScreen(x, y);
      const col = u.tu - c >= keep ? 0x2fd6ff : 0xffa63d;
      g.fillStyle(col, 0.2);
      this.diamond(g, p.sx, p.sy, 0.9);
      g.lineStyle(1.5, col, 0.5);
      this.diamond(g, p.sx, p.sy, 0.9, true);
    }
  }

  showMovePreview(u: Unit, p: MovePreview | null) {
    this.showReach(u);
    this.aim.clear();
    if (!p) return;
    const g = this.overlay;
    const pts = [toScreen(u.x, u.y), ...p.path.map(q => toScreen(q.x, q.y))];
    for (const [w, a] of [[9, 0.18], [3, 0.95]] as const) {
      g.lineStyle(w, 0x9ff3ff, a);
      g.beginPath(); g.moveTo(pts[0]!.sx, pts[0]!.sy);
      for (const q of pts.slice(1)) g.lineTo(q.sx, q.sy);
      g.strokePath();
    }
    const last = p.path[p.path.length - 1]!, q = toScreen(last.x, last.y);
    g.lineStyle(3, p.reactors ? 0xffa63d : 0x9ff3ff, 1);
    this.diamond(g, q.sx, q.sy, 0.92, true);
    // boucliers de couverture autour de la destination
    const s = this.engine.state;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]] as const) {
      const k = s.tiles[idx(s, last.x + dx, last.y + dy)];
      if (k !== 'wall' && k !== 'low') continue;
      const m = toScreen(last.x + dx * 0.42, last.y + dy * 0.42);
      g.fillStyle(0x000000, 0.6).fillCircle(m.sx, m.sy - 18, 11);
      g.fillStyle(k === 'wall' ? 0x5cf2ff : 0xffd27a, 1);
      g.fillTriangle(m.sx - 7, m.sy - 24, m.sx + 7, m.sy - 24, m.sx, m.sy - 9);
    }
  }

  showShot(from: Vec, to: Vec, chance: number) {
    const g = this.aim;
    g.clear();
    const a = toScreen(from.x, from.y, 80), b = toScreen(to.x, to.y, 70);
    const col = chance >= 50 ? 0x7dffb0 : chance >= 25 ? 0xffd27a : 0xff6a5a;
    g.lineStyle(6, col, 0.15).lineBetween(a.sx, a.sy, b.sx, b.sy);
    g.lineStyle(2, col, 0.95);
    const n = 18;
    for (let i = 0; i < n; i += 2) g.lineBetween(a.sx + ((b.sx - a.sx) * i) / n, a.sy + ((b.sy - a.sy) * i) / n, a.sx + ((b.sx - a.sx) * (i + 1)) / n, a.sy + ((b.sy - a.sy) * (i + 1)) / n);
    g.strokeCircle(b.sx, b.sy, 20).lineBetween(b.sx - 28, b.sy, b.sx - 14, b.sy).lineBetween(b.sx + 14, b.sy, b.sx + 28, b.sy);
  }

  showBlast(at: Vec | null, ok: boolean) {
    const g = this.aim;
    g.clear();
    if (!at) return;
    for (let y = at.y - RULES.grenadeRadius; y <= at.y + RULES.grenadeRadius; y++)
      for (let x = at.x - RULES.grenadeRadius; x <= at.x + RULES.grenadeRadius; x++) {
        const p = toScreen(x, y);
        g.fillStyle(ok ? 0xff7a3d : 0x888888, 0.2);
        this.diamond(g, p.sx, p.sy, 0.92);
      }
  }

  clearPreview() { this.overlay.clear(); this.aim.clear(); }

  private diamond(g: Phaser.GameObjects.Graphics, x: number, y: number, k: number, stroke = false) {
    const w = (TW / 2) * k, h = (TH / 2) * k;
    const pts = [new Phaser.Math.Vector2(x, y - h), new Phaser.Math.Vector2(x + w, y), new Phaser.Math.Vector2(x, y + h), new Phaser.Math.Vector2(x - w, y)];
    if (stroke) g.strokePoints(pts, true); else g.fillPoints(pts, true);
  }

  // ---------------------------------------------------------------- animation continue

  override update(time: number, delta: number) {
    const t = time / 1000;
    const s = this.engine.state;
    for (const [id, v] of this.views) {
      const u = this.engine.unit(id)!;
      if (v.dead) continue;
      const breathe = 1 + 0.013 * Math.sin(t * 2.4 + v.phase);
      let bob = 0, angle = 0, sx = 1;
      if (v.walk > 0) { bob = Math.abs(Math.sin(v.walk * Math.PI * 2)) * 6; angle = Math.sin(v.walk * Math.PI * 2) * 2.2; }
      if (u.kind === 'spectre') bob += 7 + 7 * Math.sin(t * 1.7 + v.phase);
      if (u.kind === 'nereide' && !v.walk) angle = 1.6 * Math.sin(t * 1.3 + v.phase);
      if (u.kind === 'carapace') sx = 1 + 0.018 * Math.sin(t * 1.1 + v.phase);
      if (v.poses) this.pose(v, u);
      const kneel = v.kneel && !v.poses ? 0.84 : 1;
      v.body.setPosition(v.x - v.kick * (v.flip ? -1 : 1), v.y - v.lift - bob);
      v.body.setScale(v.scale * sx * (v.flip ? -1 : 1), v.scale * breathe * kneel).setAngle(angle);
      v.body.setDepth(depthOf((v.x / (TW / 2) + v.y / (TH / 2)) / 2, (v.y / (TH / 2) - v.x / (TW / 2)) / 2, 70));
      v.shadow.setPosition(v.x, v.y + 4).setAlpha(u.kind === 'spectre' ? 0.45 - bob * 0.01 : 0.75);
      v.light?.setPosition(v.x + (v.flip ? 30 : -30), v.y + 10);
      v.glow?.setPosition(v.x, v.y - v.lift - bob - v.body.displayHeight * 0.55).setDepth(v.body.depth + 1);
    }
    if (this.selected) {
      const v = this.views.get(this.selected);
      if (v && this.ring.visible) this.ring.setPosition(v.x, v.y + 2);
    }
    this.xray(s);
    // alarme : gyrophare
    const k = this.alert ? 1 : 0.35;
    for (const [i, a] of this.alarms.entries()) {
      const w = 0.5 + 0.5 * Math.sin(t * (this.alert ? 6 : 2) + i * 2);
      a.light.intensity = (0.3 + 1.6 * w) * k;
      a.glow.setAlpha((0.08 + 0.4 * w) * k);
    }
    this.watchPerf(delta);
  }

  /** Cloisons et grosses caisses deviennent translucides quand elles cachent une unité visible. */
  private xray(s: TacticalEngine['state']) {
    for (const o of this.occluders) {
      let hide = false;
      const ox = o.img.x, oy = o.img.y;
      for (const u of s.units) {
        if (!u.alive || u.evacuated) continue;
        const v = this.views.get(u.id)!;
        if (!v.body.visible || u.x + u.y >= o.x + o.y) continue;
        if (Math.abs(v.x - ox) < 90 && oy - v.y > 0 && oy - v.y < 200) { hide = true; break; }
      }
      o.img.setAlpha(hide ? 0.38 : 1);
    }
  }

  /** Baisse automatique de qualité si le téléphone n'arrive pas à suivre (moyenne sur 3 s). */
  private watchPerf(delta: number) {
    const p = this.perf;
    p.t += delta; p.frames++;
    if (p.t < 3000) return;
    const fps = (p.frames * 1000) / p.t;
    p.t = 0; p.frames = 0;
    if (this.time.now < 6000 || p.degraded) return;
    p.slow = fps < 40 ? p.slow + 1 : 0;
    if (p.slow >= 2) {
      p.degraded = true;
      for (const b of this.bloom) b.parallelFilters.active = false;
      this.onLowFps();
    }
  }

  get fps() { return Math.round(this.game.loop.actualFps); }

  // ---------------------------------------------------------------- rejeu des événements

  private wait(ms: number) {
    if (this.speed >= 99) return Promise.resolve();
    return new Promise<void>(r => this.time.delayedCall(ms / this.speed, () => r()));
  }

  private tween(cfg: Phaser.Types.Tweens.TweenBuilderConfig) {
    return new Promise<void>(r => this.tweens.add({ ...cfg, duration: (cfg.duration as number) / Math.min(this.speed, 4), onComplete: () => r() }));
  }

  private say(k: SampleKey, opts?: { vol?: number; rate?: number; delay?: number }) {
    if (this.speed >= 99 && !k.startsWith('v_')) return;
    this.sfx.play(k, opts);
  }

  private floatText(p: Vec, text: string, color: string) {
    if (this.speed >= 99) return;
    const v = [...this.views.values()].find(w => { const u = this.engine.unit(w.id); return u && u.x === p.x && u.y === p.y; });
    const { sx, sy } = toScreen(p.x, p.y, v ? v.body.displayHeight + 30 : 110);
    const t = this.add.text(sx, sy, text, { fontFamily: 'system-ui, sans-serif', fontStyle: 'bold', fontSize: '24px', color, stroke: '#02070b', strokeThickness: 5, resolution: 2 }).setOrigin(0.5).setDepth(FX + 3);
    this.tweens.add({ targets: t, y: sy - 46, alpha: 0, duration: 1200 / Math.min(this.speed, 2), ease: 'Cubic.out', onComplete: () => t.destroy() });
  }

  private flash(x: number, y: number, color: number, radius: number, intensity: number, ms: number) {
    if (this.reduceFx || this.speed >= 99) return;
    const l = this.lights.addLight(x, y, radius, color, intensity, 80);
    this.tweens.add({ targets: l, intensity: 0, duration: ms, onComplete: () => this.lights.removeLight(l) });
  }

  /** Point de départ du tir : à hauteur d'arme, côté où regarde le tireur. */
  private muzzle(v: UnitView, tx: number, ty: number) {
    const h = v.body.displayHeight;
    const dir = Math.sign(tx - v.x) || 1;
    return { x: v.x + dir * Math.abs(v.body.displayWidth) * 0.3, y: v.y - v.lift - h * (this.engine.unit(v.id)?.faction === 'human' ? 0.58 : 0.5) + (ty > v.y ? 6 : -4) };
  }

  private splat(p: Vec, color: number, scale: number) {
    const q = toScreen(p.x, p.y);
    const s = this.add.image(q.sx + Phaser.Math.Between(-14, 14), q.sy + Phaser.Math.Between(-6, 6), 'fx_splat').setDepth(3).setTint(color).setAlpha(0).setScale(scale * 0.4).setAngle(Phaser.Math.Between(0, 360));
    this.tweens.add({ targets: s, alpha: 0.75, scale, duration: 260 });
  }

  async play(events: GameEvent[], banner: (text: string, tone?: Tone) => void): Promise<void> {
    const s = this.engine.state;
    const name = (id: string) => this.engine.unit(id)?.name ?? id;
    let moved = new Set<string>();
    for (const e of events) {
      switch (e.t) {
        case 'move': {
          const v = this.views.get(e.unit)!, u = this.engine.unit(e.unit)!;
          this.face(v, e.to.x - e.from.x, e.to.y - e.from.y);
          const { sx, sy } = toScreen(e.to.x, e.to.y);
          if (!e.seen || this.speed >= 99) {
            v.x = sx; v.y = sy;
            v.body.setVisible(e.seen); v.shadow.setVisible(e.seen); v.glow?.setVisible(e.seen);
            break;
          }
          v.body.setVisible(true); v.shadow.setVisible(true); v.glow?.setVisible(true);
          if (!moved.has(u.id)) {
            moved.add(u.id);
            if (u.faction === 'human' && Math.random() < 0.35) this.say('v_moving', { vol: 0.8 });
            if (u.kind === 'spectre') this.say('spectre', { vol: 0.6 });
          }
          const water = s.tiles[idx(s, e.to.x, e.to.y)] === 'water';
          this.say(water ? 'water' : (['step1', 'step2', 'step3'] as const)[(e.to.x + e.to.y) % 3]!, { rate: u.kind === 'carapace' ? 0.7 : 1 });
          const ms = u.kind === 'carapace' ? 300 : 230;
          v.walk = 0; v.stride++;
          this.tweens.add({ targets: v, walk: 0.999, duration: ms / Math.min(this.speed, 4), onComplete: () => { v.walk = 0; } });
          await this.tween({ targets: v, x: sx, y: sy, duration: ms });
          if (u.faction === 'human') { this.visible = visibleTiles(s, 'human'); this.drawFog(); }
          break;
        }
        case 'spotted': {
          const u = this.engine.unit(e.unit)!;
          this.say('sonar');
          if (u.faction === 'alien') {
            this.say(u.kind === 'carapace' ? 'carapace' : u.kind === 'nereide' ? 'nereide' : 'spectre', { delay: 0.25 });
            this.say('v_contact', { delay: 0.5 });
          }
          banner(`Contact sonar : ${u.name}`, 'warn');
          const v = this.views.get(e.unit)!;
          v.body.setVisible(true); v.shadow.setVisible(true); v.glow?.setVisible(true);
          if (s.side === 'alien') this.centerOn(u, 250 / Math.min(this.speed, 4));
          await this.wait(380);
          break;
        }
        case 'interrupt':
          if (this.engine.unit(e.unit)?.faction === 'human') banner(`${name(e.unit)} s'arrête : contact`, 'warn');
          break;
        case 'shot': await this.shot(e, banner); break;
        case 'damage': {
          const v = this.views.get(e.unit)!, u = this.engine.unit(e.unit)!;
          this.say(u.faction === 'human' ? 'hit' : 'hit_alien');
          if (u.faction === 'human' && e.wounded) this.say('v_wounded', { delay: 0.3 });
          this.floatText(u, e.amount ? `-${e.amount}${e.wounded ? ' ✚' : ''}` : 'Ricochet', '#ff7b6b');
          if (e.drained) this.floatText({ x: u.x, y: u.y - 0.6 }, `-${e.drained} UT`, '#c58bff');
          if (e.amount && this.speed < 99) {
            v.body.setTint(0xffffff).setTintMode(Phaser.TintModes.FILL);
            this.time.delayedCall(50, () => v.body.setTint(0xff5040).setTintMode(Phaser.TintModes.MULTIPLY));
            this.time.delayedCall(220, () => v.body.clearTint());
            v.kick = -8;
            this.tweens.add({ targets: v, kick: 0, duration: 260, ease: 'Back.out' });
            this.splat(u, BLOOD[u.kind] ?? 0x8a1010, 0.8);
            const p = toScreen(u.x, u.y);
            const burst = this.add.particles(p.sx, p.sy - v.body.displayHeight * 0.55, 'fx_spark', {
              speed: { min: 60, max: 220 }, lifespan: 420, scale: { start: 0.45, end: 0 }, tint: BLOOD[u.kind] ?? 0xff3030, emitting: false, gravityY: 300,
            }).setDepth(FX);
            burst.explode(14);
            this.time.delayedCall(700, () => burst.destroy());
          }
          if (u.faction === 'human' && !this.reduceFx) this.cameras.main.shake(140, 0.005);
          await this.wait(220);
          break;
        }
        case 'death': {
          const v = this.views.get(e.unit)!, u = this.engine.unit(e.unit)!;
          this.say(u.faction === 'human' ? 'v_down' : 'hit_alien', { rate: u.faction === 'human' ? 1 : 0.7 });
          banner(`${name(e.unit)} neutralisé${u.faction === 'human' ? ' — perte' : ''}`, u.faction === 'human' ? 'warn' : 'good');
          v.dead = true;
          v.light?.setVisible(false);
          v.glow?.setVisible(false);
          this.splat(u, BLOOD[u.kind] ?? 0x8a1010, 1.4);
          const fall = v.flip ? -84 : 84;
          await this.tween({ targets: v.body, angle: fall, y: v.y - v.lift * 0.2 + 6, alpha: 0.9, duration: 520, ease: 'Quad.in' });
          v.body.setTint(0x6a6f78).setDepth(depthOf(u.x, u.y, 20));
          this.tweens.add({ targets: v.shadow, alpha: 0, duration: 400 });
          break;
        }
        case 'explosion': {
          this.say('explosion');
          const { sx, sy } = toScreen(e.at.x, e.at.y);
          this.flash(sx, sy, 0xff8a3d, 520, 4.5, 700);
          if (!this.reduceFx) this.cameras.main.shake(300, 0.014);
          if (this.speed < 99) {
            const fire = this.add.particles(sx, sy - 20, 'fx_spark', { speed: { min: 80, max: 320 }, lifespan: 650, scale: { start: 1.4, end: 0 }, tint: [0xffe0a0, 0xff8a3d, 0xff4020], blendMode: 'ADD', emitting: false }).setDepth(FX);
            const smoke = this.add.particles(sx, sy - 20, 'fx_smoke', { speed: { min: 20, max: 80 }, lifespan: 1800, scale: { start: 0.6, end: 2 }, alpha: { start: 0.5, end: 0 }, tint: 0x40464c, emitting: false }).setDepth(FX - 1);
            fire.explode(50); smoke.explode(16);
            this.time.delayedCall(2000, () => { fire.destroy(); smoke.destroy(); });
            this.add.image(sx, sy, 'fx_splat').setTint(0x050505).setAlpha(0.7).setScale(2.2).setDepth(3);
          }
          await this.wait(480);
          break;
        }
        case 'destroy': {
          const o = this.objects.get(idx(s, e.at.x, e.at.y));
          this.say('cover');
          if (o) {
            this.occluders = this.occluders.filter(x => x !== o);
            this.objects.delete(idx(s, e.at.x, e.at.y));
            this.tweens.add({ targets: o.img, alpha: 0, y: o.img.y + 12, duration: 300, onComplete: () => o.img.destroy() });
          }
          break;
        }
        case 'heal': this.say('heal'); this.floatText(this.engine.unit(e.target)!, `+${e.amount}`, '#7dffb0'); await this.wait(300); break;
        case 'reload': this.say('reload'); this.floatText(this.engine.unit(e.unit)!, 'Rechargé', '#c9e6ff'); await this.wait(250); break;
        case 'kneel': this.say('click'); break;
        case 'watch': this.say('confirm'); this.say('v_ack', { delay: 0.2 }); this.floatText(this.engine.unit(e.unit)!, 'Surveillance', '#ffd27a'); break;
        case 'pickup': {
          this.say('pulse'); this.say('v_artifact', { delay: 0.6 });
          banner(`${name(e.unit)} récupère l'artefact`, 'good');
          const v = this.views.get(e.unit)!;
          await this.tween({ targets: [this.artifact, this.artifactGlow], x: v.x, y: v.y - 90, scale: 0.1, alpha: 0, duration: 500, ease: 'Cubic.in' });
          this.artifactLight.setVisible(false);
          break;
        }
        case 'alarm':
          this.alert = true;
          this.say('alarm');
          banner("L'artefact pulse : tous les hostiles convergent !", 'warn');
          this.lights.setAmbientColor(0x3a2a40);
          await this.wait(500);
          break;
        case 'logs': this.say('terminal'); banner('Journal du terminal téléchargé', 'good'); break;
        case 'drop': banner("L'artefact est tombé au sol", 'warn'); this.artifact.setAlpha(1).setScale(0.36); this.artifactGlow.setAlpha(0.5).setScale(1.3); this.artifactLight.setVisible(true); break;
        case 'bleed': this.floatText(this.engine.unit(e.unit)!, `-${e.amount} saignement`, '#ff9a8a'); break;
        case 'turn':
          moved = new Set();
          this.say('turn');
          banner(e.side === 'alien' ? 'Activité hostile…' : `Tour ${e.turn}`, 'info');
          break;
        case 'evacuate': this.say('airlock'); this.say('v_extract', { delay: 0.5 }); break;
        case 'outcome': if (e.outcome === 'victory') { this.say('objective'); this.say('v_success', { delay: 0.8 }); } break;
      }
    }
    this.refresh();
  }

  private async shot(e: Extract<GameEvent, { t: 'shot' }>, banner: (text: string, tone?: Tone) => void) {
    const w = WEAPONS[e.weapon]!;
    const sv = this.views.get(e.unit)!, tv = this.views.get(e.target);
    this.face(sv, e.to.x - e.from.x, e.to.y - e.from.y);
    if (e.reaction) banner(`Tir de réaction : ${this.engine.unit(e.unit)?.name ?? e.unit}`, 'warn');
    if (this.speed >= 99) { this.sfx.play(SHOT_SOUND[e.weapon] ?? 'rifle'); return; }
    sv.aim = true;
    this.time.delayedCall(700 / Math.min(this.speed, 4), () => { sv.aim = false; });
    await this.wait(160); // visée
    const color = SHOT_COLOR[e.weapon] ?? 0xffffff;
    const tgt = toScreen(e.to.x, e.to.y);
    const th = tv ? tv.body.displayHeight : 120;
    const end = { x: tgt.sx + (e.hit ? 0 : Phaser.Math.Between(-50, 50)), y: tgt.sy - th * 0.55 + (e.hit ? 0 : Phaser.Math.Between(-40, 10)) };
    const m = e.seen ? this.muzzle(sv, end.x, end.y) : { x: end.x - 220, y: end.y - 110 };
    this.say(SHOT_SOUND[e.weapon] ?? 'rifle');
    if (e.seen) {
      const f = this.add.image(m.x, m.y, 'fx_muzzle').setDepth(FX).setBlendMode(Phaser.BlendModes.ADD).setTint(color)
        .setRotation(Math.atan2(end.y - m.y, end.x - m.x)).setScale(0.55).setOrigin(0.1, 0.5);
      this.tweens.add({ targets: f, alpha: 0, scaleX: 0.9, duration: 110, onComplete: () => f.destroy() });
      this.flash(m.x, m.y, color, 220, 2.6, 180);
      sv.kick = 6;
      this.tweens.add({ targets: sv, kick: 0, duration: 200, ease: 'Quad.out' });
    }
    if (w.sound === 'psi' || e.weapon === 'psi') {
      // onde psychique : anneaux qui convergent sur la cible
      for (let i = 0; i < 3; i++) {
        const r = this.add.image(end.x, end.y, 'fx_ring').setDepth(FX).setBlendMode(Phaser.BlendModes.ADD).setTint(color).setScale(2.4).setAlpha(0);
        this.tweens.add({ targets: r, scale: 0.2, alpha: { from: 0.9, to: 0 }, delay: i * 90, duration: 420, onComplete: () => r.destroy() });
      }
      await this.wait(380);
    } else if (e.weapon === 'acid' || e.weapon === 'harpoon' || e.weapon === 'dart') {
      // projectile visible (acide en cloche, harpon et dard tendus)
      const proj = this.add.image(m.x, m.y, 'fx_spark').setDepth(FX).setBlendMode(Phaser.BlendModes.ADD).setTint(color).setScale(e.weapon === 'acid' ? 0.9 : 0.5);
      const arc = e.weapon === 'acid' ? 60 : 0;
      const o = { k: 0 };
      await this.tween({
        targets: o, k: 1, duration: e.weapon === 'acid' ? 380 : 200,
        onUpdate: () => proj.setPosition(m.x + (end.x - m.x) * o.k, m.y + (end.y - m.y) * o.k - Math.sin(o.k * Math.PI) * arc),
      } as Phaser.Types.Tweens.TweenBuilderConfig);
      proj.destroy();
    } else {
      // traceur lumineux
      const tr = this.add.graphics().setDepth(FX).setBlendMode(Phaser.BlendModes.ADD);
      tr.lineStyle(7, color, 0.22).lineBetween(m.x, m.y, end.x, end.y);
      tr.lineStyle(2, 0xffffff, 0.95).lineBetween(m.x, m.y, end.x, end.y);
      this.tweens.add({ targets: tr, alpha: 0, duration: 220, onComplete: () => tr.destroy() });
      await this.wait(90);
    }
    // impact
    const sparks = this.add.particles(end.x, end.y, 'fx_spark', {
      speed: { min: 40, max: 180 }, lifespan: 360, scale: { start: 0.4, end: 0 }, tint: e.hit ? color : 0xffd9a0, blendMode: 'ADD', emitting: false,
    }).setDepth(FX);
    sparks.explode(e.hit ? 8 : 12);
    this.time.delayedCall(600, () => sparks.destroy());
    this.flash(end.x, end.y + 40, color, 160, 1.4, 200);
    if (!e.hit) { this.say('miss', { delay: 0.05 }); this.floatText(e.to, `Raté (${e.chance} %)`, '#c9d6e0'); }
    await this.wait(200);
  }
}
