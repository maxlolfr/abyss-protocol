// EnemyAI : IA à règles et à score, déterministe (seed + ordre fixe des unités).
// Chaque archétype pondère différemment : Néréide = flanc, Carapace = pression, Spectre = harcèlement à distance.
import type { BattleState, FireMode, GameEvent, Unit, Vec } from './types';
import { UNIT_TEMPLATES, WEAPONS } from './data';
import { cheb, dist, idx, living, unitById } from './map';
import { pathFrom, reachable, findPath } from './pathfinding';
import { canSee } from './los';
import { coverAgainst } from './cover';
import { hitChance } from './combat';
import { alienAwareness, checkOutcome, doMove, doShoot, shotCost } from './actions';
import { int } from './rng';

const COVER_SHIELD = [1, 0.45, 0.12];

function knownTargets(s: BattleState, side: Unit['faction']): Unit[] {
  const mine = living(s).filter(u => u.faction === side);
  return living(s).filter(e => e.faction !== side && !e.downed && mine.some(m => canSee(s, m, e))); // un soldat à terre n'est plus une cible
}

/** Danger d'une case : somme des ennemis connus qui la voient, pondérée par la couverture. */
function exposure(s: BattleState, p: Vec, foes: Unit[]): number {
  let e = 0;
  for (const f of foes) if (canSee(s, f, p)) e += COVER_SHIELD[coverAgainst(s, p, f)]!;
  return e;
}

/** Meilleure attaque possible depuis `from` avec `tu` UT. */
function bestAttack(s: BattleState, a: Unit, from: Vec, tu: number, foes: Unit[]) {
  const w = WEAPONS[a.weapon]!;
  let best: { target: Unit; mode: FireMode; value: number; chance: number } | null = null;
  for (const t of foes) {
    if (dist(from, t) > w.range || !canSee(s, a, t, from)) continue;
    for (const mode of ['snap', 'aimed'] as FireMode[]) {
      const cost = shotCost(a, mode);
      if (cost > tu) continue;
      const { chance } = hitChance(s, a, t, mode, from);
      const shots = Math.min(2, Math.floor(tu / cost));
      const dmg = Math.max(1, w.damage - t.armor) + (w.drain ? 10 : 0);
      const value = (chance / 100) * dmg * shots * (t.hp <= w.damage ? 1.4 : 1) * (t.carrying ? 1.3 : 1);
      if (!best || value > best.value) best = { target: t, mode, value, chance };
    }
  }
  return best;
}

function scoreTile(s: BattleState, a: Unit, p: Vec, cost: number, foes: Unit[]): number {
  const role = UNIT_TEMPLATES[a.kind]!.role;
  const left = a.tu - cost;
  const atk = bestAttack(s, a, p, left, foes);
  let score = atk ? atk.value : 0;
  const exp = exposure(s, p, foes);
  const nearest = Math.min(...foes.map(f => dist(p, f)));
  if (role === 'flanker') {
    if (atk && coverAgainst(s, atk.target, p) === 0) score += 8; // cherche le flanc
    score -= exp * 7;
  } else if (role === 'brute') {
    score -= nearest * 1.2; // avance et met la pression
    score -= exp * 2.5;
  } else {
    score -= Math.abs(nearest - 7) * 1.5; // garde ses distances
    score -= exp * 9;
  }
  return score - cost * 0.04;
}

function walkTo(s: BattleState, a: Unit, target: Vec, reserve: number, ev: GameEvent[]): boolean {
  const r = reachable(s, a, Math.max(0, a.tu - reserve));
  const full = findPath(s, a, target);
  if (!full) return false;
  // Aller le plus loin possible le long du trajet complet, dans la limite des UT.
  let stop: Vec | null = null;
  for (const p of full.path) if (r.cost.has(idx(s, p.x, p.y))) stop = p;
  if (!stop) return false;
  const path = pathFrom(s, r, stop);
  if (!path || !path.length) return false;
  return doMove(s, a, path, ev).interrupted;
}

