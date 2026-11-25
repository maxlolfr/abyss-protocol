// TurnManager : alternance joueur / aliens, recharge des UT, saignements.
import type { BattleState, Faction, GameEvent } from './types';
import { living } from './map';
import { kill } from './combat';
import { checkOutcome } from './actions';
import { runAiTurn } from './ai';

/** Début du tour d'un camp : UT rechargées (moins le brouillage), fin de surveillance, saignements. */
export function startSide(s: BattleState, side: Faction, ev: GameEvent[]): void {
  s.side = side;
  ev.push({ t: 'turn', side, turn: s.turn });
  for (const u of living(s).filter(u => u.faction === side)) {
    u.tu = Math.max(0, u.maxTu - u.drain);
    u.drain = 0;
    u.watching = false;
    if (u.wounds > 0) {
      u.hp -= u.wounds;
      ev.push({ t: 'bleed', unit: u.id, amount: u.wounds, hp: Math.max(0, u.hp) });
      if (u.hp <= 0) kill(s, u, ev);
    }
  }
  checkOutcome(s, ev);
}

/** Fin du tour du joueur : les aliens jouent, puis un nouveau tour commence. */
export function endPlayerTurn(s: BattleState, ev: GameEvent[]): void {
  startSide(s, 'alien', ev);
  if (s.outcome === 'ongoing') runAiTurn(s, 'alien', ev);
  if (s.outcome !== 'ongoing') return;
  s.turn++;
  startSide(s, 'human', ev);
}
