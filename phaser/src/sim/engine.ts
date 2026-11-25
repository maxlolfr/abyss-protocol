// TacticalEngine : point d'entrée unique de la simulation.
// Le rendu ne modifie jamais l'état directement : il envoie des Command et rejoue les GameEvent reçus.
import type { BattleState, Command, CoverLevel, FireMode, GameEvent, Unit, Vec } from './types';
import { ALIEN_ROSTER, RULES, SQUAD, UNIT_TEMPLATES, WEAPONS } from './data';
import { LAB_MAP, idx, living, parseMap, unitById } from './map';
import { pathFrom, reachable, type Reach } from './pathfinding';
import { canSee, spottedBy, updateExplored } from './los';
import { coverAgainst } from './cover';
import { hitChance } from './combat';
import { seedFrom, int } from './rng';
import {
  canHeal, canReload, canShoot, canThrow, checkOutcome, doEvacuate, doHeal, doInteract, doKneel, doMove, doReload,
  doShoot, doThrow, doWatch, evacSplit, interactTarget, shotCost,
} from './actions';
import { endPlayerTurn } from './turn';

export const SAVE_VERSION = 1;

export function makeUnit(id: string, name: string, kind: string, p: Vec, over: Partial<Unit> = {}): Unit {
  const t = UNIT_TEMPLATES[kind]!;
  const weapon = over.weapon ?? t.weapon;
  const hp = over.maxHp ?? t.hp, tu = over.maxTu ?? t.tu;
  return {
    id, name, faction: kind === 'soldier' ? 'human' : 'alien', kind, x: p.x, y: p.y,
    hp, maxHp: hp, tu, maxTu: tu, accuracy: t.accuracy, reactions: t.reactions, armor: t.armor,
    weapon, ammo: WEAPONS[weapon]!.mag, wounds: 0, drain: 0, kneeling: false, watching: false,
    alive: true, evacuated: false, grenades: 0, medkit: 0, carrying: false, kills: 0, ...over,
  };
}

/** Nouvelle bataille. La seed choisit les positions des aliens parmi les emplacements prévus. */
export function createBattle(seed: string): BattleState {
  const m = parseMap(LAB_MAP);
  const s: BattleState = {
    version: SAVE_VERSION, seed, rng: seedFrom(seed), turn: 1, side: 'human',
    width: m.width, height: m.height, tiles: m.tiles, explored: m.tiles.map(() => false), units: [],
    objectives: { artifact: m.artifact, terminal: m.terminal, logsDone: false, evac: m.evac },
    outcome: 'ongoing', alienAlert: false, lastKnown: {}, commands: [],
  };
  SQUAD.forEach((q, i) => s.units.push(makeUnit(q.id, q.name, 'soldier', m.soldierSpawns[i]!, {
    weapon: q.weapon, accuracy: q.accuracy, reactions: q.reactions, maxTu: q.tu, tu: q.tu, maxHp: q.hp, hp: q.hp,
    medkit: q.medkit, grenades: q.grenades, ammo: WEAPONS[q.weapon]!.mag,
  })));
  const spots = [...m.alienSpots];
  for (let i = spots.length - 1; i > 0; i--) { const j = int(s, i + 1); [spots[i], spots[j]] = [spots[j]!, spots[i]!]; }
  const count: Record<string, number> = {};
  ALIEN_ROSTER.forEach((kind, i) => {
    count[kind] = (count[kind] ?? 0) + 1;
    s.units.push(makeUnit(`a${i + 1}`, `${UNIT_TEMPLATES[kind]!.name} ${count[kind]}`, kind, spots[i]!));
  });
  updateExplored(s);
  return s;
}

export interface MovePreview { path: Vec[]; cost: number; tuAfter: number; cover: CoverLevel; reactors: number; ok: boolean }
export interface ShotPreview { cost: number; chance: number; cover: CoverLevel; tuAfter: number; from: Vec; to: Vec; error: string | null }

export class TacticalEngine {
  private reachCache: { key: string; r: Reach } | null = null;

  constructor(public state: BattleState) {}

  static create(seed: string) { return new TacticalEngine(createBattle(seed)); }

  unit(id: string): Unit | undefined { return unitById(this.state, id); }
  get soldiers() { return this.state.units.filter(u => u.faction === 'human'); }
  /** Aliens actuellement visibles par l'escouade (seuls ceux-là sont affichés). */
  visibleAliens(): Unit[] { return spottedBy(this.state, 'human'); }

  reach(u: Unit): Reach {
    const key = `${u.id}:${u.x},${u.y}:${u.tu}:${this.state.commands.length}`;
    if (this.reachCache?.key !== key) this.reachCache = { key, r: reachable(this.state, u) };
    return this.reachCache.r;
  }

