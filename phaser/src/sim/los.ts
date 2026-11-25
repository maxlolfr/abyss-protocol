// LineOfSight + FogOfWar. Les cloisons bloquent la vue ; les obstacles bas et les unités ne la bloquent pas.
import type { BattleState, Faction, Unit, Vec } from './types';
import { dist, idx, living, tileAt } from './map';
import { UNIT_TEMPLATES } from './data';

/** Ligne de Bresenham entre deux centres de cases ; vrai si aucune cloison ne s'interpose. */
export function hasLine(s: BattleState, a: Vec, b: Vec): boolean {
  let x = a.x, y = a.y;
  const dx = Math.abs(b.x - a.x), dy = -Math.abs(b.y - a.y);
  const sx = a.x < b.x ? 1 : -1, sy = a.y < b.y ? 1 : -1;
  let err = dx + dy;
  while (x !== b.x || y !== b.y) {
    const e2 = 2 * err;
    const mx = e2 >= dy, my = e2 <= dx;
    // un pas diagonal entre deux cloisons ne laisse pas passer la vue
    if (mx && my && tileAt(s, x + sx, y) === 'wall' && tileAt(s, x, y + sy) === 'wall') return false;
    if (mx) { err += dy; x += sx; }
    if (my) { err += dx; y += sy; }
    if ((x !== b.x || y !== b.y) && tileAt(s, x, y) === 'wall') return false;
  }
  return true;
}

export const visionOf = (u: Unit) => UNIT_TEMPLATES[u.kind]?.vision ?? 10;

export function canSee(s: BattleState, viewer: Unit, p: Vec, from: Vec = viewer): boolean {
  return dist(from, p) <= visionOf(viewer) && hasLine(s, from, p);
}

/** Cases vues par au moins une unité du camp (1 = visible). */
export function visibleTiles(s: BattleState, faction: Faction): Uint8Array {
  const vis = new Uint8Array(s.width * s.height);
  for (const u of living(s)) {
    if (u.faction !== faction) continue;
    const r = visionOf(u);
    for (let y = Math.max(0, u.y - r); y <= Math.min(s.height - 1, u.y + r); y++)
      for (let x = Math.max(0, u.x - r); x <= Math.min(s.width - 1, u.x + r); x++) {
        const i = idx(s, x, y);
        if (!vis[i] && canSee(s, u, { x, y })) vis[i] = 1;
      }
  }
  return vis;
}

/** Ennemis visibles par un camp. */
export function spottedBy(s: BattleState, faction: Faction): Unit[] {
  const mine = living(s).filter(u => u.faction === faction);
  return living(s).filter(e => e.faction !== faction && mine.some(m => canSee(s, m, e)));
}

/** Met à jour la mémoire du brouillard côté joueur. */
export function updateExplored(s: BattleState): void {
  const vis = visibleTiles(s, 'human');
  vis.forEach((v, i) => { if (v) s.explored[i] = true; });
}
