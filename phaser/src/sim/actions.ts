// ActionPointSystem : coût en UT de chaque action et exécution des actions (joueur comme IA).
// Chaque fonction modifie l'état et ajoute des événements que le rendu rejoue.
import type { BattleState, FireMode, GameEvent, Unit, Vec } from './types';
import { RULES, WEAPONS } from './data';
import { cheb, inEvac, living } from './map';
import { stepCost } from './pathfinding';
import { canSee, spottedBy, updateExplored } from './los';
import { explode, hitChance, modeDef, reactionFire, resolveShot, seenByHumans } from './combat';

export const shotCost = (u: Unit, mode: FireMode) => modeDef(u, mode)?.tu ?? Infinity;

/** Les aliens partagent ce qu'ils voient : alerte + dernières positions connues. */
export function alienAwareness(s: BattleState): void {
  for (const h of spottedBy(s, 'alien')) {
    s.alienAlert = true;
    s.lastKnown[h.id] = { x: h.x, y: h.y };
  }
}

export interface MoveResult { steps: number; interrupted: boolean }

/**
 * Déplacement pas à pas. S'arrête si les UT manquent, si un nouvel ennemi apparaît
 * (le joueur garde ses UT pour réagir) ou si l'unité tombe sous un tir de réaction.
 */
export function doMove(s: BattleState, u: Unit, path: Vec[], ev: GameEvent[]): MoveResult {
  let steps = 0;
  const known = new Set(spottedBy(s, u.faction).map(e => e.id));
  for (const p of path) {
    const c = stepCost(s, u, u.x, u.y, p.x, p.y);
    if (!isFinite(c) || c > u.tu) break;
    const from = { x: u.x, y: u.y };
    const wasSeen = u.faction === 'human' || seenByHumans(s, from);
    u.tu -= c;
    u.x = p.x; u.y = p.y;
    u.kneeling = false;
    steps++;
    const nowSeen = u.faction === 'human' || seenByHumans(s, u);
    ev.push({ t: 'move', unit: u.id, from, to: { x: u.x, y: u.y }, seen: wasSeen || nowSeen });
    if (u.faction === 'alien' && !wasSeen && nowSeen) ev.push({ t: 'spotted', unit: u.id });
    if (u.faction === 'human') updateExplored(s);
    alienAwareness(s);
    reactionFire(s, u, ev);
    if (!u.alive || s.outcome !== 'ongoing') return { steps, interrupted: true };
    const fresh = spottedBy(s, u.faction).filter(e => !known.has(e.id));
    if (fresh.length) {
      if (u.faction === 'human') for (const e of fresh) ev.push({ t: 'spotted', unit: e.id });
      ev.push({ t: 'interrupt', unit: u.id });
      return { steps, interrupted: true };
    }
  }
  return { steps, interrupted: false };
}

export function canShoot(s: BattleState, u: Unit, t: Unit, mode: FireMode): string | null {
  const w = WEAPONS[u.weapon]!;
  if (!t.alive || t.faction === u.faction) return 'Cible invalide';
  if (!modeDef(u, mode)) return 'Mode indisponible';
  if (w.mag > 0 && u.ammo <= 0) return 'Chargeur vide';
  if (u.tu < shotCost(u, mode)) return 'UT insuffisantes';
  const info = hitChance(s, u, t, mode);
  if (!info.los) return 'Pas de ligne de tir';
  if (!info.inRange) return 'Hors de portée';
  return null;
}

export function doShoot(s: BattleState, u: Unit, t: Unit, mode: FireMode, ev: GameEvent[]): void {
  u.tu -= shotCost(u, mode);
  resolveShot(s, u, t, mode, ev);
}

export function canThrow(s: BattleState, u: Unit, to: Vec): string | null {
  if (u.grenades <= 0) return 'Plus de grenade';
  if (u.tu < RULES.grenadeTu) return 'UT insuffisantes';
  if (cheb(u, to) > RULES.grenadeRange) return 'Trop loin';
  if (!canSee(s, u, to)) return 'Point non visible';
  return null;
}

export function doThrow(s: BattleState, u: Unit, to: Vec, ev: GameEvent[]): void {
  u.tu -= RULES.grenadeTu;
  u.grenades--;
  explode(s, u, to, ev);
}

