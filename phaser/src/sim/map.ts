// Carte de la phase 1 : laboratoire sous-marin abandonné « Station Thétis-7 ».
// Format texte (une case = un caractère) en attendant l'import Tiled de la phase 4.
import type { BattleState, Tile, Unit, Vec } from './types';
import { UNIT_TEMPLATES } from './data';

// #: cloison  .: sol  ~: zone inondée  c/x: console/caisse (obstacle bas = couvert partiel)
// T: terminal (obstacle bas, objectif secondaire)  S: départ soldat (dans le sas)  E: sas
// ?: emplacement alien possible  D: artefact (objectif principal)
export const LAB_MAP = [
  '########################',
  '#SSEE#......~~~~.......#',
  '#SSEE#..c...~~~~...?...#',
  '#EEEE.......~~##...x...#',
  '#..x.#####..~~##.......#',
  '#....#...#.....#..c....#',
  '##.###...#..?..#####.###',
  '#........#.....#.......#',
  '#..c..x..#..c........?.#',
  '#........#..?..#.......#',
  '###.######.....####.####',
  '#.....~~~#.....#.......#',
  '#..?..~~~...D......x...#',
  '#.....~~~#.....#...?...#',
  '#..x..c..###.###.......#',
  '#........#..?..#..T....#',
  '#....?...#.........x...#',
  '########################',
];

/** Mission Némésis (même plan que godot/sim/data.gd, ENV-007) : salle de confinement, artefact dans la cuve
 * au fond, mezzanines (=) et escaliers (/) des deux côtés, terminal sur la mezzanine est, bassins techniques,
 * sas au sud. Version Phaser : la simulation TS est encore plate (les hauteurs sont propres à Godot), les
 * mezzanines sont donc des planchers en caillebotis au niveau du sol. X : coque, k : caisse sur la mezzanine,
 * N/C/P : Néréide, Carapace, Spectre à des places fixes. */
export const NEMESIS_MAP = [
  'XXXXXXXXXXXXXXXX',
  'X=k=..cD.c..=T=X',
  'X=P=....C...===X',
  'X===..#..#..===X',
  'X===.c.....c===X',
  'X./..c....c../.X',
  'X...c..##..c...X',
  'X~~..........~NX',
  'X~~..........~~X',
  'X..c...#.#..c..X',
  'X.....SES......X',
  'X.....EEE......X',
  'X.....SES......X',
  'XXXXXXXXXXXXXXXX',
];

export const MAPS: Record<string, readonly string[]> = { lab: LAB_MAP, nemesis: NEMESIS_MAP };

export interface ParsedMap {
  width: number;
  height: number;
  tiles: Tile[];
  soldierSpawns: Vec[];
  alienSpots: Vec[];
  artifact: Vec;
  terminal: Vec;
  evac: Vec[];
  /** Aliens placés par la carte (N, C, P), sinon tirés au sort parmi les « ? ». */
  fixedAliens: Array<{ kind: string; at: Vec }>;
}

const FIXED: Record<string, string> = { N: 'nereide', C: 'carapace', P: 'spectre' };

export function parseMap(rows: readonly string[]): ParsedMap {
  const height = rows.length;
  const width = rows[0]!.length;
  const out: ParsedMap = { width, height, tiles: [], soldierSpawns: [], alienSpots: [], artifact: { x: 0, y: 0 }, terminal: { x: 0, y: 0 }, evac: [], fixedAliens: [] };
  rows.forEach((row, y) => {
    if (row.length !== width) throw new Error(`ligne ${y} : largeur ${row.length} au lieu de ${width}`);
    [...row].forEach((ch, x) => {
      const p = { x, y };
      out.tiles.push('#X'.includes(ch) ? 'wall' : ch === '~' ? 'water' : 'cxkT'.includes(ch) ? 'low' : 'floor');
      if (FIXED[ch]) out.fixedAliens.push({ kind: FIXED[ch]!, at: p });
      if (ch === 'S') out.soldierSpawns.push(p);
      if (ch === 'S' || ch === 'E') out.evac.push(p);
      if (ch === '?') out.alienSpots.push(p);
      if (ch === 'D') out.artifact = p;
      if (ch === 'T') out.terminal = p;
    });
  });
  return out;
}

export const idx = (s: { width: number }, x: number, y: number) => y * s.width + x;
export const inBounds = (s: { width: number; height: number }, x: number, y: number) =>
  x >= 0 && y >= 0 && x < s.width && y < s.height;
export const tileAt = (s: BattleState, x: number, y: number): Tile =>
  inBounds(s, x, y) ? s.tiles[idx(s, x, y)]! : 'wall';

export const living = (s: BattleState) => s.units.filter(u => u.alive && !u.evacuated);
export const unitAt = (s: BattleState, x: number, y: number) => living(s).find(u => u.x === x && u.y === y);
export const unitById = (s: BattleState, id: string) => s.units.find(u => u.id === id);

/** Une case peut-elle accueillir cette unité (hors occupation) ? */
export function standable(s: BattleState, u: Unit, x: number, y: number): boolean {
  const t = tileAt(s, x, y);
  if (t === 'wall') return false;
  if (t === 'low') return !!UNIT_TEMPLATES[u.kind]?.hover;
  return true;
}

export const dist = (a: Vec, b: Vec) => Math.hypot(a.x - b.x, a.y - b.y);
export const cheb = (a: Vec, b: Vec) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
export const inEvac = (s: BattleState, p: Vec) => s.objectives.evac.some(e => e.x === p.x && e.y === p.y);
