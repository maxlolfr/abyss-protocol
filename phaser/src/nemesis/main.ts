// Démo Phaser 4 « salle Némésis » : même simulation et même HUD que le prototype, rendu premium séparé.
// Netteté sur écran Retina : le canvas est dessiné à la définition réelle (jusqu'à ×2) puis réduit en CSS.
import Phaser from 'phaser';
import '../style.css';
import './nemesis.css';
import { SaveManager, TacticalEngine, type KeyValueStore } from '../sim';
import { Hud } from '../game/hud';
import { audio, type Sfx } from '../game/audio';
import { NemesisScene } from './NemesisScene';
import { Samples, type SampleKey } from './sfx';


const params = new URLSearchParams(location.search);
const quality: 'haute' | 'allegee' = params.get('q') === 'allegee' || localStorage.getItem('nemesis.q') === 'allegee' ? 'allegee' : 'haute';
let ratio = quality === 'haute' ? Math.min(window.devicePixelRatio || 1, 2) : 1;

// sauvegarde séparée du prototype
const store: KeyValueStore = {
  getItem: k => localStorage.getItem('nemesis.' + k),
  setItem: (k, v) => localStorage.setItem('nemesis.' + k, v),
  removeItem: k => localStorage.removeItem('nemesis.' + k),
};
const saves = new SaveManager(store);
const sfx = new Samples('nemesis/');

// Les sons d'interface du HUD passent par les vrais sons quand ils sont chargés, sinon par la synthèse.
const synthPlay = audio.play.bind(audio), synthVol = audio.setVolumes.bind(audio);
const UI: Partial<Record<Sfx, SampleKey>> = { confirm: 'confirm', deny: 'deny', turn: 'turn', click: 'click' };
audio.play = (k: Sfx) => { const m = UI[k]; if (!m || !sfx.play(m)) synthPlay(k); };
audio.setVolumes = (f: number, a: number) => { synthVol(f, 0); sfx.setVolumes(f, a); };

const size = () => ({ w: Math.round(window.innerWidth * ratio), h: Math.round(window.innerHeight * ratio) });
const s0 = size();
const game = new Phaser.Game({
  type: Phaser.WEBGL,
  parent: 'game',
  backgroundColor: '#02070b',
  width: s0.w,
  height: s0.h,
  scale: { mode: Phaser.Scale.NONE, zoom: 1 / ratio },
  render: { maxLights: 24, antialias: true, powerPreference: 'high-performance' },
  disableContextMenu: true,
  scene: [],
});
const fit = () => { const s = size(); game.scale.resize(s.w, s.h); game.scale.setZoom(1 / ratio); };
window.addEventListener('resize', fit);
window.addEventListener('orientationchange', () => setTimeout(fit, 250));

const newSeed = () => Date.now().toString(36);
let engine: TacticalEngine;

const hud = new Hud(document.getElementById('ui')!, {
  save: e => saves.save(e.state),
  finished: () => saves.clear(),
  newMission: () => begin(TacticalEngine.create(newSeed(), 'nemesis')),
  sameSeed: () => begin(TacticalEngine.create(engine.state.seed, 'nemesis')),
});

function toast(text: string) {
  const t = document.getElementById('toasts');
  if (!t) return;
  const d = document.createElement('div');
  d.className = 'toast info'; d.textContent = text;
  t.appendChild(d); setTimeout(() => d.remove(), 3500);
}