export function canHeal(u: Unit, t: Unit): string | null {
  if (u.medkit <= 0) return 'Kit médical vide';
  if (!t.alive || t.faction !== u.faction) return 'Cible invalide';
  if (cheb(u, t) > 1) return 'Trop loin (contact requis)';
  if (u.tu < RULES.medkitTu) return 'UT insuffisantes';
  if (t.hp >= t.maxHp && t.wounds === 0) return 'Pas blessé';
  return null;
}

export function doHeal(u: Unit, t: Unit, ev: GameEvent[]): void {
  u.tu -= RULES.medkitTu;
  u.medkit--;
  const amount = Math.min(RULES.medkitHeal, t.maxHp - t.hp);
  t.hp += amount;
  t.wounds = 0;
  ev.push({ t: 'heal', unit: u.id, target: t.id, amount });
}

export function canReload(u: Unit): string | null {
  const w = WEAPONS[u.weapon]!;
  if (w.mag === 0 || u.ammo >= w.mag) return 'Chargeur plein';
  if (u.tu < RULES.reloadTu) return 'UT insuffisantes';
  return null;
}

export function doReload(u: Unit, ev: GameEvent[]): void {
  u.tu -= RULES.reloadTu;
  u.ammo = WEAPONS[u.weapon]!.mag;
  ev.push({ t: 'reload', unit: u.id });
}

export function doKneel(u: Unit, ev: GameEvent[]): void {
  u.tu -= RULES.kneelTu;
  u.kneeling = true;
  ev.push({ t: 'kneel', unit: u.id });
}

export function doWatch(u: Unit, ev: GameEvent[]): void {
  u.tu -= RULES.watchTu;
  u.watching = true;
  ev.push({ t: 'watch', unit: u.id });
}

/** Ce qu'une interaction ferait depuis la position actuelle. */
export function interactTarget(s: BattleState, u: Unit): 'artifact' | 'terminal' | null {
  const o = s.objectives;
  if (o.artifact && cheb(u, o.artifact) <= 1) return 'artifact';
  if (!o.logsDone && cheb(u, o.terminal) <= 1) return 'terminal';
  return null;
}

export function doInteract(s: BattleState, u: Unit, ev: GameEvent[]): void {
  const what = interactTarget(s, u);
  u.tu -= RULES.interactTu;
  if (what === 'artifact') {
    u.carrying = true;
    s.objectives.artifact = null;
    ev.push({ t: 'pickup', unit: u.id });
    // L'artefact émet une pulsation : tous les hostiles savent où il est.
    s.alienAlert = true;
    s.lastKnown[u.id] = { x: u.x, y: u.y };
    ev.push({ t: 'alarm' });
  } else if (what === 'terminal') {
    s.objectives.logsDone = true;
    ev.push({ t: 'logs', unit: u.id });
  }
}

/** Soldats qui seraient évacués / laissés si on évacuait maintenant. */
export function evacSplit(s: BattleState) {
  const humans = living(s).filter(u => u.faction === 'human');
  return { leaving: humans.filter(u => inEvac(s, u)), staying: humans.filter(u => !inEvac(s, u)) };
}

export function doEvacuate(s: BattleState, ev: GameEvent[]): void {
  const { leaving } = evacSplit(s);
  for (const u of leaving) u.evacuated = true;
  ev.push({ t: 'evacuate', units: leaving.map(u => u.id) });
  s.outcome = leaving.some(u => u.carrying) ? 'victory' : 'defeat';
  ev.push({ t: 'outcome', outcome: s.outcome });
}

/** Victoire si tous les hostiles sont neutralisés, défaite si plus aucun soldat. */
export function checkOutcome(s: BattleState, ev: GameEvent[]): void {
  if (s.outcome !== 'ongoing') return;
  const alive = living(s);
  if (!alive.some(u => u.faction === 'human')) s.outcome = 'defeat';
  else if (!alive.some(u => u.faction === 'alien')) s.outcome = 'victory';
  if (s.outcome !== 'ongoing') ev.push({ t: 'outcome', outcome: s.outcome });
}
