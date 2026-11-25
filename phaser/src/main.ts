// Point d'entrée : jeu Phaser, écran de départ, sauvegarde automatique, cycle des missions.
import Phaser from 'phaser';
import './style.css';
import { SaveManager, TacticalEngine } from './sim';
import { BattleScene } from './game/BattleScene';
import { Hud } from './game/hud';
import { audio } from './game/audio';

declare global { interface Window { __abyss?: { engine: TacticalEngine; scene: BattleScene | null; hud: Hud } } }

const saves = new SaveManager(localStorage);
const game = new Phaser.Game({
  type: Phaser.WEBGL,
  parent: 'game',
  backgroundColor: '#03080d',
  scale: { mode: Phaser.Scale.RESIZE, width: '100%', height: '100%' },
  render: { maxLights: 16 },
  disableContextMenu: true,
  scene: [],
});

const newSeed = () => Date.now().toString(36);
let engine: TacticalEngine;

const hud = new Hud(document.getElementById('ui')!, {
  save: e => saves.save(e.state),
  finished: () => saves.clear(),
  newMission: () => begin(TacticalEngine.create(newSeed())),
  sameSeed: () => begin(TacticalEngine.create(engine.state.seed)),
});

/** Lance (ou relance) la scène de combat sur ce moteur, puis branche le HUD quand elle est prête. */
function begin(e: TacticalEngine) {
  engine = e;
  const go = () => {
    const sc = game.scene.getScene('battle') as BattleScene | null;
    const fresh = !sc;
    const scene = sc ?? (game.scene.add('battle', BattleScene, false) as BattleScene);
    scene.events.once(Phaser.Scenes.Events.CREATE, () => {
      hud.bind(scene, e);
      window.__abyss = { engine: e, scene, hud };
    });
    if (fresh) game.scene.start('battle', { engine: e });
    else scene.scene.restart({ engine: e });
  };
  if (game.isBooted) go(); else game.events.once(Phaser.Core.Events.READY, go);
}

// Le premier toucher débloque l'audio (iOS).
document.addEventListener('pointerdown', () => audio.unlock(), { once: true });

const start = document.getElementById('start')!;
const resume = document.getElementById('btnResume') as HTMLButtonElement;
const saved = saves.load();
if (saved && saved.outcome === 'ongoing') resume.hidden = false;
const launch = (e: TacticalEngine) => {
  audio.unlock();
  start.hidden = true;
  begin(e);
};
document.getElementById('btnStart')!.addEventListener('click', () => launch(TacticalEngine.create(new URLSearchParams(location.search).get('seed') ?? newSeed())));
resume.addEventListener('click', () => { if (saved) launch(new TacticalEngine(saved)); });
