// Projection isométrique 2:1. Une case = losange de TW×TH pixels ; z = hauteur en pixels.
export const TW = 64;
export const TH = 32;
export const WALL_H = 46;
export const LOW_H = 18;

export const toScreen = (x: number, y: number, z = 0) => ({ sx: ((x - y) * TW) / 2, sy: ((x + y) * TH) / 2 - z });

/** Case sous un point écran (coordonnées monde de la caméra). */
export function toTile(px: number, py: number) {
  const a = px / (TW / 2), b = py / (TH / 2);
  return { x: Math.round((a + b) / 2), y: Math.round((b - a) / 2) };
}

/** Ordre d'affichage : les objets plus « bas » à l'écran passent devant. */
export const depthOf = (x: number, y: number, layer = 0) => 1000 + (x + y) * 100 + layer;

/** Direction écran sur 8 orientations (0 = est écran, sens horaire) pour un déplacement en cases. */
export function dir8(dx: number, dy: number): number {
  const sx = dx - dy, sy = (dx + dy) / 2;
  if (!sx && !sy) return 2;
  const a = Math.atan2(sy, sx);
  return (Math.round(a / (Math.PI / 4)) + 8) % 8;
}
