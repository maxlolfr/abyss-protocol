// Contrat entre le HUD et une scène de combat : le HUD ne connaît que cette interface,
// ce qui permet plusieurs rendus (prototype BattleScene, démo premium NemesisScene) sur la même simulation.
import type Phaser from 'phaser';
import type { GameEvent, MovePreview, Unit, Vec } from '../sim';

export type Tone = 'info' | 'warn' | 'good';

export interface TacticalView {
  onTap: (p: Vec) => void;
  speed: number;
  reduceFx: boolean;
  readonly fps: number;
  /** Pixels du canvas par pixel CSS (canvas Retina réduit en CSS) ; absent = 1. */
  readonly pixelRatio?: number;
  readonly cameras: Phaser.Cameras.Scene2D.CameraManager;
  select(id: string | null): void;
  showReach(u: Unit | null): void;
  showMovePreview(u: Unit, p: MovePreview | null): void;
  showShot(from: Vec, to: Vec, chance: number): void;
  showBlast(at: Vec | null, ok: boolean): void;
  clearPreview(): void;
  centerOn(p: Vec, ms?: number): void;
  /** Point monde (avant caméra) du centre de la case. */
  worldOf(p: Vec): { sx: number; sy: number };
  play(events: GameEvent[], banner: (text: string, tone?: Tone) => void): Promise<void>;
}
