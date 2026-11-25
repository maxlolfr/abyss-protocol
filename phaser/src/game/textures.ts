// Assets provisoires générés au démarrage (aucun fichier image) : blocs isométriques avec normal maps
// pour que l'éclairage dynamique de Phaser 4 sculpte les volumes, et unités sur 8 orientations.
// Ils seront remplacés par des atlas pré-rendus (voir docs/ARCHITECTURE.md, convention de noms).
import type Phaser from 'phaser';
import { LOW_H, TH, TW, WALL_H } from './iso';

type Ctx = CanvasRenderingContext2D;
const N_TOP = 'rgb(128,128,255)', N_LEFT = 'rgb(48,150,210)', N_RIGHT = 'rgb(208,150,210)';

function canvas(w: number, h: number): [HTMLCanvasElement, Ctx] {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return [c, c.getContext('2d')!];
}

function diamond(g: Ctx, cx: number, cy: number, w: number, h: number) {
  g.beginPath();
  g.moveTo(cx, cy - h / 2); g.lineTo(cx + w / 2, cy); g.lineTo(cx, cy + h / 2); g.lineTo(cx - w / 2, cy);
  g.closePath();
}

function add(scene: Phaser.Scene, key: string, color: HTMLCanvasElement, normal?: HTMLCanvasElement) {
  const t = scene.textures.addCanvas(key, color);
  if (t && normal) t.setDataSource(normal);
}

/** Bloc isométrique de hauteur h : faces haut / gauche / droite. */
function block(scene: Phaser.Scene, key: string, h: number, top: string, left: string, right: string, detail?: (g: Ctx) => void) {
  const W = TW, H = TH + h;
  const paint = (g: Ctx, t: string, l: string, r: string) => {
    g.fillStyle = l;
    g.beginPath(); g.moveTo(0, TH / 2); g.lineTo(W / 2, TH); g.lineTo(W / 2, TH + h); g.lineTo(0, TH / 2 + h); g.closePath(); g.fill();
    g.fillStyle = r;
    g.beginPath(); g.moveTo(W, TH / 2); g.lineTo(W / 2, TH); g.lineTo(W / 2, TH + h); g.lineTo(W, TH / 2 + h); g.closePath(); g.fill();
    g.fillStyle = t; diamond(g, W / 2, TH / 2, W, TH); g.fill();
  };
  const [c, g] = canvas(W, H);
  paint(g, top, left, right);
  g.strokeStyle = 'rgba(140,220,255,0.18)'; g.lineWidth = 1; diamond(g, W / 2, TH / 2, W - 2, TH - 1); g.stroke();
  detail?.(g);
  const [n, gn] = canvas(W, H);
  paint(gn, N_TOP, N_LEFT, N_RIGHT);
  add(scene, key, c, n);
}

function floor(scene: Phaser.Scene, key: string, base: string, seed: number) {
  const [c, g] = canvas(TW, TH);
  g.fillStyle = base; diamond(g, TW / 2, TH / 2, TW, TH); g.fill();
  g.save(); diamond(g, TW / 2, TH / 2, TW, TH); g.clip();
  g.strokeStyle = 'rgba(0,0,0,0.25)';
  for (let i = -TW; i < TW; i += 8) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i + TH * 2, TH); g.stroke(); }
  // salissures et rivets pseudo-aléatoires
  for (let i = 0; i < 6; i++) {
    const x = (seed * 37 + i * 23) % TW, y = (seed * 11 + i * 7) % TH;
    g.fillStyle = i % 2 ? 'rgba(120,200,220,0.10)' : 'rgba(0,0,0,0.22)';
    g.fillRect(x, y, 2 + (i % 3), 1 + (i % 2));
  }
  g.restore();
  g.strokeStyle = 'rgba(160,230,255,0.22)'; diamond(g, TW / 2, TH / 2, TW - 2, TH - 2); g.stroke();
  const [n, gn] = canvas(TW, TH);
  gn.fillStyle = N_TOP; diamond(gn, TW / 2, TH / 2, TW, TH); gn.fill();
  gn.strokeStyle = 'rgb(128,190,240)'; gn.lineWidth = 2; diamond(gn, TW / 2, TH / 2, TW - 3, TH - 3); gn.stroke();
  add(scene, key, c, n);
}

function sprite(scene: Phaser.Scene, key: string, w: number, h: number, draw: (g: Ctx) => void) {
  const [c, g] = canvas(w, h);
  draw(g);
  add(scene, key, c);
}

/** Unités : un dessin par orientation (0..7). `look` = vecteur écran de la direction. */
function unitFrames(scene: Phaser.Scene, kind: string, draw: (g: Ctx, lx: number, ly: number) => void) {
  for (let d = 0; d < 8; d++) {
    const a = (d * Math.PI) / 4;
    sprite(scene, `${kind}_${d}`, 56, 72, g => draw(g, Math.cos(a), Math.sin(a)));
  }
}

