// SaveManager : sauvegarde locale versionnée (l'état complet est du JSON, RNG comprise).
import type { BattleState } from './types';
import { SAVE_VERSION } from './engine';

export interface KeyValueStore { getItem(k: string): string | null; setItem(k: string, v: string): void; removeItem(k: string): void }

export const SAVE_KEY = 'abyss-protocol.battle';

interface SaveFile { format: 'abyss-protocol'; version: number; savedAt: string; state: BattleState }

// Une entrée par version future : migrations[n] transforme un état v(n) en v(n+1).
const migrations: Record<number, (s: BattleState) => BattleState> = {};

export function serialize(state: BattleState, now = new Date()): string {
  const file: SaveFile = { format: 'abyss-protocol', version: SAVE_VERSION, savedAt: now.toISOString(), state };
  return JSON.stringify(file);
}

/** Renvoie l'état ou null si la sauvegarde est absente, corrompue ou trop ancienne. */
export function deserialize(text: string | null): BattleState | null {
  if (!text) return null;
  try {
    const f = JSON.parse(text) as SaveFile;
    if (f.format !== 'abyss-protocol' || !f.state) return null;
    let s = f.state, v = f.version;
    while (v < SAVE_VERSION) {
      const m = migrations[v];
      if (!m) return null;
      s = m(s); v++;
    }
    return v === SAVE_VERSION ? { ...s, version: v } : null;
  } catch {
    return null;
  }
}

export class SaveManager {
  constructor(private store: KeyValueStore) {}
  save(state: BattleState) { try { this.store.setItem(SAVE_KEY, serialize(state)); } catch { /* stockage plein ou interdit : on joue sans sauvegarde */ } }
  load(): BattleState | null { try { return deserialize(this.store.getItem(SAVE_KEY)); } catch { return null; } }
  clear() { try { this.store.removeItem(SAVE_KEY); } catch { /* idem */ } }
}
