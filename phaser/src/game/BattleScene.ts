// Rendu isométrique 2.5D de la bataille. Ne fait que LIRE l'état de la simulation et rejouer ses événements.
import Phaser from 'phaser';
import type { GameEvent, MovePreview, TacticalEngine, Unit, Vec } from '../sim';
import { RULES, WEAPONS, idx, inEvac, visibleTiles } from '../sim';
import { LOW_H, TH, dir8, depthOf, toScreen, toTile } from './iso';
import { makeTextures } from './textures';
import { audio, type Sfx } from './audio';

interface UnitView { img: Phaser.GameObjects.Image; shadow: Phaser.GameObjects.Image; dir: number; light?: Phaser.GameObjects.Light; bob: number }

const SHOT_COLOR: Record<string, number> = { rifle: 0x9ff3ff, pistol: 0xc8f6ff, harpoon: 0xffe08a, dart: 0x7dffc4, acid: 0xc6ff4d, psi: 0xc58bff };
const UNIT_LIFT: Record<string, number> = { spectre: 14 };

export class BattleScene extends Phaser.Scene {
  engine!: TacticalEngine;
  onTap: (p: Vec) => void = () => {};
  speed = 1;
  reduceFx = false;
  private floors: Phaser.GameObjects.Image[] = [];
  private objects = new Map<number, Phaser.GameObjects.Image>();
  private views = new Map<string, UnitView>();
  private overlay!: Phaser.GameObjects.Graphics; // zone atteignable, trajet
  private aim!: Phaser.GameObjects.Graphics; // trajectoire, rayon de grenade
  private marks!: Phaser.GameObjects.Graphics; // barres de PV, sélection
  private labels: Phaser.GameObjects.Text[] = [];
  private artifactImg!: Phaser.GameObjects.Image;
  private artifactLight!: Phaser.GameObjects.Light;
  private selected: string | null = null;
  private visible: Uint8Array = new Uint8Array(0);
  private pinch: { d: number; z: number } | null = null;
  private drag = { active: false, moved: false, x: 0, y: 0, sx: 0, sy: 0 };

  constructor() { super('battle'); }

  init(data: { engine: TacticalEngine }) { this.engine = data.engine; }

