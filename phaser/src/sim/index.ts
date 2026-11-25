// Façade publique de la simulation (aucune dépendance au rendu).
export * from './types';
export * from './data';
export { TacticalEngine, createBattle, SAVE_VERSION } from './engine';
export type { MovePreview, ShotPreview } from './engine';
export { SaveManager, serialize, deserialize, SAVE_KEY } from './save';
export { coverAround, coverAgainst } from './cover';
export { visibleTiles, canSee } from './los';
export { idx, inEvac, tileAt } from './map';
export { evacSplit, interactTarget } from './actions';
