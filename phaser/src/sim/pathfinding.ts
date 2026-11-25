// Pathfinding : A* pour un trajet, Dijkstra borné pour la zone atteignable. Coûts en UT (ActionPointSystem).
import type { BattleState, Unit, Vec } from './types';
import { idx, standable, tileAt, unitAt } from './map';
import { RULES, UNIT_TEMPLATES } from './data';

const DIRS: ReadonlyArray<readonly [number, number]> = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];

/** Coût en UT d'un pas vers (x, y), ou Infinity si interdit. */
export function stepCost(s: BattleState, u: Unit, fx: number, fy: number, x: number, y: number): number {
  if (!standable(s, u, x, y)) return Infinity;
  const occ = unitAt(s, x, y);
  if (occ && occ !== u) return Infinity;
  const diag = fx !== x && fy !== y;
  // Pas de coupe en diagonale contre un angle de mur ou d'obstacle.
  if (diag && (!standable(s, u, x, fy) || !standable(s, u, fx, y))) return Infinity;
  const tpl = UNIT_TEMPLATES[u.kind];
  let c = diag ? RULES.moveDiag : RULES.moveOrtho;
  if (tileAt(s, x, y) === 'water' && !tpl?.amphibious && !tpl?.hover) c += RULES.waterExtra;
  return c;
}

export interface Reach { cost: Map<number, number>; prev: Map<number, number> }

/** Toutes les cases atteignables avec `budget` UT. */
export function reachable(s: BattleState, u: Unit, budget = u.tu): Reach {
  const start = idx(s, u.x, u.y);
  const cost = new Map([[start, 0]]);
  const prev = new Map<number, number>();
  const open: number[] = [start];
  while (open.length) {
    // file à priorité simple : la carte est petite (≈ 400 cases)
    let bi = 0;
    for (let i = 1; i < open.length; i++) if (cost.get(open[i]!)! < cost.get(open[bi]!)!) bi = i;
    const cur = open.splice(bi, 1)[0]!;
    const cx = cur % s.width, cy = Math.floor(cur / s.width), cc = cost.get(cur)!;
    for (const [dx, dy] of DIRS) {
      const nx = cx + dx, ny = cy + dy;
      const sc = stepCost(s, u, cx, cy, nx, ny);
      if (!isFinite(sc)) continue;
      const nc = cc + sc, ni = idx(s, nx, ny);
      if (nc > budget || nc >= (cost.get(ni) ?? Infinity)) continue;
      cost.set(ni, nc);
      prev.set(ni, cur);
      open.push(ni);
    }
  }
  return { cost, prev };
}

/** Reconstitue le trajet (sans la case de départ) vers `to` à partir d'un Reach. */
export function pathFrom(s: BattleState, r: Reach, to: Vec): Vec[] | null {
  let k: number | undefined = idx(s, to.x, to.y);
  if (!r.cost.has(k)) return null;
  const path: Vec[] = [];
  while (k !== undefined && r.prev.has(k)) {
    path.unshift({ x: k % s.width, y: Math.floor(k / s.width) });
    k = r.prev.get(k);
  }
  return path;
}

/** A* sans limite d'UT (utile à l'IA pour se diriger vers un point lointain). */
export function findPath(s: BattleState, u: Unit, to: Vec): { path: Vec[]; cost: number } | null {
  const h = (x: number, y: number) => {
    const dx = Math.abs(x - to.x), dy = Math.abs(y - to.y);
    return RULES.moveOrtho * Math.abs(dx - dy) + RULES.moveDiag * Math.min(dx, dy);
  };
  const start = idx(s, u.x, u.y), goal = idx(s, to.x, to.y);
  const g = new Map([[start, 0]]);
  const prev = new Map<number, number>();
  const open = new Map([[start, h(u.x, u.y)]]);
  while (open.size) {
    let cur = -1, best = Infinity;
    for (const [k, f] of open) if (f < best || (f === best && k < cur)) { best = f; cur = k; }
    if (cur === goal) break;
    open.delete(cur);
    const cx = cur % s.width, cy = Math.floor(cur / s.width);
    for (const [dx, dy] of DIRS) {
      const nx = cx + dx, ny = cy + dy;
      const ni = idx(s, nx, ny);
      // la case d'arrivée peut être occupée (on s'arrête à côté) : l'appelant tronque le trajet
      const sc = ni === goal && standable(s, u, nx, ny) ? (dx && dy ? RULES.moveDiag : RULES.moveOrtho) : stepCost(s, u, cx, cy, nx, ny);
      if (!isFinite(sc)) continue;
      const ng = g.get(cur)! + sc;
      if (ng >= (g.get(ni) ?? Infinity)) continue;
      g.set(ni, ng);
      prev.set(ni, cur);
      open.set(ni, ng + h(nx, ny));
    }
  }
  if (!g.has(goal)) return null;
  const path: Vec[] = [];
  let k: number | undefined = goal;
  while (k !== undefined && k !== start) {
    path.unshift({ x: k % s.width, y: Math.floor(k / s.width) });
    k = prev.get(k);
  }
  return { path, cost: g.get(goal)! };
}

/** Coût total d'un trajet déjà calculé. */
export function pathCost(s: BattleState, u: Unit, path: Vec[]): number {
  let x = u.x, y = u.y, c = 0;
  for (const p of path) { c += stepCost(s, u, x, y, p.x, p.y); x = p.x; y = p.y; }
  return c;
}