function soldier(g: Ctx, lx: number, ly: number) {
  const cx = 28, base = 64;
  const back = ly < -0.3;
  // arme (derrière le corps si l'unité regarde vers le haut)
  const gun = () => { g.strokeStyle = '#9fb3c4'; g.lineWidth = 4; g.beginPath(); g.moveTo(cx + lx * 4, base - 26); g.lineTo(cx + lx * 20, base - 26 + ly * 10); g.stroke(); };
  if (back) gun();
  g.fillStyle = '#1b2c3d'; g.fillRect(cx - 9, base - 18, 7, 18); g.fillRect(cx + 2, base - 18, 7, 18); // jambes
  const grd = g.createLinearGradient(cx - 13, 0, cx + 13, 0);
  grd.addColorStop(0, '#2b4b66'); grd.addColorStop(1, '#3e6f93');
  g.fillStyle = grd; g.beginPath(); g.roundRect(cx - 13, base - 42, 26, 26, 6); g.fill(); // buste
  g.fillStyle = '#d18b2c'; g.fillRect(cx - 13, base - 30, 26, 3); // bande ambre
  g.fillStyle = '#4c84ad'; g.beginPath(); g.arc(cx, base - 50, 11, 0, Math.PI * 2); g.fill(); // casque
  if (!back) { g.fillStyle = '#7ff4ff'; g.beginPath(); g.ellipse(cx + lx * 6, base - 50 + ly * 2, 7, 4, 0, 0, Math.PI * 2); g.fill(); }
  g.fillStyle = '#8ec9e8'; g.fillRect(cx - 2 - lx * 9, base - 40, 4, 6); // bouteille
  if (!back) gun();
}

