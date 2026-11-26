import { describe, it, expect } from 'vitest';
import { arena, OPEN } from './helpers';
import { TacticalEngine, createBattle } from '../src/sim/engine';
import { deserialize, serialize, SaveManager } from '../src/sim/save';
import { runAiTurn } from '../src/sim/ai';
import { endPlayerTurn } from '../src/sim/turn';
import { RULES, WEAPONS } from '../src/sim/data';
import type { Command, GameEvent } from '../src/sim/types';

const memStore = () => { const m = new Map<string, string>(); return { getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => void m.set(k, v), removeItem: (k: string) => void m.delete(k) }; };

describe('TacticalEngine : commandes et UT', () => {
  it('un déplacement coûte exactement son aperçu', () => {
    const e = TacticalEngine.create('ut');
    const u = e.unit('s3')!; // s1 est encerclé par l'escouade au départ
    const to = { x: u.x + 1, y: u.y + 2 };
    const p = e.previewMove(u, to)!;
    const before = u.tu;
    e.apply({ type: 'move', unit: 's3', to });
    expect(u.tu).toBe(before - p.cost);
    expect(u.tu).toBe(p.tuAfter);
  });
  it('refuse les commandes impossibles sans rien modifier', () => {
    const e = TacticalEngine.create('refus');
    const snap = JSON.stringify(e.state);
    expect(e.apply({ type: 'move', unit: 's1', to: { x: 0, y: 0 } })).toHaveLength(0);
    expect(e.apply({ type: 'shoot', unit: 's1', target: 'a1', mode: 'aimed' })).toHaveLength(0);
    expect(e.apply({ type: 'interact', unit: 's1' })).toHaveLength(0);
    expect(e.apply({ type: 'move', unit: 'a1', to: { x: 2, y: 2 } })).toHaveLength(0);
    expect(JSON.stringify(e.state)).toBe(snap);
  });
  it('tir : UT, munitions, rechargement', () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 3 } }, { id: 'a', kind: 'carapace', at: { x: 6, y: 3 }, hp: 999, maxHp: 999 }]);
    const e = new TacticalEngine(s);
    const u = s.units[0]!;
    e.apply({ type: 'shoot', unit: 's', target: 'a', mode: 'snap' });
    expect(u.tu).toBe(60 - WEAPONS.rifle!.snap.tu);
    expect(u.ammo).toBe(WEAPONS.rifle!.mag - 1);
    e.apply({ type: 'reload', unit: 's' });
    expect(u.ammo).toBe(WEAPONS.rifle!.mag);
    expect(u.tu).toBe(60 - WEAPONS.rifle!.snap.tu - RULES.reloadTu);
  });
  it('à genoux : +précision, couvert bas devient total', () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 3 } }, { id: 'a', kind: 'nereide', at: { x: 9, y: 3 } }]);
    const e = new TacticalEngine(s);
    const before = e.previewShot(s.units[0]!, s.units[1]!, 'aimed').chance;
    e.apply({ type: 'kneel', unit: 's' });
    expect(e.previewShot(s.units[0]!, s.units[1]!, 'aimed').chance).toBe(Math.min(95, before + RULES.kneelAcc));
  });
});

describe('Tirs de réaction', () => {
  it("un soldat en surveillance tire sur l'alien qui bouge dans sa vue", () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 } }, { id: 'a', kind: 'nereide', at: { x: 9, y: 5 } }]);
    const e = new TacticalEngine(s);
    e.apply({ type: 'watch', unit: 's' });
    const ev = e.apply({ type: 'endTurn' });
    const reactions = ev.filter((x): x is Extract<GameEvent, { t: 'shot' }> => x.t === 'shot' && x.reaction && x.unit === 's');
    expect(reactions.length).toBeGreaterThanOrEqual(1);
  });
  it("sans UT, pas de réaction", () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 1 }, tu: 0 }, { id: 'a', kind: 'nereide', at: { x: 9, y: 5 } }]);
    const ev: GameEvent[] = [];
    s.side = 'alien';
    runAiTurn(s, 'alien', ev);
    expect(ev.some(x => x.t === 'shot' && x.reaction)).toBe(false);
  });
});

