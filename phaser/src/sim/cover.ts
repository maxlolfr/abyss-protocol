// CoverSystem : la couverture d'une case dépend de la direction du tireur.
import type { BattleState, CoverLevel, Vec } from './types';
import { tileAt } from './map';

const level = (s: BattleState, x: number, y: number): CoverLevel => {
  const t = tileAt(s, x, y);
  return t === 'wall' ? 2 : t === 'low' ? 1 : 0;
};

/**
 * Couverture d'une cible en `target` face à un tireur en `from`.
 * On regarde la case voisine de la cible côté tireur sur chaque axe dominant.
 * À genoux, un obstacle bas devient une couverture totale.
 */
export function coverAgainst(s: BattleState, target: Vec, from: Vec, kneeling = false): CoverLevel {
  const dx = from.x - target.x, dy = from.y - target.y;
  if (Math.max(Math.abs(dx), Math.abs(dy)) <= 1) return 0; // au contact, pas de couverture
  let best: CoverLevel = 0;
  if (dx !== 0 && Math.abs(dx) * 2 >= Math.abs(dy)) best = Math.max(best, level(s, target.x + Math.sign(dx), target.y)) as CoverLevel;
  if (dy !== 0 && Math.abs(dy) * 2 >= Math.abs(dx)) best = Math.max(best, level(s, target.x, target.y + Math.sign(dy))) as CoverLevel;
  if (kneeling && best === 1) best = 2;
  return best;
}

/** Couverture offerte par une case dans les 4 directions (affichage des boucliers). */
export function coverAround(s: BattleState, p: Vec): { n: CoverLevel; s: CoverLevel; e: CoverLevel; w: CoverLevel } {
  return { n: level(s, p.x, p.y - 1), s: level(s, p.x, p.y + 1), e: level(s, p.x + 1, p.y), w: level(s, p.x - 1, p.y) };
}
