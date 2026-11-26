// Types partagés par toute la simulation. Aucun import de rendu ici : l'état est du JSON pur, sérialisable tel quel.

export interface Vec { x: number; y: number }
export type Faction = 'human' | 'alien';
export type Tile = 'floor' | 'wall' | 'low' | 'water';
export type FireMode = 'snap' | 'aimed';
export type CoverLevel = 0 | 1 | 2; // aucune, partielle, totale

export interface Unit {
  id: string;
  name: string;
  faction: Faction;
  kind: string; // clé de UNIT_TEMPLATES
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  tu: number;
  maxTu: number;
  accuracy: number;
  reactions: number;
  armor: number;
  weapon: string; // clé de WEAPONS
  ammo: number;
  wounds: number; // -1 PV par blessure au début du tour de son camp
  drain: number; // UT perdues au début du prochain tour (brouillage psychique)
  kneeling: boolean;
  watching: boolean; // surveillance : gagne le test de réaction, premier tir de réaction gratuit
  alive: boolean;
  evacuated: boolean;
  grenades: number;
  medkit: number;
  carrying: boolean; // porte l'artefact
  kills: number;
  downed?: number; // à terre (Némésis) : tours restants avant de succomber, relevable avec un kit médical
}

export interface Objectives {
  /** Principal : récupérer l'artefact et l'évacuer par le sas (ou neutraliser tous les hostiles). */
  artifact: Vec | null; // position au sol ; null si porté
  /** Secondaire : télécharger le journal du terminal. */
  terminal: Vec;
  logsDone: boolean;
  evac: Vec[]; // cases du sas
}

export type Outcome = 'ongoing' | 'victory' | 'defeat';

export type Command =
  | { type: 'move'; unit: string; to: Vec }
  | { type: 'shoot'; unit: string; target: string; mode: FireMode }
  | { type: 'throw'; unit: string; to: Vec }
  | { type: 'heal'; unit: string; target: string }
  | { type: 'reload'; unit: string }
  | { type: 'kneel'; unit: string }
  | { type: 'watch'; unit: string }
  | { type: 'interact'; unit: string }
  | { type: 'evacuate' }
  | { type: 'endTurn' };

export interface BattleState {
  version: number;
  seed: string;
  /** Clé de MAPS (absent dans les anciennes sauvegardes = 'lab'). */
  mission?: string;
  rng: number;
  turn: number;
  side: Faction;
  width: number;
  height: number;
  tiles: Tile[];
  explored: boolean[]; // brouillard de guerre côté joueur
  units: Unit[];
  objectives: Objectives;
  outcome: Outcome;
  alienAlert: boolean;
  lastKnown: Record<string, Vec>; // dernières positions de soldats connues des aliens
  commands: Command[]; // journal rejouable avec la même seed
}

export type GameEvent =
  | { t: 'move'; unit: string; from: Vec; to: Vec; seen: boolean }
  | { t: 'interrupt'; unit: string }
  | { t: 'spotted'; unit: string }
  | {
      t: 'shot'; unit: string; from: Vec; to: Vec; target: string; weapon: string; mode: FireMode;
      chance: number; hit: boolean; reaction: boolean; seen: boolean;
    }
  | { t: 'damage'; unit: string; amount: number; hp: number; wounded: boolean; drained: number }
  | { t: 'death'; unit: string }
  | { t: 'explosion'; at: Vec; radius: number }
  | { t: 'destroy'; at: Vec }
  | { t: 'downed'; unit: string; turns: number }
  | { t: 'revive'; unit: string }
  | { t: 'heal'; unit: string; target: string; amount: number }
  | { t: 'reload'; unit: string }
  | { t: 'kneel'; unit: string }
  | { t: 'watch'; unit: string }
  | { t: 'pickup'; unit: string }
  | { t: 'logs'; unit: string }
  | { t: 'drop'; at: Vec }
  | { t: 'alarm' }
  | { t: 'bleed'; unit: string; amount: number; hp: number }
  | { t: 'turn'; side: Faction; turn: number }
  | { t: 'evacuate'; units: string[] }
  | { t: 'outcome'; outcome: Outcome };
