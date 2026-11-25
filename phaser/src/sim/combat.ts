// CombatResolver : probabilité de toucher, dégâts, blessures, grenade, tirs de réaction.
import type { BattleState, CoverLevel, FireMode, GameEvent, Unit, Vec } from './types';
import { RULES, WEAPONS } from './data';
import { cheb, dist, idx, living, tileAt } from './map';
import { canSee, hasLine } from './los';
import { coverAgainst } from './cover';
import { next, roll } from './rng';

export interface ShotInfo { chance: number; cover: CoverLevel; distance: number; inRange: boolean; los: boolean; cost: number }

export function modeDef(u: Unit, mode: FireMode) {
  const w = WEAPONS[u.weapon]!;
  return mode === 'aimed' ? w.aimed : w.snap;
}

/** Probabilité de toucher (en %) si `shooter` tire depuis `from` sur `target`. 0 si impossible. */
export function hitChance(s: BattleState, shooter: Unit, target: Unit, mode: FireMode, from: Vec = shooter): ShotInfo {
  const w = WEAPONS[shooter.weapon]!;
  const m = modeDef(shooter, mode);
  const distance = dist(from, target);
  const cover = w.ignoresCover ? 0 : coverAgainst(s, target, from, target.kneeling);
  const los = hasLine(s, from, target);
  const inRange = distance <= w.range;
  const cost = m?.tu ?? Infinity;
  if (!m || !los || !inRange) return { chance: 0, cover, distance, inRange, los, cost };
  let c = (shooter.accuracy * m.acc) / 100;
  if (shooter.kneeling && from === shooter) c += RULES.kneelAcc;
  c -= Math.max(0, distance - RULES.rangePenaltyFrom) * (mode === 'snap' ? 3 : 2);
  c -= Math.min(4, shooter.wounds) * RULES.woundPenalty;
  c -= RULES.coverPenalty[cover];
  const chance = Math.round(Math.min(RULES.maxChance, Math.max(RULES.minChance, c)));
  return { chance, cover, distance, inRange, los, cost };
}

export const seenByHumans = (s: BattleState, p: Vec) =>
  living(s).some(h => h.faction === 'human' && canSee(s, h, p));

/** Inflige des dégâts déjà réduits par l'armure. */
export function applyDamage(s: BattleState, target: Unit, amount: number, ev: GameEvent[], attacker?: Unit, drain = 0): void {
  if (!target.alive) return;
  const wounded = amount >= RULES.woundThreshold;
  target.hp -= amount;
  if (wounded) target.wounds++;
  target.drain += drain;
  ev.push({ t: 'damage', unit: target.id, amount, hp: Math.max(0, target.hp), wounded, drained: drain });
  if (target.faction === 'alien') s.alienAlert = true;
  if (target.hp <= 0) kill(s, target, ev, attacker);
}

export function kill(s: BattleState, u: Unit, ev: GameEvent[], by?: Unit): void {
  u.alive = false;
  u.hp = 0;
  if (by) by.kills++;
  ev.push({ t: 'death', unit: u.id });
  if (u.carrying) {
    u.carrying = false;
    s.objectives.artifact = { x: u.x, y: u.y };
    ev.push({ t: 'drop', at: { x: u.x, y: u.y } });
  }
}

/** Résout un tir (les UT ont déjà été payées par l'appelant). */
export function resolveShot(s: BattleState, shooter: Unit, target: Unit, mode: FireMode, ev: GameEvent[], reaction = false): void {
  const w = WEAPONS[shooter.weapon]!;
  const info = hitChance(s, shooter, target, mode);
  if (w.mag > 0) shooter.ammo--;
  shooter.kneeling = shooter.kneeling && !reaction;
  const hit = roll(s, info.chance);
  const seen = shooter.faction === 'human' || seenByHumans(s, shooter);
  ev.push({ t: 'shot', unit: shooter.id, from: { x: shooter.x, y: shooter.y }, to: { x: target.x, y: target.y }, target: target.id, weapon: shooter.weapon, mode, chance: info.chance, hit, reaction, seen });
  if (shooter.faction === 'human') {
    s.alienAlert = true;
    // la cible repère d'où vient le tir
    s.lastKnown[shooter.id] = { x: shooter.x, y: shooter.y };
  }
  if (!hit) return;
  const raw = Math.round(w.damage * (0.5 + next(s)));
  applyDamage(s, target, Math.max(0, raw - target.armor), ev, shooter, w.drain ?? 0);
}

/** Grenade : dégâts dégressifs autour du point d'impact (alliés compris). */
export function explode(s: BattleState, thrower: Unit, at: Vec, ev: GameEvent[]): void {
  ev.push({ t: 'explosion', at, radius: RULES.grenadeRadius });
  s.alienAlert = true;
  for (const u of living(s).sort((a, b) => a.id.localeCompare(b.id))) {
    const d = cheb(u, at);
    if (d > RULES.grenadeRadius || !hasLine(s, at, u)) continue;
    const raw = Math.round((RULES.grenadeDamage - RULES.grenadeFalloff * d) * (0.8 + 0.4 * next(s)));
    applyDamage(s, u, Math.max(0, raw - Math.floor(u.armor / 2)), ev, thrower);
  }
  // Décor destructible : les obstacles bas au contact de l'explosion sont pulvérisés (sauf le terminal).
  for (let y = at.y - 1; y <= at.y + 1; y++)
    for (let x = at.x - 1; x <= at.x + 1; x++) {
      const t = s.objectives.terminal;
      if (tileAt(s, x, y) !== 'low' || (x === t.x && y === t.y)) continue;
      s.tiles[idx(s, x, y)] = 'floor';
      ev.push({ t: 'destroy', at: { x, y } });
    }
}

const reactionScore = (u: Unit) => (u.reactions * u.tu) / u.maxTu;

/**
 * Tirs de réaction contre `mover` après un pas. Un ennemi tire s'il voit le mobile, l'a à portée,
 * a les UT d'un tir rapide et un meilleur score de réaction (réactions × UT restantes / UT max),
 * ou s'il est en surveillance (premier tir gratuit et garanti).
 */
export function reactionFire(s: BattleState, mover: Unit, ev: GameEvent[]): void {
  const enemies = living(s).filter(e => e.faction !== mover.faction).sort((a, b) => a.id.localeCompare(b.id));
  for (const e of enemies) {
    if (!mover.alive || s.outcome !== 'ongoing') return;
    const w = WEAPONS[e.weapon]!;
    if (w.mag > 0 && e.ammo <= 0) continue;
    if (!canSee(s, e, mover) || dist(e, mover) > w.range) continue;
    const cost = e.watching ? 0 : w.snap.tu;
    if (e.tu < cost) continue;
    if (!e.watching && reactionScore(e) <= reactionScore(mover)) continue;
    e.tu -= cost;
    e.watching = false;
    if (e.faction === 'alien') { s.alienAlert = true; s.lastKnown[mover.id] = { x: mover.x, y: mover.y }; }
    resolveShot(s, e, mover, 'snap', ev, true);
  }
}
