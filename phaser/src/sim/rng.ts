// Générateur pseudo-aléatoire déterministe (mulberry32).
// Son état (un entier 32 bits) vit dans BattleState.rng : sauvegarder l'état suffit à rejouer la suite exacte.

export interface RngHolder { rng: number }

export function seedFrom(text: string | number): number {
  const s = String(text);
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return h >>> 0;
}

/** Nombre dans [0, 1[ ; fait avancer l'état. */
export function next(holder: RngHolder): number {
  let t = (holder.rng = (holder.rng + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

/** Entier dans [0, n[. */
export function int(holder: RngHolder, n: number): number {
  return Math.floor(next(holder) * n);
}

/** Jet de pourcentage : vrai si le tirage 0..99 est sous `chance`. */
export function roll(holder: RngHolder, chance: number): boolean {
  return int(holder, 100) < chance;
}