function nereide(g: Ctx, lx: number, ly: number) {
  const cx = 28, base = 64;
  g.fillStyle = '#0f4a45'; g.fillRect(cx - 8, base - 18, 6, 18); g.fillRect(cx + 2, base - 18, 6, 18);
  g.fillStyle = '#167a6c'; g.beginPath(); g.ellipse(cx, base - 32, 11, 16, 0, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#2bc4a0'; // nageoires dorsales
  g.beginPath(); g.moveTo(cx - 4, base - 50); g.lineTo(cx - 14 - lx * 4, base - 62); g.lineTo(cx + 2, base - 44); g.fill();
  g.fillStyle = '#1d9a86'; g.beginPath(); g.ellipse(cx + lx * 3, base - 52, 9, 10, 0, 0, Math.PI * 2); g.fill();
  if (ly > -0.3) {
    g.fillStyle = '#d8ffef';
    for (const o of [-3, 3]) { g.beginPath(); g.arc(cx + lx * 6 + o, base - 54, 2.2, 0, Math.PI * 2); g.fill(); }
  }
  g.strokeStyle = '#9ff7d6'; g.lineWidth = 3; g.beginPath(); g.moveTo(cx + lx * 6, base - 34); g.lineTo(cx + lx * 22, base - 34 + ly * 10); g.stroke();
}

function carapace(g: Ctx, lx: number, ly: number) {
  const cx = 28, base = 66;
  g.strokeStyle = '#4b2f1c'; g.lineWidth = 4;
  for (const s of [-1, 1]) for (const k of [0, 8]) { g.beginPath(); g.moveTo(cx + s * 10, base - 14 - k / 2); g.lineTo(cx + s * 24, base - 2 - k / 3); g.stroke(); }
  const grd = g.createRadialGradient(cx - 6, base - 34, 4, cx, base - 26, 26);
  grd.addColorStop(0, '#a5683a'); grd.addColorStop(1, '#3d2414');
  g.fillStyle = grd; g.beginPath(); g.ellipse(cx, base - 26, 24, 18, 0, 0, Math.PI * 2); g.fill();
  g.strokeStyle = 'rgba(255,210,150,0.35)'; g.lineWidth = 2;
  for (let i = -1; i <= 1; i++) { g.beginPath(); g.arc(cx, base - 26 + i * 6, 18 - Math.abs(i) * 4, Math.PI * 1.1, Math.PI * 1.9); g.stroke(); }
  g.fillStyle = '#ffb347'; // yeux
  if (ly > -0.4) for (const o of [-5, 5]) { g.beginPath(); g.arc(cx + lx * 14 + o, base - 30 + ly * 4, 2.6, 0, Math.PI * 2); g.fill(); }
  g.fillStyle = '#c0803f'; g.beginPath(); g.arc(cx + lx * 22, base - 20 + ly * 8, 6, 0, Math.PI * 2); g.fill(); // pince
}

function spectre(g: Ctx, lx: number, ly: number) {
  const cx = 28, top = 14;
  g.strokeStyle = 'rgba(190,130,255,0.75)'; g.lineWidth = 2;
  for (let i = -3; i <= 3; i++) {
    g.beginPath(); g.moveTo(cx + i * 4, top + 20);
    g.bezierCurveTo(cx + i * 6 - lx * 6, top + 34, cx + i * 3 + lx * 4, top + 42, cx + i * 5 - lx * 8, top + 52); g.stroke();
  }
  const grd = g.createRadialGradient(cx, top + 10, 2, cx, top + 14, 20);
  grd.addColorStop(0, '#f3e4ff'); grd.addColorStop(0.4, '#a46bff'); grd.addColorStop(1, 'rgba(70,20,140,0.85)');
  g.fillStyle = grd; g.beginPath(); g.ellipse(cx, top + 14, 18, 13, 0, Math.PI, 0); g.lineTo(cx + 18, top + 20); g.lineTo(cx - 18, top + 20); g.fill();
  g.fillStyle = '#ffd36b';
  for (const o of [-5, 5]) { g.beginPath(); g.arc(cx + lx * 6 + o, top + 14, 1.8, 0, Math.PI * 2); g.fill(); }
}

export function makeTextures(scene: Phaser.Scene): void {
  floor(scene, 'floor0', '#26394a', 1);
  floor(scene, 'floor1', '#223446', 2);
  floor(scene, 'floor2', '#2a3d4c', 3);
  floor(scene, 'water', '#12485a', 4);
  floor(scene, 'evac', '#3b3a2a', 5);
  block(scene, 'wall', WALL_H, '#3a5266', '#1b2a37', '#26394a', g => {
    g.fillStyle = 'rgba(255,170,60,0.55)'; g.fillRect(TW / 2 + 8, TH + 8, 10, 2); // témoin lumineux
  });
  block(scene, 'crate', LOW_H, '#5c4a2c', '#2f2617', '#45371f', g => {
    g.strokeStyle = 'rgba(0,0,0,0.4)'; g.beginPath(); g.moveTo(16, 8); g.lineTo(48, 24); g.stroke();
  });
  block(scene, 'console', LOW_H, '#2e4656', '#17242f', '#203340', g => {
    g.fillStyle = 'rgba(90,230,255,0.7)'; g.fillRect(24, 10, 16, 4);
  });
  block(scene, 'terminal', LOW_H + 6, '#284a3e', '#13261f', '#1c362c', g => {
    g.fillStyle = 'rgba(120,255,170,0.9)'; g.fillRect(22, 8, 20, 6);
  });
  sprite(scene, 'artifact', 40, 56, g => {
    const grd = g.createRadialGradient(20, 26, 2, 20, 26, 18);
    grd.addColorStop(0, '#ffffff'); grd.addColorStop(0.3, '#6ff8ff'); grd.addColorStop(1, 'rgba(0,120,160,0)');
    g.fillStyle = grd; g.fillRect(0, 6, 40, 40);
    g.fillStyle = '#0d2d3a'; g.beginPath(); g.moveTo(20, 8); g.lineTo(30, 28); g.lineTo(20, 48); g.lineTo(10, 28); g.closePath(); g.fill();
    g.strokeStyle = '#8ff7ff'; g.lineWidth = 2; g.stroke();
  });
  sprite(scene, 'shadow', 44, 18, g => {
    const grd = g.createRadialGradient(22, 9, 2, 22, 9, 22);
    grd.addColorStop(0, 'rgba(0,0,0,0.6)'); grd.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = grd; g.beginPath(); g.ellipse(22, 9, 22, 9, 0, 0, Math.PI * 2); g.fill();
  });
  sprite(scene, 'debris', TW, TH, g => {
    g.fillStyle = 'rgba(20,14,8,0.8)';
    for (let i = 0; i < 9; i++) g.fillRect(14 + ((i * 17) % 34), 8 + ((i * 7) % 16), 4 + (i % 3), 3);
  });
  sprite(scene, 'bubble', 8, 8, g => { g.strokeStyle = 'rgba(200,245,255,0.8)'; g.beginPath(); g.arc(4, 4, 3, 0, Math.PI * 2); g.stroke(); });
  sprite(scene, 'mote', 4, 4, g => { g.fillStyle = 'rgba(200,230,240,0.7)'; g.fillRect(1, 1, 2, 2); });
  sprite(scene, 'spark', 8, 8, g => {
    const grd = g.createRadialGradient(4, 4, 0, 4, 4, 4);
    grd.addColorStop(0, '#fff'); grd.addColorStop(1, 'rgba(255,180,80,0)');
    g.fillStyle = grd; g.fillRect(0, 0, 8, 8);
  });
  unitFrames(scene, 'soldier', soldier);
  unitFrames(scene, 'nereide', nereide);
  unitFrames(scene, 'carapace', carapace);
  unitFrames(scene, 'spectre', spectre);
}