  previewMove(u: Unit, to: Vec): MovePreview | null {
    const r = this.reach(u);
    const cost = r.cost.get(idx(this.state, to.x, to.y));
    if (cost === undefined || cost === 0) return null;
    const path = pathFrom(this.state, r, to)!;
    // ennemis visibles qui verraient la destination et ont de quoi tirer en réaction
    const reactors = this.visibleAliens().filter(e => canSee(this.state, e, to) && e.tu >= WEAPONS[e.weapon]!.snap.tu).length;
    const threats = this.visibleAliens();
    const cover = threats.length ? Math.min(...threats.map(e => coverAgainst(this.state, to, e))) as CoverLevel : 0;
    return { path, cost, tuAfter: u.tu - cost, cover, reactors, ok: true };
  }

  previewShot(u: Unit, t: Unit, mode: FireMode): ShotPreview {
    const info = hitChance(this.state, u, t, mode);
    const cost = shotCost(u, mode);
    return { cost, chance: info.chance, cover: info.cover, tuAfter: u.tu - cost, from: { x: u.x, y: u.y }, to: { x: t.x, y: t.y }, error: canShoot(this.state, u, t, mode) };
  }

  canThrow(u: Unit, to: Vec) { return canThrow(this.state, u, to); }
  canHeal(u: Unit, t: Unit) { return canHeal(u, t); }
  canReload(u: Unit) { return canReload(u); }
  interactTarget(u: Unit) { return interactTarget(this.state, u); }
  evacSplit() { return evacSplit(this.state); }

  /** Valide puis exécute une commande. Renvoie les événements à rejouer ([] si refusée). */
  apply(cmd: Command): GameEvent[] {
    const s = this.state;
    if (s.outcome !== 'ongoing' || s.side !== 'human') return [];
    const ev: GameEvent[] = [];
    const u = 'unit' in cmd ? unitById(s, cmd.unit) : undefined;
    if ('unit' in cmd && (!u || !u.alive || u.evacuated || u.faction !== 'human')) return [];
    switch (cmd.type) {
      case 'move': {
        const p = this.previewMove(u!, cmd.to);
        if (!p) return [];
        doMove(s, u!, p.path, ev);
        break;
      }
      case 'shoot': {
        const t = unitById(s, cmd.target);
        if (!t || canShoot(s, u!, t, cmd.mode)) return [];
        doShoot(s, u!, t, cmd.mode, ev);
        break;
      }
      case 'throw':
        if (canThrow(s, u!, cmd.to)) return [];
        doThrow(s, u!, cmd.to, ev);
        break;
      case 'heal': {
        const t = unitById(s, cmd.target);
        if (!t || canHeal(u!, t)) return [];
        doHeal(u!, t, ev);
        break;
      }
      case 'reload':
        if (canReload(u!)) return [];
        doReload(u!, ev);
        break;
      case 'kneel':
        if (u!.kneeling || u!.tu < RULES.kneelTu) return [];
        doKneel(u!, ev);
        break;
      case 'watch':
        if (u!.watching || u!.tu < RULES.watchTu) return [];
        doWatch(u!, ev);
        break;
      case 'interact':
        if (!interactTarget(s, u!) || u!.tu < RULES.interactTu) return [];
        doInteract(s, u!, ev);
        break;
      case 'evacuate':
        if (!evacSplit(s).leaving.length) return [];
        doEvacuate(s, ev);
        break;
      case 'endTurn':
        endPlayerTurn(s, ev);
        updateExplored(s);
        break;
    }
    s.commands.push(cmd);
    checkOutcome(s, ev);
    return ev;
  }

  /** Résumé de fin de mission (récapitulatif unique, pas de popups intermédiaires). */
  summary() {
    const s = this.state;
    const soldiers = this.soldiers;
    const aliens = s.units.filter(u => u.faction === 'alien');
    const carrier = soldiers.find(u => u.carrying && (u.evacuated || u.alive));
    const someEvacuated = soldiers.some(u => u.evacuated);
    return {
      outcome: s.outcome,
      turns: s.turn,
      artifact: !!carrier || (s.outcome === 'victory' && !living(s).some(u => u.faction === 'alien')),
      logs: s.objectives.logsDone,
      kills: aliens.filter(a => !a.alive).length,
      aliens: aliens.length,
      lost: soldiers.filter(u => !u.alive || (someEvacuated && !u.evacuated)).length,
      soldiers: soldiers.map(u => ({ name: u.name, alive: u.alive, kills: u.kills, hp: u.hp, maxHp: u.maxHp })),
    };
  }
}
