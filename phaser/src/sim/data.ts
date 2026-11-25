// Données de contenu de la phase 1. Toute la balance chiffrée est ici (coûts UT inspirés de l'exemple du GDD §7).

export interface FireModeDef { tu: number; acc: number }
export interface WeaponDef {
  name: string;
  damage: number;
  range: number;
  mag: number; // 0 = pas de munitions (attaques naturelles)
  snap: FireModeDef;
  aimed?: FireModeDef;
  melee?: boolean;
  ignoresCover?: boolean;
  drain?: number; // UT retirées à la cible pour son prochain tour (brouillage)
  sound: 'rifle' | 'pistol' | 'harpoon' | 'alien' | 'acid' | 'psi';
}

export const WEAPONS: Record<string, WeaponDef> = {
  // Arsenal humain : 3 armes
  rifle: { name: 'Fusil à fléchettes', damage: 26, range: 14, mag: 10, snap: { tu: 12, acc: 62 }, aimed: { tu: 24, acc: 108 }, sound: 'rifle' },
  pistol: { name: 'Pistolet à gaz', damage: 20, range: 9, mag: 12, snap: { tu: 9, acc: 70 }, aimed: { tu: 18, acc: 92 }, sound: 'pistol' },
  harpoon: { name: 'Harpon lourd', damage: 44, range: 12, mag: 4, snap: { tu: 16, acc: 50 }, aimed: { tu: 30, acc: 102 }, sound: 'harpoon' },
  // Attaques des trois archétypes aliens (pas de munitions)
  dart: { name: 'Lance-dard', damage: 24, range: 12, mag: 0, snap: { tu: 14, acc: 60 }, aimed: { tu: 26, acc: 98 }, sound: 'alien' },
  acid: { name: 'Jet corrosif', damage: 34, range: 6, mag: 0, snap: { tu: 18, acc: 82 }, sound: 'acid' },
  psi: { name: 'Onde psychique', damage: 15, range: 9, mag: 0, snap: { tu: 20, acc: 85 }, ignoresCover: true, drain: 20, sound: 'psi' },
};

export type Role = 'soldier' | 'flanker' | 'brute' | 'psychic';
export interface UnitTemplate {
  name: string; hp: number; tu: number; accuracy: number; reactions: number; armor: number;
  weapon: string; vision: number; role: Role;
  amphibious?: boolean; // l'eau ne coûte pas d'UT en plus
  hover?: boolean; // passe au-dessus de l'eau et des obstacles bas
}

export const UNIT_TEMPLATES: Record<string, UnitTemplate> = {
  soldier: { name: 'Plongeur', hp: 34, tu: 60, accuracy: 66, reactions: 55, armor: 4, weapon: 'rifle', vision: 12, role: 'soldier' },
  nereide: { name: 'Néréide', hp: 30, tu: 62, accuracy: 62, reactions: 55, armor: 3, weapon: 'dart', vision: 11, role: 'flanker', amphibious: true },
  carapace: { name: 'Carapace', hp: 62, tu: 48, accuracy: 55, reactions: 35, armor: 10, weapon: 'acid', vision: 10, role: 'brute' },
  spectre: { name: 'Spectre', hp: 22, tu: 66, accuracy: 75, reactions: 45, armor: 0, weapon: 'psi', vision: 11, role: 'psychic', hover: true },
};

/** Les 4 soldats de départ (Walker reprend l'exemple de vétéran du GDD). */
export const SQUAD = [
  { id: 's1', name: 'Sgt. Walker', weapon: 'rifle', accuracy: 68, reactions: 58, tu: 60, hp: 36, medkit: 0, grenades: 1 },
  { id: 's2', name: 'Okafor', weapon: 'harpoon', accuracy: 60, reactions: 40, tu: 56, hp: 42, medkit: 0, grenades: 0 },
  { id: 's3', name: 'Lind', weapon: 'rifle', accuracy: 74, reactions: 62, tu: 58, hp: 32, medkit: 0, grenades: 0 },
  { id: 's4', name: 'Moreau', weapon: 'pistol', accuracy: 64, reactions: 70, tu: 66, hp: 32, medkit: 3, grenades: 0 },
] as const;

/** Cartes à 3 aliens fixes (Némésis) : mêmes valeurs que godot/sim/data.gd, plus résistants qu'à 6. */
export const HARDENED: Record<string, { hp: number; tu: number; accuracy: number }> = {
  nereide: { hp: 44, tu: 64, accuracy: 68 },
  carapace: { hp: 90, tu: 52, accuracy: 62 },
  spectre: { hp: 34, tu: 66, accuracy: 80 },
};

export const ALIEN_ROSTER = ['nereide', 'nereide', 'nereide', 'carapace', 'spectre', 'spectre'] as const;

export const RULES = {
  moveOrtho: 6,
  moveDiag: 8,
  waterExtra: 4,
  reloadTu: 8,
  kneelTu: 4,
  kneelAcc: 10,
  watchTu: 18,
  grenadeTu: 18,
  grenadeRange: 10,
  grenadeDamage: 45,
  grenadeFalloff: 12,
  grenadeRadius: 2,
  medkitTu: 12,
  medkitHeal: 14,
  interactTu: 10, // ramasser l'artefact, télécharger le journal
  coverPenalty: [0, 20, 45] as const,
  rangePenaltyFrom: 7, // au-delà, -3 % par case (tir rapide) ou -2 % (tir précis)
  woundPenalty: 5,
  woundThreshold: 12,
  minChance: 5,
  maxChance: 95,
};