describe('Objectifs, victoire et défaite', () => {
  it("prendre l'artefact déclenche l'alarme ; l'évacuer donne la victoire", () => {
    const e = TacticalEngine.create('obj');
    const s = e.state;
    const u = e.unit('s1')!;
    // téléportation de test à côté de l'artefact
    const art = s.objectives.artifact!;
    u.x = art.x - 1; u.y = art.y;
    const ev = e.apply({ type: 'interact', unit: 's1' });
    expect(ev.some(x => x.t === 'alarm')).toBe(true);
    expect(u.carrying).toBe(true);
    expect(s.alienAlert).toBe(true);
    u.x = s.objectives.evac[0]!.x; u.y = s.objectives.evac[0]!.y;
    e.apply({ type: 'evacuate' });
    expect(s.outcome).toBe('victory');
  });
  it('évacuer sans artefact = retraite (défaite)', () => {
    const e = TacticalEngine.create('retraite');
    e.apply({ type: 'evacuate' });
    expect(e.state.outcome).toBe('defeat');
    expect(e.summary().lost).toBe(0);
  });
  it("le porteur tué lâche l'artefact", () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 2, y: 2 }, carrying: true, hp: 1 }, { id: 'a', kind: 'carapace', at: { x: 3, y: 2 } }]);
    s.side = 'alien';
    const ev: GameEvent[] = [];
    for (let i = 0; i < 5 && s.units[0]!.alive; i++) { s.units[1]!.tu = 48; runAiTurn(s, 'alien', ev); }
    expect(s.units[0]!.alive).toBe(false);
    expect(s.objectives.artifact).toEqual({ x: 2, y: 2 });
    expect(s.outcome).toBe('defeat');
  });
  it('tous les aliens neutralisés = victoire', () => {
    const s = arena(OPEN, [{ id: 's', kind: 'soldier', at: { x: 1, y: 3 } }, { id: 'a', kind: 'spectre', at: { x: 4, y: 3 }, hp: 1 }]);
    const e = new TacticalEngine(s);
    for (let i = 0; i < 4 && s.outcome === 'ongoing'; i++) e.apply({ type: 'shoot', unit: 's', target: 'a', mode: 'snap' });
    expect(s.outcome).toBe('victory');
  });
});

describe('Déterminisme et sauvegarde', () => {
  const play = (e: TacticalEngine, cmds: Command[]) => cmds.forEach(c => e.apply(c));
  const script: Command[] = [
    { type: 'move', unit: 's4', to: { x: 4, y: 3 } }, { type: 'move', unit: 's2', to: { x: 4, y: 5 } },
    { type: 'kneel', unit: 's2' }, { type: 'watch', unit: 's3' }, { type: 'endTurn' },
    { type: 'move', unit: 's1', to: { x: 2, y: 7 } }, { type: 'endTurn' }, { type: 'endTurn' },
  ];
  it('même seed + mêmes commandes = même partie', () => {
    const a = TacticalEngine.create('replay'), b = TacticalEngine.create('replay');
    play(a, script); play(b, script);
    expect(JSON.stringify(a.state)).toBe(JSON.stringify(b.state));
  });
  it('sauvegarder puis reprendre ne change rien à la suite', () => {
    const a = TacticalEngine.create('save');
    play(a, script.slice(0, 5));
    const store = memStore();
    new SaveManager(store).save(a.state);
    const b = new TacticalEngine(new SaveManager(store).load()!);
    play(a, script.slice(5)); play(b, script.slice(5));
    expect(JSON.stringify(b.state)).toBe(JSON.stringify(a.state));
  });
  it('rejette une sauvegarde corrompue ou étrangère', () => {
    expect(deserialize('{oops')).toBeNull();
    expect(deserialize('{"format":"autre","version":1,"state":{}}')).toBeNull();
    expect(deserialize(serialize(createBattle('x')))!.seed).toBe('x');
  });
});

describe('IA et équilibrage (IA contre IA)', () => {
  it('les parties se terminent, et ni camp ne gagne toujours', () => {
    let wins = 0;
    const N = 16;
    for (let i = 0; i < N; i++) {
      const s = createBattle('balance' + i);
      const ev: GameEvent[] = [];
      while (s.outcome === 'ongoing' && s.turn < 40) { runAiTurn(s, 'human', ev); if (s.outcome === 'ongoing') endPlayerTurn(s, ev); }
      expect(s.outcome).not.toBe('ongoing');
      if (s.outcome === 'victory') wins++;
    }
    expect(wins).toBeGreaterThan(N * 0.15);
    expect(wins).toBeLessThan(N * 0.85);
  });
});

describe('mission Némésis', () => {
  it('place 2 soldats dans le sas et 3 aliens fixes, sans tirage', () => {
    const a = createBattle('n1', 'nemesis'), b = createBattle('autre', 'nemesis');
    expect(a.mission).toBe('nemesis');
    expect(a.units.filter(u => u.faction === 'human').map(u => u.name)).toEqual(['Sgt. Walker', 'Okafor']);
    const al = a.units.filter(u => u.faction === 'alien');
    expect(al.map(u => u.kind).sort()).toEqual(['carapace', 'nereide', 'spectre']);
    expect(al.map(u => [u.x, u.y])).toEqual(b.units.filter(u => u.faction === 'alien').map(u => [u.x, u.y]));
    expect(al.find(u => u.kind === 'carapace')!.maxHp).toBe(62);
    expect(a.objectives.artifact).toEqual({ x: 7, y: 1 });
    expect(a.objectives.terminal).toEqual({ x: 13, y: 1 });
  });
  it('se joue jusqu\'au bout en automatique', () => {
    const e = new TacticalEngine(createBattle('auto', 'nemesis'));
    for (let i = 0; i < 40 && e.state.outcome === 'ongoing'; i++) e.apply({ type: 'endTurn' });
    expect(['ongoing', 'defeat', 'victory']).toContain(e.state.outcome);
  });
});
