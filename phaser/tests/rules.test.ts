import { describe, it, expect } from 'vitest';
import { arena, OPEN } from './helpers';
import { LAB_MAP, parseMap } from '../src/sim/map';
import { findPath, reachable, stepCost } from '../src/sim/pathfinding';
import { hasLine, updateExplored } from '../src/sim/los';
import { coverAgainst } from '../src/sim/cover';
import { hitChance } from '../src/sim/combat';
import { next, seedFrom } from '../src/sim/rng';
import { RULES } from '../src/sim/data';

describe('RNG', () => {
  it('même seed, même suite', () => {
    const a = { rng: seedFrom('abc') }, b = { rng: seedFrom('abc') };
    const xa = [next(a), next(a), next(a)], xb = [next(b), next(b), next(b)];
    expect(xa).toEqual(xb);
    expect(xa.every(v => v >= 0 && v < 1)).toBe(true);
  });
});

describe('Carte du laboratoire', () => {
  const m = parseMap(LAB_MAP);
  it('contient les éléments de la mission', () => {
    expect(m.soldierSpawns).toHaveLength(4);
    expect(m.alienSpots.length).toBeGreaterThanOrEqual(6);
    expect(m.evac.length).toBeGreaterThanOrEqual(4);
    expect(m.tiles[m.terminal.y * m.width + m.terminal.x]).toBe('low');
  });
  it('toutes les cases praticables sont reliées', () => {
    const s = arena(LAB_MAP, [{ id: 's', kind: 'soldier', at: m.soldierSpawns[0]! }]);
    const r = reachable(s, s.units[0]!, 100000);
    const walk = m.tiles.filter(t => t === 'floor' || t === 'water').length;
    expect(r.cost.size).toBe(walk);
  });
});

describe('Pathfinding et UT', () => {
  const rows = ['#######', '#.....#', '#.~~..#', '#.#...#', '#######'];
  it('coûts orthogonal 6, diagonal 8, eau +4', () => {
    const s = arena(rows, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 } }, { id: 'n', kind: 'nereide', at: { x: 5, y: 1 } }]);
    const [sol, ner] = s.units as [any, any];
    expect(stepCost(s, sol, 1, 1, 2, 1)).toBe(RULES.moveOrtho);
    expect(stepCost(s, sol, 1, 1, 2, 2)).toBe(RULES.moveDiag + RULES.waterExtra);
    expect(stepCost(s, ner, 4, 1, 3, 2)).toBe(RULES.moveDiag); // amphibie
  });
  it('pas de coupe en diagonale contre un mur', () => {
    const s = arena(rows, [{ id: 's', kind: 'soldier', at: { x: 1, y: 2 } }]);
    expect(stepCost(s, s.units[0]!, 1, 2, 2, 3)).toBe(Infinity); // (2,3) est un mur
    expect(stepCost(s, s.units[0]!, 1, 3, 2, 2)).toBe(Infinity); // l'angle (2,3) est un mur
    expect(stepCost(s, s.units[0]!, 1, 2, 2, 1)).toBe(RULES.moveDiag); // angles libres
  });
  it('la zone atteignable respecte les UT', () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 }, tu: 12 }]);
    const r = reachable(s, s.units[0]!);
    expect(Math.max(...r.cost.values())).toBeLessThanOrEqual(12);
    expect(r.cost.has(1 * 12 + 3)).toBe(true); // 2 cases à droite = 12 UT
    expect(r.cost.has(1 * 12 + 4)).toBe(false);
  });
  it('A* trouve le chemin le moins cher', () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 } }]);
    const p = findPath(s, s.units[0]!, { x: 4, y: 4 })!;
    expect(p.cost).toBe(3 * RULES.moveDiag);
  });
});

describe('Ligne de vue, brouillard, couverture', () => {
  const rows = ['#########', '#.......#', '#...#...#', '#...c...#', '#.......#', '#########'];
  it('les cloisons bloquent, les obstacles bas non', () => {
    const s = arena(rows, []);
    expect(hasLine(s, { x: 2, y: 2 }, { x: 6, y: 2 })).toBe(false);
    expect(hasLine(s, { x: 2, y: 3 }, { x: 6, y: 3 })).toBe(true);
  });
  it('le brouillard se lève autour des soldats seulement', () => {
    const s = arena(rows, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 } }]);
    updateExplored(s);
    expect(s.explored[1 * 9 + 2]).toBe(true);
    expect(s.explored[2 * 9 + 7]).toBe(false); // derrière la cloison
  });
  it('couverture partielle, totale, à genoux, de flanc', () => {
    const s = arena(rows, []);
    expect(coverAgainst(s, { x: 5, y: 3 }, { x: 1, y: 3 })).toBe(1); // console à l'ouest
    expect(coverAgainst(s, { x: 5, y: 3 }, { x: 1, y: 3 }, true)).toBe(2); // à genoux
    expect(coverAgainst(s, { x: 5, y: 2 }, { x: 1, y: 2 })).toBe(2); // cloison
    expect(coverAgainst(s, { x: 5, y: 3 }, { x: 5, y: 1 })).toBe(0); // flanqué par le nord
    expect(coverAgainst(s, { x: 5, y: 3 }, { x: 4, y: 4 })).toBe(0); // au contact
  });
});

describe('Probabilité de toucher', () => {
  const rows = ['############', '#..........#', '#......c...#', '#..........#', '############'];
  it('la couverture et la distance réduisent la chance, bornée 5–95', () => {
    const s = arena(rows, [
      { id: 's', kind: 'soldier', at: { x: 2, y: 2 } },
      { id: 'a', kind: 'nereide', at: { x: 8, y: 2 } },
      { id: 'b', kind: 'nereide', at: { x: 8, y: 1 } },
    ]);
    const [sol, cov, open] = s.units as [any, any, any];
    const c1 = hitChance(s, sol, cov, 'aimed').chance, c2 = hitChance(s, sol, open, 'aimed').chance;
    expect(c1).toBeLessThan(c2);
    expect(c2).toBeLessThanOrEqual(95);
    expect(hitChance(s, sol, open, 'snap').chance).toBeLessThan(c2);
  });
  it("l'onde psychique ignore la couverture", () => {
    const s = arena(rows, [
      { id: 'sp', kind: 'spectre', at: { x: 2, y: 2 } },
      { id: 's', kind: 'soldier', at: { x: 8, y: 2 } },
    ]);
    expect(hitChance(s, s.units[0]!, s.units[1]!, 'snap').cover).toBe(0);
  });
});

describe('Décor destructible', () => {
  it('la grenade pulvérise les obstacles bas au contact', async () => {
    const { explode } = await import('../src/sim/combat');
    const rows = ['#######', '#.....#', '#..c..#', '#.....#', '#######'];
    const s = arena(rows, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 } }]);
    s.objectives.terminal = { x: 0, y: 0 };
    const ev: any[] = [];
    explode(s, s.units[0]!, { x: 4, y: 2 }, ev);
    expect(s.tiles[2 * 7 + 3]).toBe('floor');
    expect(ev.some(e => e.t === 'destroy')).toBe(true);
  });
});