  create() {
    if (!this.textures.exists('floor0')) makeTextures(this);
    const s = this.engine.state;
    this.lights.enable().setAmbientColor(0x3a4c60);
    this.cameras.main.setBackgroundColor(0x03080d);

    for (let y = 0; y < s.height; y++)
      for (let x = 0; x < s.width; x++) {
        const t = s.tiles[idx(s, x, y)]!;
        const { sx, sy } = toScreen(x, y);
        const key = t === 'water' ? 'water' : inEvac(s, { x, y }) ? 'evac' : `floor${(x * 7 + y * 13) % 3}`;
        const f = this.add.image(sx, sy, key).setDepth(0).setLighting(true);
        this.floors[idx(s, x, y)] = f;
        if (t === 'wall' || t === 'low') {
          const term = s.objectives.terminal;
          const k = t === 'wall' ? 'wall' : x === term.x && y === term.y ? 'terminal' : (x + y) % 2 ? 'crate' : 'console';
          const tex = this.textures.get(k).getSourceImage() as HTMLCanvasElement;
          const img = this.add.image(sx, sy, k).setOrigin(0.5, (tex.height - TH / 2) / tex.height).setDepth(depthOf(x, y, 50)).setLighting(true);
          this.objects.set(idx(s, x, y), img);
        }
      }

    // Éclairage d'ambiance : sas ambré, alarmes rouges, terminal vert, artefact cyan
    const L = (x: number, y: number, r: number, c: number, i: number) => { const p = toScreen(x, y); return this.lights.addLight(p.sx, p.sy, r, c, i, 70); };
    L(2.5, 2, 230, 0xffa040, 1.3);
    L(19, 3, 200, 0xff3030, 0.9);
    L(3, 13, 200, 0xff3030, 0.9);
    L(s.objectives.terminal.x, s.objectives.terminal.y, 150, 0x60ff9a, 1.2);
    const art = s.objectives.artifact ?? { x: 12, y: 12 };
    this.artifactLight = L(art.x, art.y, 210, 0x40f0ff, 1.6);
    const ap = toScreen(art.x, art.y);
    this.artifactImg = this.add.image(ap.sx, ap.sy, 'artifact').setOrigin(0.5, 0.85).setDepth(depthOf(art.x, art.y, 60));
    this.tweens.add({ targets: this.artifactImg, y: ap.sy - 6, duration: 1400, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    this.tweens.add({ targets: this.artifactLight, intensity: 0.8, duration: 900, yoyo: true, repeat: -1 });

    for (const u of s.units) this.makeUnitView(u);

    this.overlay = this.add.graphics().setDepth(1);
    this.aim = this.add.graphics().setDepth(900000);
    this.marks = this.add.graphics().setDepth(900001);
    this.atmosphere();
    this.setupCamera();
    this.refresh();
  }

  private makeUnitView(u: Unit) {
    const { sx, sy } = toScreen(u.x, u.y);
    const shadow = this.add.image(sx, sy + 2, 'shadow').setDepth(2).setAlpha(0.8);
    const img = this.add.image(sx, sy - (UNIT_LIFT[u.kind] ?? 0), `${u.kind}_2`).setOrigin(0.5, 0.9).setLighting(true);
    const v: UnitView = { img, shadow, dir: u.faction === 'human' ? 1 : 5, bob: 0 };
    // Lampe frontale des plongeurs : la lumière suit l'unité.
    if (u.faction === 'human') v.light = this.lights.addLight(sx, sy, 170, 0xcfeeff, 1.1, 60);
    if (u.kind === 'spectre') this.tweens.add({ targets: v, bob: 5, duration: 1100, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
    this.views.set(u.id, v);
  }

  private atmosphere() {
    const s = this.engine.state;
    const a = toScreen(0, s.height), b = toScreen(s.width, 0), c = toScreen(s.width, s.height);
    const zone = new Phaser.Geom.Rectangle(a.sx, -40, b.sx - a.sx, c.sy + 40);
    // neige marine (particules en suspension) et bulles qui montent de quelques fuites
    this.add.particles(0, 0, 'mote', {
      emitZone: { type: 'random', source: zone } as never, lifespan: 9000, speedY: { min: 3, max: 10 }, speedX: { min: -4, max: 4 },
      alpha: { start: 0.5, end: 0 }, frequency: 120, quantity: 1,
    }).setDepth(800000);
    for (const [x, y] of [[13, 2], [7, 12], [21, 9]] as const) {
      const p = toScreen(x, y);
      this.add.particles(p.sx, p.sy, 'bubble', {
        lifespan: 2600, speedY: { min: -40, max: -25 }, speedX: { min: -6, max: 6 }, scale: { min: 0.5, max: 1.2 },
        alpha: { start: 0.8, end: 0 }, frequency: 380, x: { min: -8, max: 8 },
      }).setDepth(800000);
    }
    this.cameras.main.filters.external.addVignette(0.5, 0.5, 0.75, 0.55, 0x00060c);
  }

  private setupCamera() {
    const cam = this.cameras.main;
    const s = this.engine.state;
    cam.setZoom(Math.min(1.6, Math.max(0.6, this.scale.width / 900)));
    const start = this.engine.soldiers[0]!;
    this.centerOn(start, 0);
    this.input.addPointer(1);
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      Object.assign(this.drag, { active: true, moved: false, x: p.x, y: p.y, sx: cam.scrollX, sy: cam.scrollY });
    });
    this.input.on('pointermove', (p: Phaser.Input.Pointer) => {
      const p1 = this.input.pointer1, p2 = this.input.pointer2;
      if (p1.isDown && p2.isDown) {
        const d = Phaser.Math.Distance.Between(p1.x, p1.y, p2.x, p2.y);
        if (!this.pinch) this.pinch = { d, z: cam.zoom };
        cam.setZoom(Phaser.Math.Clamp((this.pinch.z * d) / this.pinch.d, 0.45, 2.6));
        this.drag.moved = true;
        return;
      }
      if (!this.drag.active || !p.isDown) return;
      const dx = p.x - this.drag.x, dy = p.y - this.drag.y;
      if (Math.hypot(dx, dy) > 10) this.drag.moved = true;
      if (this.drag.moved) cam.setScroll(this.drag.sx - dx / cam.zoom, this.drag.sy - dy / cam.zoom);
    });
    this.input.on('pointerup', (p: Phaser.Input.Pointer) => {
      if (!this.input.pointer1.isDown && !this.input.pointer2.isDown) this.pinch = null;
      if (this.drag.active && !this.drag.moved) {
        const w = cam.getWorldPoint(p.x, p.y);
        // on vise le sol : petit décalage pour les clics sur le haut des sprites
        const t = toTile(w.x, w.y + 6);
        if (t.x >= 0 && t.y >= 0 && t.x < s.width && t.y < s.height) this.onTap(t);
      }
      this.drag.active = false;
    });
    this.input.on('wheel', (_p: unknown, _o: unknown, _dx: number, dy: number) => {
      cam.setZoom(Phaser.Math.Clamp(cam.zoom * (dy > 0 ? 0.9 : 1.1), 0.45, 2.6));
    });
  }

  centerOn(p: Vec, ms = 350) {
    const { sx, sy } = toScreen(p.x, p.y);
    if (ms === 0) this.cameras.main.centerOn(sx, sy);
    else this.cameras.main.pan(sx, sy, ms, 'Sine.easeInOut');
  }

  select(id: string | null) { this.selected = id; this.drawMarks(); }

  /** Resynchronise tout l'affichage sur l'état de la simulation. */
  refresh() {
    const s = this.engine.state;
    this.visible = visibleTiles(s, 'human');
    s.tiles.forEach((t, i) => {
      const seen = this.visible[i], known = s.explored[i];
      const f = this.floors[i]!;
      f.setVisible(known || seen === 1).setTint(seen ? 0xffffff : 0x56606c);
      const o = this.objects.get(i);
      if (o) {
        if (t !== 'wall' && t !== 'low') { o.destroy(); this.objects.delete(i); return; }
        o.setVisible(known || seen === 1).setTint(seen ? 0xffffff : 0x56606c);
      }
    });
    for (const u of s.units) {
      const v = this.views.get(u.id)!;
      const shown = u.alive && !u.evacuated && (u.faction === 'human' || this.visible[idx(s, u.x, u.y)] === 1);
      this.placeUnit(u, v);
      v.img.setVisible(shown).setScale(1, u.kneeling ? 0.82 : 1).setAlpha(1);
      v.shadow.setVisible(shown);
      v.light?.setVisible(u.alive && !u.evacuated);
    }
    const art = s.objectives.artifact;
    this.artifactImg.setVisible(!!art && (s.explored[idx(s, art.x, art.y)] ?? false));
    this.artifactLight.setVisible(!!art);
    if (art) {
      const p = toScreen(art.x, art.y);
      this.artifactImg.setPosition(p.sx, p.sy).setDepth(depthOf(art.x, art.y, 60));
      this.artifactLight.setPosition(p.sx, p.sy);
    }
    this.drawMarks();
  }

  private placeUnit(u: Unit, v: UnitView) {
    const { sx, sy } = toScreen(u.x, u.y);
    v.img.setPosition(sx, sy - (UNIT_LIFT[u.kind] ?? 0)).setDepth(depthOf(u.x, u.y, 70)).setTexture(`${u.kind}_${v.dir}`);
    v.shadow.setPosition(sx, sy + 2);
    v.light?.setPosition(sx, sy);
  }

  /** PV au-dessus des unités visibles, anneau de sélection, icônes d'état. */
  private drawMarks() {
    const g = this.marks;
    g.clear();
    for (const l of this.labels) l.destroy();
    this.labels = [];
    const s = this.engine.state;
    for (const u of s.units) {
      const v = this.views.get(u.id)!;
      if (!v.img.visible) continue;
      const x = v.img.x, y = v.img.y - 64;
      g.fillStyle(0x000000, 0.6).fillRect(x - 16, y, 32, 4);
      g.fillStyle(u.faction === 'human' ? 0x5cf2ff : 0xff5a4a, 1).fillRect(x - 16, y, (32 * u.hp) / u.maxHp, 4);
      if (u.id === this.selected) {
        g.lineStyle(2, 0x7ff4ff, 1).strokeEllipse(v.shadow.x, v.shadow.y, 46, 22);
      }
      const icons = (u.watching ? '◉' : '') + (u.kneeling ? '▼' : '') + (u.carrying ? '◆' : '') + (u.wounds ? '✚' : '');
      if (icons) this.labels.push(this.add.text(x, y - 14, icons, { fontFamily: 'system-ui', fontSize: '13px', color: '#ffd27a', stroke: '#000', strokeThickness: 3 }).setOrigin(0.5).setDepth(900002));
    }
  }

  /** Zone atteignable : cyan si on garde de quoi tirer en réaction, ambre sinon. */
  showReach(u: Unit | null) {
    const g = this.overlay;
    g.clear();
    if (!u || !u.alive) return;
    const s = this.engine.state;
    const r = this.engine.reach(u);
    const keep = WEAPONS[u.weapon]!.snap.tu;
    for (const [i, c] of r.cost) {
      if (c === 0) continue;
      const x = i % s.width, y = Math.floor(i / s.width);
      const p = toScreen(x, y);
      g.fillStyle(u.tu - c >= keep ? 0x2fd6ff : 0xffa63d, 0.16);
      this.diamond(g, p.sx, p.sy, 0.86);
    }
  }

  showMovePreview(u: Unit, p: MovePreview | null) {
    this.showReach(u);
    this.aim.clear();
    if (!p) return;
    const g = this.overlay;
    let prev = toScreen(u.x, u.y);
    g.lineStyle(3, 0x9ff3ff, 0.9);
    for (const step of p.path) {
      const q = toScreen(step.x, step.y);
      g.lineBetween(prev.sx, prev.sy, q.sx, q.sy);
      prev = q;
    }
    const last = p.path[p.path.length - 1]!;
    const q = toScreen(last.x, last.y);
    g.lineStyle(2, p.reactors ? 0xffa63d : 0x9ff3ff, 1);
    this.diamond(g, q.sx, q.sy, 0.9, true);
    // boucliers de couverture autour de la destination
    const s = this.engine.state;
    const t = (x: number, y: number) => s.tiles[idx(s, x, y)];
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]] as const) {
      const k = t(last.x + dx, last.y + dy);
      if (k !== 'wall' && k !== 'low') continue;
      const m = toScreen(last.x + dx * 0.45, last.y + dy * 0.45);
      g.fillStyle(k === 'wall' ? 0x5cf2ff : 0xffd27a, 0.95).fillCircle(m.sx, m.sy - 10, k === 'wall' ? 6 : 4);
    }
  }

  showShot(from: Vec, to: Vec, chance: number) {
    const g = this.aim;
    g.clear();
    const a = toScreen(from.x, from.y, 30), b = toScreen(to.x, to.y, 30);
    g.lineStyle(2, chance >= 50 ? 0x7dffb0 : chance >= 25 ? 0xffd27a : 0xff6a5a, 0.95);
    const n = 14;
    for (let i = 0; i < n; i += 2) g.lineBetween(a.sx + ((b.sx - a.sx) * i) / n, a.sy + ((b.sy - a.sy) * i) / n, a.sx + ((b.sx - a.sx) * (i + 1)) / n, a.sy + ((b.sy - a.sy) * (i + 1)) / n);
    g.strokeCircle(b.sx, b.sy, 14);
  }

  showBlast(at: Vec | null, ok: boolean) {
    const g = this.aim;
    g.clear();
    if (!at) return;
    for (let y = at.y - RULES.grenadeRadius; y <= at.y + RULES.grenadeRadius; y++)
      for (let x = at.x - RULES.grenadeRadius; x <= at.x + RULES.grenadeRadius; x++) {
        const p = toScreen(x, y);
        g.fillStyle(ok ? 0xff7a3d : 0x888888, 0.22);
        this.diamond(g, p.sx, p.sy, 0.9);
      }
  }

  clearPreview() { this.overlay.clear(); this.aim.clear(); }

  private diamond(g: Phaser.GameObjects.Graphics, x: number, y: number, k: number, stroke = false) {
    const w = 32 * k, h = 16 * k;
    const pts = [new Phaser.Math.Vector2(x, y - h), new Phaser.Math.Vector2(x + w, y), new Phaser.Math.Vector2(x, y + h), new Phaser.Math.Vector2(x - w, y)];
    if (stroke) g.strokePoints(pts, true); else g.fillPoints(pts, true);
  }

  override update() {
    for (const [id, v] of this.views) {
      const u = this.engine.unit(id)!;
      if (u.kind === 'spectre' && v.img.visible) v.img.y = toScreen(u.x, u.y).sy - UNIT_LIFT.spectre! - v.bob;
    }
  }

  // ---------- rejeu des événements de la simulation ----------

  private wait(ms: number) {
    if (this.speed >= 99) return Promise.resolve();
    return new Promise<void>(r => this.time.delayedCall(ms / this.speed, () => r()));
  }

  private floatText(p: Vec, text: string, color: string) {
    if (this.speed >= 99) return;
    const { sx, sy } = toScreen(p.x, p.y, 70);
    const t = this.add.text(sx, sy, text, { fontFamily: 'system-ui', fontStyle: 'bold', fontSize: '18px', color, stroke: '#000', strokeThickness: 4 }).setOrigin(0.5).setDepth(900003);
    this.tweens.add({ targets: t, y: sy - 34, alpha: 0, duration: 1100 / Math.min(this.speed, 2), onComplete: () => t.destroy() });
  }

  private flashLight(p: Vec, color: number, radius: number, intensity: number, ms: number) {
    if (this.reduceFx || this.speed >= 99) return;
    const { sx, sy } = toScreen(p.x, p.y);
    const l = this.lights.addLight(sx, sy, radius, color, intensity, 50);
    this.tweens.add({ targets: l, intensity: 0, duration: ms, onComplete: () => this.lights.removeLight(l) });
  }

  /** Rejoue les événements dans l'ordre ; `banner` affiche les messages non bloquants dans le HUD. */
  async play(events: GameEvent[], banner: (text: string, tone?: 'info' | 'warn' | 'good') => void): Promise<void> {
    const s = this.engine.state;
    const name = (id: string) => this.engine.unit(id)?.name ?? id;
    for (const e of events) {
      switch (e.t) {
        case 'move': {
          const v = this.views.get(e.unit)!;
          v.dir = dir8(e.to.x - e.from.x, e.to.y - e.from.y);
          const u = this.engine.unit(e.unit)!;
          v.img.setTexture(`${u.kind}_${v.dir}`).setScale(1, 1);
          const { sx, sy } = toScreen(e.to.x, e.to.y);
          const lift = UNIT_LIFT[u.kind] ?? 0;
          if (!e.seen || this.speed >= 99) {
            v.img.setPosition(sx, sy - lift).setDepth(depthOf(e.to.x, e.to.y, 70)).setVisible(e.seen);
            v.shadow.setPosition(sx, sy + 2).setVisible(e.seen);
            v.light?.setPosition(sx, sy);
            break;
          }
          v.img.setVisible(true); v.shadow.setVisible(true);
          v.img.setDepth(Math.max(v.img.depth, depthOf(e.to.x, e.to.y, 70)));
          if (u.faction === 'human') audio.play('step');
          const ms = 150 / this.speed;
          this.tweens.add({ targets: v.img, x: sx, y: sy - lift, duration: ms });
          this.tweens.add({ targets: [v.shadow], x: sx, y: sy + 2, duration: ms });
          if (v.light) this.tweens.add({ targets: v.light, x: sx, y: sy, duration: ms });
          await this.wait(150);
          v.img.setDepth(depthOf(e.to.x, e.to.y, 70));
          if (u.faction === 'human') this.refreshFog();
          break;
        }
        case 'spotted': {
          const u = this.engine.unit(e.unit)!;
          audio.play('sonar');
          banner(`Contact sonar : ${u.name}`, 'warn');
          const v = this.views.get(e.unit)!;
          v.img.setVisible(true); v.shadow.setVisible(true);
          if (s.side === 'alien') this.centerOn(u, 250 / Math.min(this.speed, 4));
          await this.wait(350);
          break;
        }
        case 'interrupt':
          if (this.engine.unit(e.unit)?.faction === 'human') banner(`${name(e.unit)} s'arrête : contact`, 'warn');
          break;
        case 'shot': {
          const w = WEAPONS[e.weapon]!;
          const shooter = this.views.get(e.unit)!;
          shooter.dir = dir8(e.to.x - e.from.x, e.to.y - e.from.y);
          shooter.img.setTexture(`${this.engine.unit(e.unit)!.kind}_${shooter.dir}`);
          if (e.reaction) banner(`Tir de réaction : ${name(e.unit)}`, 'warn');
          audio.play(w.sound as Sfx);
          if (this.speed < 99) {
            const a = toScreen(e.from.x, e.from.y, 30), b = toScreen(e.to.x, e.to.y, 30);
            const miss = e.hit ? 0 : 18;
            const tr = this.add.graphics().setDepth(900000);
            tr.lineStyle(w.sound === 'psi' ? 5 : 2, SHOT_COLOR[e.weapon] ?? 0xffffff, 1);
            if (e.seen) tr.lineBetween(a.sx, a.sy, b.sx + miss, b.sy - miss / 2);
            else tr.lineBetween(b.sx - 60, b.sy - 30, b.sx + miss, b.sy - miss / 2); // tir venu du noir
            this.tweens.add({ targets: tr, alpha: 0, duration: 260 / this.speed, onComplete: () => tr.destroy() });
            if (e.seen) this.flashLight(e.from, SHOT_COLOR[e.weapon] ?? 0xffffff, 120, 2.2, 160);
          }
          if (!e.hit) { audio.play('miss'); this.floatText(e.to, `Raté (${e.chance} %)`, '#c9d6e0'); }
          await this.wait(260);
          break;
        }
        case 'damage': {
          const v = this.views.get(e.unit)!;
          audio.play('hit');
          this.floatText(this.engine.unit(e.unit)!, e.amount ? `-${e.amount}${e.wounded ? ' ✚' : ''}` : 'Ricochet', '#ff7b6b');
          if (e.drained) this.floatText({ x: this.engine.unit(e.unit)!.x, y: this.engine.unit(e.unit)!.y - 0.6 }, `-${e.drained} UT`, '#c58bff');
          v.img.setTint(0xff6060);
          this.time.delayedCall(140, () => v.img.clearTint());
          if (this.engine.unit(e.unit)!.faction === 'human' && !this.reduceFx) this.cameras.main.shake(120, 0.004);
          await this.wait(200);
          break;
        }
        case 'death': {
          const v = this.views.get(e.unit)!;
          audio.play('death');
          banner(`${name(e.unit)} neutralisé${this.engine.unit(e.unit)!.faction === 'human' ? ' — perte' : ''}`, this.engine.unit(e.unit)!.faction === 'human' ? 'warn' : 'good');
          this.tweens.add({ targets: v.img, alpha: 0, angle: 70, duration: 500 / Math.min(this.speed, 4) });
          v.light?.setVisible(false);
          await this.wait(400);
          v.shadow.setVisible(false);
          break;
        }
        case 'explosion': {
          audio.play('explosion');
          this.flashLight(e.at, 0xff8a3d, 300, 4, 600);
          if (!this.reduceFx) this.cameras.main.shake(260, 0.012);
          const { sx, sy } = toScreen(e.at.x, e.at.y);
          const burst = this.add.particles(sx, sy, 'spark', { speed: { min: 60, max: 220 }, lifespan: 600, quantity: 40, emitting: false, scale: { start: 2, end: 0 } }).setDepth(900000);
          burst.explode(40);
          this.time.delayedCall(900, () => burst.destroy());
          await this.wait(450);
          break;
        }
        case 'destroy': {
          const o = this.objects.get(idx(s, e.at.x, e.at.y));
          o?.destroy();
          this.objects.delete(idx(s, e.at.x, e.at.y));
          const { sx, sy } = toScreen(e.at.x, e.at.y);
          this.add.image(sx, sy, 'debris').setDepth(1).setLighting(true);
          break;
        }
        case 'heal':
          audio.play('heal');
          this.floatText(this.engine.unit(e.target)!, `+${e.amount}`, '#7dffb0');
          await this.wait(300);
          break;
        case 'reload': audio.play('reload'); this.floatText(this.engine.unit(e.unit)!, 'Rechargé', '#c9e6ff'); break;
        case 'kneel': audio.play('click'); break;
        case 'watch': audio.play('confirm'); this.floatText(this.engine.unit(e.unit)!, 'Surveillance', '#ffd27a'); break;
        case 'pickup': banner(`${name(e.unit)} récupère l'artefact`, 'good'); this.artifactImg.setVisible(false); this.artifactLight.setVisible(false); break;
        case 'alarm':
          audio.play('alarm');
          banner("L'artefact pulse : tous les hostiles convergent !", 'warn');
          this.flashLight(s.objectives.artifact ?? this.engine.soldiers.find(u => u.carrying) ?? { x: 12, y: 12 }, 0x40f0ff, 420, 3, 1200);
          await this.wait(500);
          break;
        case 'logs': audio.play('confirm'); banner('Journal du terminal téléchargé', 'good'); break;
        case 'drop': banner("L'artefact est tombé au sol", 'warn'); break;
        case 'bleed': this.floatText(this.engine.unit(e.unit)!, `-${e.amount} saignement`, '#ff9a8a'); break;
        case 'turn': audio.play('turn'); banner(e.side === 'alien' ? 'Activité hostile…' : `Tour ${e.turn}`, 'info'); break;
        case 'evacuate': case 'outcome': break;
      }
    }
    this.refresh();
  }

  private refreshFog() {
    const s = this.engine.state;
    this.visible = visibleTiles(s, 'human');
    this.visible.forEach((v, i) => {
      if (!v) return;
      this.floors[i]!.setVisible(true).setTint(0xffffff);
      this.objects.get(i)?.setVisible(true).setTint(0xffffff);
    });
  }

  /** Mesure simple de performance pour les tests sur appareils. */
  get fps() { return Math.round(this.game.loop.actualFps); }
  get lightCount() { return this.lights.getLightCount(); }
  get lowHeight() { return LOW_H; }
}
