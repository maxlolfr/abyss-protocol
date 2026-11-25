// Petites cartes de test construites à la main.
import { parseMap } from '../src/sim/map';
import { makeUnit, SAVE_VERSION } from '../src/sim/engine';
import type { BattleState, Unit, Vec } from '../src/sim/types';
import { seedFrom } from '../src/sim/rng';

export function arena(rows: string[], units: Array<{ id: string; kind: string; at: Vec } & Partial<Unit>>, seed = 'test'): BattleState {
  const m = parseMap(rows);
  return {
    version: SAVE_VERSION, seed, rng: seedFrom(seed), turn: 1, side: 'human', width: m.width, height: m.height,
    tiles: m.tiles, explored: m.tiles.map(() => false),
    units: units.map(({ id, kind, at, ...over }) => makeUnit(id, id, kind, at, over)),
    objectives: { artifact: null, terminal: { x: 0, y: 0 }, logsDone: false, evac: m.evac },
    outcome: 'ongoing', alienAlert: false, lastKnown: {}, commands: [],
  };
}

export const OPEN = [
  '############',
  '#..........#',
  '#..........#',
  '#..........#',
  '#..........#',
  '#..........#',
  '############',
];