/** Tutoriel en 4 bulles au premier lancement (passable, mémorisé). */
function tutorial() {
  try { if (localStorage.getItem('nemesis.tuto')) return; } catch { /* stockage indisponible */ }
  const steps = [
    ['Se déplacer', 'Touche une case pour voir le trajet, touche-la encore pour y aller. Chaque action coûte des UT (barre orange).'],
    ['Se mettre à couvert', 'Les boucliers autour de la case : cyan = couvert plein, jaune = demi-couvert. Finis toujours ton tour à couvert.'],
    ['Tirer', 'Touche un alien : le % de chance de toucher s\'affiche. Rapide coûte peu, Précis touche mieux.'],
    ['Finir le tour', 'Quand tes soldats sont placés, « Fin du tour ». Mission : prendre l\'artefact violet et revenir au sas.'],
  ];
  let i = 0;
  const box = document.createElement('div');
  box.className = 'tuto';
  const done = () => { box.remove(); try { localStorage.setItem('nemesis.tuto', '1'); } catch { /* rien */ } };
  const show = () => {
    const [t, d] = steps[i]!;
    box.innerHTML = `<b>${i + 1}/4 · ${t}</b><p>${d}</p><div><button class="skip">Passer</button><button class="next">${i < 3 ? 'Suivant' : 'Jouer'}</button></div>`;
    box.querySelector<HTMLButtonElement>('.skip')!.onclick = done;
    box.querySelector<HTMLButtonElement>('.next')!.onclick = () => { if (++i < steps.length) show(); else done(); };
  };
  show();
  document.body.appendChild(box);
}

function begin(e: TacticalEngine) {
  engine = e;
  const go = () => {
    const existing = game.scene.getScene('nemesis') as NemesisScene | null;
    const scene = existing ?? (game.scene.add('nemesis', NemesisScene, false) as NemesisScene | null);
    if (!scene) { setTimeout(go, 30); return; } // gestionnaire de scènes occupé : on réessaie au tour suivant
    scene.events.once(Phaser.Scenes.Events.CREATE, () => {
      hud.bind(scene, e);
      tutorial();
      window.__abyss = { engine: e, scene, hud };
      scene.onLowFps = () => {
        // baisse automatique : définition ×1, sans flou lumineux
        if (ratio > 1) { ratio = 1; fit(); }
        toast('Qualité allégée automatiquement pour garder la fluidité');
      };
      scene.events.on('contextlost', () => toast('Affichage interrompu : il reprend tout seul'));
    });
    const data = { engine: e, sfx, pixelRatio: ratio, quality };
    if (existing) scene.scene.restart(data); else game.scene.start('nemesis', data);
  };
  if (game.isBooted) go(); else game.events.once(Phaser.Core.Events.READY, go);
}

document.addEventListener('pointerdown', () => { audio.unlock(); sfx.unlock(); }, { once: true });

// portraits des cartes du HUD (styles en ligne : chemins relatifs à la page, valables partout)
const css = document.createElement('style');
css.textContent = ['s1', 's2', 's3', 's4'].map(id => `.card[data-id="${id}"] .face{background-image:url(nemesis/portraits/${id}.webp)}`).join('');
document.head.appendChild(css);

const start = document.getElementById('start')!;
const resume = document.getElementById('btnResume') as HTMLButtonElement;
const saved = saves.load();
if (saved && saved.outcome === 'ongoing' && saved.mission === 'nemesis') resume.hidden = false;
const qBtn = document.getElementById('btnQuality') as HTMLButtonElement;
qBtn.textContent = quality === 'haute' ? 'Qualité : haute' : 'Qualité : allégée';
qBtn.addEventListener('click', () => {
  localStorage.setItem('nemesis.q', quality === 'haute' ? 'allegee' : 'haute');
  location.reload();
});
const launch = (e: TacticalEngine) => {
  audio.unlock(); sfx.unlock();
  start.hidden = true;
  begin(e);
  sfx.play('v_start', { delay: 1.2 });
};
document.getElementById('btnStart')!.addEventListener('click', () => launch(TacticalEngine.create(params.get('seed') ?? newSeed(), 'nemesis')));
resume.addEventListener('click', () => { if (saved) launch(new TacticalEngine(saved)); });
if (params.has('auto')) launch(TacticalEngine.create(params.get('seed') ?? 'demo', 'nemesis')); // captures automatiques