function actAlien(s: BattleState, a: Unit, ev: GameEvent[]): void {
  const w = WEAPONS[a.weapon]!;
  for (let iter = 0; iter < 4 && a.alive && s.outcome === 'ongoing'; iter++) {
    alienAwareness(s);
    const foes = knownTargets(s, 'alien');
    if (!foes.length) {
      if (!s.alienAlert) {
        // patrouille calme autour de sa position, en gardant des UT pour réagir
        // Némésis : la brute rôde vers le sas pour un contact rapide ; les autres restent près de leur poste
        const sas = s.mission === 'nemesis' && UNIT_TEMPLATES[a.kind]!.role === 'brute' ? s.objectives.evac[0] : undefined;
        const goal = sas ? { x: sas.x + int(s, 3) - 1, y: sas.y - 3 } : { x: a.x + int(s, 7) - 3, y: a.y + int(s, 7) - 3 };
        walkTo(s, a, goal, Math.ceil(a.tu / 2), ev);
        return;
      }
      // chasse : vers la dernière position connue la plus proche
      // Alerte locale : on ne converge que vers un bruit proche, sauf si l'artefact a été pris (pulsation).
      const range = s.objectives.artifact === null ? Infinity : 11;
      const spots = Object.entries(s.lastKnown).filter(([id, p]) => unitById(s, id)?.alive && dist(a, p) <= range);
      if (!spots.length) return;
      spots.sort((p, q) => dist(a, p[1]) - dist(a, q[1]) || p[0].localeCompare(q[0]));
      const [id, spot] = spots[0]!;
      if (cheb(a, spot) <= 1) { delete s.lastKnown[id]; continue; }
      const reserve = UNIT_TEMPLATES[a.kind]!.role === 'brute' ? 0 : w.snap.tu;
      if (!walkTo(s, a, spot, reserve, ev)) return; // pas interrompu : fin d'activation
      continue;
    }
    // 1) se placer sur la meilleure case (dont la case actuelle)
    const r = reachable(s, a, a.tu - w.snap.tu);
    let best = { i: idx(s, a.x, a.y), score: scoreTile(s, a, a, 0, foes) };
    for (const [i, c] of r.cost) {
      if (c === 0) continue;
      const sc = scoreTile(s, a, { x: i % s.width, y: Math.floor(i / s.width) }, c, foes);
      if (sc > best.score + 0.01) best = { i, score: sc };
    }
    if (best.i !== idx(s, a.x, a.y)) {
      const path = pathFrom(s, r, { x: best.i % s.width, y: Math.floor(best.i / s.width) })!;
      if (doMove(s, a, path, ev).interrupted) { checkOutcome(s, ev); continue; }
    }
    // 2) tirer tant que c'est rentable
    for (let n = 0; n < 3 && a.alive; n++) {
      const atk = bestAttack(s, a, a, a.tu, knownTargets(s, 'alien'));
      if (!atk || atk.chance < 8) break;
      doShoot(s, a, atk.target, atk.mode, ev);
      checkOutcome(s, ev);
      if (s.outcome !== 'ongoing') return;
    }
    // 3) se mettre à l'abri avec les UT restantes
    const left = knownTargets(s, 'alien');
    if (a.alive && left.length && exposure(s, a, left) > 0.2) {
      const rr = reachable(s, a, a.tu);
      let safe = { i: idx(s, a.x, a.y), v: exposure(s, a, left) };
      for (const [i, c] of rr.cost) {
        const v = exposure(s, { x: i % s.width, y: Math.floor(i / s.width) }, left) + c * 0.005;
        if (v < safe.v - 0.05) safe = { i, v };
      }
      if (safe.i !== idx(s, a.x, a.y)) doMove(s, a, pathFrom(s, rr, { x: safe.i % s.width, y: Math.floor(safe.i / s.width) })!, ev);
    }
    return;
  }
}

/** Joue le tour complet d'un camp contrôlé par l'IA (aliens ; aussi utilisé pour les simulations). */
export function runAiTurn(s: BattleState, side: Unit['faction'], ev: GameEvent[]): void {
  const actors = living(s).filter(u => u.faction === side).sort((a, b) => a.id.localeCompare(b.id));
  for (const a of actors) {
    if (s.outcome !== 'ongoing') return;
    if (side === 'alien') actAlien(s, a, ev);
    else actAsSoldier(s, a, ev);
    checkOutcome(s, ev);
  }
}

/** Version « soldat » de l'IA, pour les simulations d'équilibrage (IA contre IA). */
function actAsSoldier(s: BattleState, a: Unit, ev: GameEvent[]): void {
  const w = WEAPONS[a.weapon]!;
  if (w.mag > 0 && a.ammo === 0 && a.tu >= 8) { a.tu -= 8; a.ammo = w.mag; }
  const foes = knownTargets(s, 'human');
  if (!foes.length) {
    const goal = s.objectives.artifact ?? { x: 12, y: 12 };
    walkTo(s, a, goal, w.snap.tu * 2, ev);
    return;
  }
  const r = reachable(s, a, a.tu - w.snap.tu);
  let best = { i: idx(s, a.x, a.y), score: -Infinity };
  for (const [i, c] of r.cost) {
    const p = { x: i % s.width, y: Math.floor(i / s.width) };
    const atk = bestAttack(s, a, p, a.tu - c, foes);
    const sc = (atk ? atk.value : 0) - exposure(s, p, foes) * 6 - c * 0.04;
    if (sc > best.score) best = { i, score: sc };
  }
  if (best.i !== idx(s, a.x, a.y)) doMove(s, a, pathFrom(s, r, { x: best.i % s.width, y: Math.floor(best.i / s.width) })!, ev);
  for (let n = 0; n < 3 && a.alive; n++) {
    const atk = bestAttack(s, a, a, a.tu, knownTargets(s, 'human'));
    if (!atk || (w.mag > 0 && a.ammo <= 0)) break;
    doShoot(s, a, atk.target, atk.mode, ev);
    checkOutcome(s, ev);
    if (s.outcome !== 'ongoing') return;
  }
}
