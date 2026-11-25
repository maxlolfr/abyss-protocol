// Interface DOM permanente + contrôleur tactile. Aucune fenêtre modale hormis le récapitulatif final.
// Le HUD n'écrit jamais dans l'état : il prévisualise, puis envoie une Command au moteur et fait rejouer les événements.
import type { BattleScene } from './BattleScene';
import { RULES, WEAPONS, type Command, type FireMode, type TacticalEngine, type Unit, type Vec } from '../sim';
import { audio } from './audio';

type Tone = 'info' | 'warn' | 'good';
type Armed = 'snap' | 'aimed' | 'grenade' | 'heal' | null;
type Act = 'snap' | 'aimed' | 'grenade' | 'heal' | 'reload' | 'kneel' | 'watch' | 'interact' | 'evac' | 'end';

interface Pending { cmd: Command; key: string; kind: string; target?: string; chips: string[]; warns: string[] }
interface Status { ok: boolean; label: string; sub: string; reason: string }

export interface HudHooks {
  save(e: TacticalEngine): void; // appelé après chaque commande validée
  finished(e: TacticalEngine): void; // mission terminée : effacer la sauvegarde
  newMission(): void;
  sameSeed(): void;
}

const COVER = ['aucune', 'partielle', 'totale'];
const LABELS: Record<Act, string> = { snap: 'Tir rapide', aimed: 'Tir précis', grenade: 'Grenade', heal: 'Soin', reload: 'Recharger', kneel: 'À genoux', watch: 'Surveillance', interact: 'Interagir', evac: 'Évacuer', end: 'Fin du tour' };
const cheb = (a: Vec, b: Vec) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
const plural = (n: number, one: string, many: string) => `${n} ${n > 1 ? many : one}`;
const sleep = (ms: number) => new Promise<void>(r => setTimeout(r, ms));

const SKELETON = `
<div class="hud" id="hud">
  <div id="obj" class="panel"></div>
  <div class="top-right">
    <div class="speed" id="speed" aria-label="Vitesse du tour alien">
      <button data-s="1" class="on">×1</button><button data-s="2">×2</button><button data-s="4">×4</button><button data-s="99">Passer</button>
    </div>
    <button id="menuBtn" aria-label="Menu">☰</button>
  </div>
  <div id="cards"></div>
  <div id="toasts"></div>
  <div id="preview" class="panel empty"></div>
  <div class="actions" id="actions"></div>
</div>
<div id="fps" hidden></div>
<aside class="menu" id="menu" aria-label="Options">
  <h3>OPTIONS <button id="menuClose" aria-label="Fermer">✕</button></h3>
  <label>Réduire les effets <input type="checkbox" id="optFx"></label>
  <label>Volume effets <input type="range" id="optVol" min="0" max="100" value="80"></label>
  <label>Volume ambiance <input type="range" id="optAmb" min="0" max="100" value="50"></label>
  <label>Afficher les i/s <input type="checkbox" id="optFps"></label>
  <button id="btnNew">Nouvelle mission</button>
  <button id="btnSame">Recommencer cette seed</button>
  <div class="seed" id="seedInfo"></div>
</aside>
<div id="summary" hidden></div>`;

export class Hud {
  private scene!: BattleScene;
  private engine!: TacticalEngine;
  private selected = '';
  private pending: Pending | null = null;
  private armed: Armed = null;
  private locked = false;
  private speed = 1;
  private reduceFx = false;
  private fpsTimer = 0;
  private el: Record<string, HTMLElement> = {};

  constructor(root: HTMLElement, private hooks: HudHooks) {
    root.innerHTML = SKELETON;
    for (const id of ['hud', 'obj', 'cards', 'toasts', 'preview', 'actions', 'speed', 'menu', 'summary', 'fps', 'seedInfo']) this.el[id] = document.getElementById(id)!;
    const on = (id: string, ev: string, fn: (e: Event) => void) => document.getElementById(id)!.addEventListener(ev, fn);
    this.el.cards!.addEventListener('click', e => {
      const id = (e.target as HTMLElement).closest<HTMLElement>('[data-id]')?.dataset.id;
      if (id && !this.locked) this.pick(id);
    });
    this.el.actions!.addEventListener('click', e => {
      const act = (e.target as HTMLElement).closest<HTMLElement>('[data-act]')?.dataset.act as Act | undefined;
      if (act && !this.locked) this.press(act);
    });
    this.el.preview!.addEventListener('click', e => {
      const b = (e.target as HTMLElement).closest<HTMLElement>('[data-do]')?.dataset.do;
      if (b === 'ok') void this.confirm(); else if (b === 'no') this.cancel();
    });
    this.el.speed!.addEventListener('click', e => {
      const s = Number((e.target as HTMLElement).closest<HTMLElement>('[data-s]')?.dataset.s);
      if (!s) return;
      this.speed = s; this.scene.speed = s;
      this.el.speed!.querySelectorAll('button').forEach(b => b.classList.toggle('on', Number(b.dataset.s) === s));
    });
    on('menuBtn', 'click', () => this.el.menu!.classList.toggle('open'));
    on('menuClose', 'click', () => this.el.menu!.classList.remove('open'));
    on('optFx', 'change', e => { this.reduceFx = (e.target as HTMLInputElement).checked; this.scene.reduceFx = this.reduceFx; });
    const vols = () => audio.setVolumes(Number((document.getElementById('optVol') as HTMLInputElement).value) / 100, Number((document.getElementById('optAmb') as HTMLInputElement).value) / 100);
    on('optVol', 'input', vols); on('optAmb', 'input', vols);
    on('optFps', 'change', e => this.showFps((e.target as HTMLInputElement).checked));
    // actions destructrices du menu : deux touchers (pas de modale)
    this.twoTap('btnNew', 'Toucher pour confirmer', () => hooks.newMission());
    this.twoTap('btnSame', 'Toucher pour confirmer', () => hooks.sameSeed());
  }

  private twoTap(id: string, armedText: string, fn: () => void) {
    const b = document.getElementById(id)!, text = b.textContent!;
    let t = 0;
    b.addEventListener('click', () => {
      if (b.textContent === armedText) { clearTimeout(t); b.textContent = text; this.el.menu!.classList.remove('open'); fn(); return; }
      b.textContent = armedText; b.classList.add('danger');
      t = window.setTimeout(() => { b.textContent = text; b.classList.remove('danger'); }, 3000);
    });
  }

  private showFps(on: boolean) {
    this.el.fps!.hidden = !on;
    clearInterval(this.fpsTimer);
    if (on) this.fpsTimer = window.setInterval(() => { this.el.fps!.textContent = `${this.scene.fps} i/s`; }, 500);
  }

  /** Branche le HUD sur une (nouvelle) bataille. */
  bind(scene: BattleScene, engine: TacticalEngine) {
    this.scene = scene; this.engine = engine;
    this.locked = false; this.pending = null; this.armed = null;
    scene.onTap = p => this.tap(p);
    scene.speed = this.speed; scene.reduceFx = this.reduceFx;
    this.el.summary!.hidden = true;
    this.el.toasts!.innerHTML = '';
    this.el.seedInfo!.textContent = `Seed : ${engine.state.seed}`;
    const first = this.alive()[0];
    this.selected = first?.id ?? '';
    scene.select(this.selected || null);
    if (first) scene.showReach(first);
    this.render();
  }

  // ---------- état dérivé ----------

  private alive() { return this.engine.soldiers.filter(u => u.alive && !u.evacuated); }
  private sel(): Unit | undefined { return this.alive().find(u => u.id === this.selected); }

  toast(text: string, tone: Tone = 'info') {
    const box = this.el.toasts!;
    const d = document.createElement('div');
    d.className = `toast ${tone}`; d.textContent = text;
    box.appendChild(d);
    while (box.children.length > 3) box.firstElementChild!.remove();
    setTimeout(() => d.classList.add('out'), 2400);
    setTimeout(() => d.remove(), 2800);
  }

  // ---------- sélection, aperçus ----------

  private pick(id: string, center = true) {
    this.selected = id;
    this.cancel(false);
    this.scene.select(id);
    const u = this.sel();
    if (u) { this.scene.showReach(u); if (center) this.scene.centerOn(u); }
    audio.play('click');
    this.render();
  }

  /** Annule l'aperçu et le mode de visée, sans aucun coût. */
  private cancel(redraw = true) {
    this.pending = null; this.armed = null;
    this.scene.clearPreview();
    const u = this.sel();
    if (u) this.scene.showReach(u);
    if (redraw) this.render();
  }

  private setPending(p: Pending) {
    this.pending = p;
    this.render();
  }

  private tap(p: Vec) {
    if (this.locked || this.engine.state.outcome !== 'ongoing') return;
    const e = this.engine, u = this.sel();
    const visible = e.visibleAliens();
    const alien = visible.find(a => a.x === p.x && a.y === p.y);
    const friend = this.alive().find(a => a.x === p.x && a.y === p.y);
    if (friend) {
      if (this.armed === 'heal' && u) return this.healPreview(u, friend);
      if (friend.id !== this.selected) return this.pick(friend.id);
      return this.cancel();
    }
    if (!u) return;
    if (alien) {
      const forced = this.armed === 'snap' || this.armed === 'aimed' ? this.armed : undefined;
      return this.shotPreview(u, alien, forced);
    }
    if (this.armed === 'grenade') return this.throwPreview(u, p);
    if (this.armed) return this.cancel(); // toucher ailleurs : annule sans coût
    this.movePreview(u, p);
  }

  private movePreview(u: Unit, p: Vec) {
    const pv = this.engine.previewMove(u, p);
    if (!pv) { this.cancel(); return; } // hors de portée : annule
    const key = `move:${p.x},${p.y}`;
    if (this.pending?.key === key) { void this.confirm(); return; }
    const warns = pv.reactors ? [`⚠ ${plural(pv.reactors, 'tir', 'tirs')} de réaction possible${pv.reactors > 1 ? 's' : ''}`] : [];
    this.armed = null;
    this.scene.clearPreview();
    this.scene.showMovePreview(u, pv);
    this.setPending({ cmd: { type: 'move', unit: u.id, to: p }, key, kind: 'move', warns,
      chips: ['Déplacement', `${pv.cost} UT → reste ${pv.tuAfter}`, `couverture ${COVER[pv.cover]}`, `trajet ${plural(pv.path.length, 'case', 'cases')}`] });
  }

  private shotPreview(u: Unit, t: Unit, forced?: FireMode) {
    const w = WEAPONS[u.weapon]!;
    const modes: FireMode[] = forced ? [forced] : w.aimed ? ['aimed', 'snap'] : ['snap'];
    let mode = modes[0]!, pv = this.engine.previewShot(u, t, mode);
    for (const m of modes) { mode = m; pv = this.engine.previewShot(u, t, m); if (!pv.error) break; }
    if (pv.error) { this.toast(pv.error, 'warn'); audio.play('deny'); this.cancel(); return; }
    const key = `shoot:${t.id}:${mode}`;
    if (this.pending?.key === key) { void this.confirm(); return; }
    this.armed = forced ?? null;
    this.scene.clearPreview();
    this.scene.showShot(pv.from, pv.to, pv.chance);
    this.setPending({ cmd: { type: 'shoot', unit: u.id, target: t.id, mode }, key, kind: 'shoot', target: t.id, warns: [],
      chips: [mode === 'aimed' ? 'Tir précis' : 'Tir rapide', `${pv.cost} UT → reste ${pv.tuAfter}`, `${pv.chance} % de toucher`, `couverture ${COVER[pv.cover]}`, `trajectoire vers ${t.name}`] });
  }

  private throwPreview(u: Unit, p: Vec) {
    const err = this.engine.canThrow(u, p);
    if (err) { this.toast(err, 'warn'); audio.play('deny'); this.cancel(); return; }
    const key = `throw:${p.x},${p.y}`;
    if (this.pending?.key === key) { void this.confirm(); return; }
    const r = RULES.grenadeRadius;
    const foes = this.engine.visibleAliens().filter(a => cheb(a, p) <= r).length;
    const friends = this.alive().filter(a => cheb(a, p) <= r).length;
    this.scene.clearPreview();
    this.scene.showBlast(p, true);
    this.setPending({ cmd: { type: 'throw', unit: u.id, to: p }, key, kind: 'throw', warns: friends ? [`⚠ ${plural(friends, 'allié', 'alliés')} dans le rayon`] : [],
      chips: ['Grenade', `${RULES.grenadeTu} UT → reste ${u.tu - RULES.grenadeTu}`, `rayon ${r}`, `${plural(foes, 'hostile', 'hostiles')} en vue dans le rayon`] });
  }

  private healPreview(u: Unit, t: Unit) {
    const err = this.engine.canHeal(u, t);
    if (err) { this.toast(err, 'warn'); audio.play('deny'); this.cancel(); return; }
    const key = `heal:${t.id}`;
    if (this.pending?.key === key) { void this.confirm(); return; }
    this.scene.clearPreview();
    this.setPending({ cmd: { type: 'heal', unit: u.id, target: t.id }, key, kind: 'heal', warns: [],
      chips: ['Soin', t.id === u.id ? 'sur soi-même' : t.name, `${RULES.medkitTu} UT → reste ${u.tu - RULES.medkitTu}`, `+${Math.min(RULES.medkitHeal, t.maxHp - t.hp)} PV`] });
  }

  // ---------- boutons d'action ----------

  private status(a: Act, u: Unit | undefined): Status {
    const e = this.engine;
    const no = (sub: string, reason: string, label: string): Status => ({ ok: false, label, sub, reason });
    const yes = (cost: number, label: string): Status => ({ ok: true, label, sub: `${cost} UT`, reason: '' });
    if (a === 'end') return { ok: true, label: 'Fin du tour', sub: 'Tour alien', reason: '' };
    if (a === 'evac') {
      const n = e.evacSplit().staying.length;
      return { ok: true, label: n ? `Évacuer (${n === 1 ? '1 reste' : `${n} restent`} sur place)` : 'Évacuer (tous)', sub: '0 UT', reason: '' };
    }
    if (!u) return no('—', 'Aucun soldat sélectionné', LABELS[a]);
    const w = WEAPONS[u.weapon]!;
    const ut = (c: number) => (u.tu < c ? no('UT insuff.', `UT insuffisantes (${c} requises, ${u.tu} restantes)`, '') : null);
    let label = '', cost = 0, bad: Status | null = null;
    switch (a) {
      case 'snap': case 'aimed': {
        label = a === 'snap' ? 'Tir rapide' : 'Tir précis';
        const d = a === 'snap' ? w.snap : w.aimed;
        if (!d) return no('Indisponible', 'Mode indisponible pour cette arme', label);
        cost = d.tu;
        if (w.mag > 0 && u.ammo <= 0) return no('Vide', 'Chargeur vide : recharger', label);
        bad = ut(cost);
        if (!bad) {
          const vis = e.visibleAliens();
          if (!vis.length) return no('Pas de cible', 'Aucun alien en vue', label);
          const errs = vis.map(t => e.previewShot(u, t, a).error);
          if (errs.every(x => x)) return no('Hors portée', errs[0]!, label);
        }
        break;
      }
      case 'grenade':
        label = `Grenade ×${u.grenades}`; cost = RULES.grenadeTu;
        if (u.grenades <= 0) return no('Aucune', 'Plus de grenade', label);
        bad = ut(cost);
        break;
      case 'heal':
        label = `Soin ×${u.medkit}`; cost = RULES.medkitTu;
        if (u.medkit <= 0) return no('Vide', 'Kit médical vide', label);
        bad = ut(cost);
        if (!bad && !this.alive().some(t => !e.canHeal(u, t))) return no('Aucun blessé', 'Aucun blessé au contact (toi compris)', label);
        break;
      case 'reload': {
        label = 'Recharger'; cost = RULES.reloadTu;
        const err = e.canReload(u);
        if (err === 'Chargeur plein') return no('Plein', err, label);
        bad = ut(cost);
        break;
      }
      case 'kneel':
        label = 'À genoux'; cost = RULES.kneelTu;
        if (u.kneeling) return no('Déjà', 'Déjà à genoux', label);
        bad = ut(cost);
        break;
      case 'watch':
        label = 'Surveillance'; cost = RULES.watchTu;
        if (u.watching) return no('Active', 'Surveillance déjà active', label);
        bad = ut(cost);
        break;
      case 'interact': {
        const t = e.interactTarget(u);
        label = t === 'artifact' ? "Prendre l'artefact" : t === 'terminal' ? 'Télécharger le journal' : 'Interagir'; cost = RULES.interactTu;
        if (!t) return no('Rien ici', "Rien à proximité : approche l'artefact ou le terminal", label);
        bad = ut(cost);
        break;
      }
    }
    if (bad) return { ...bad, label };
    return yes(cost, label);
  }

  private press(a: Act) {
    const e = this.engine, u = this.sel();
    const st = this.status(a, u);
    if (!st.ok) { this.toast(st.reason, 'warn'); audio.play('deny'); return; }
    if (this.armed === a && !this.pending) return this.cancel(); // re-toucher le mode armé le désarme
    if (a === 'end') return this.preparePlain('end', { type: 'endTurn' }, ['Fin du tour', `UT inutilisées : ${this.alive().reduce((n, x) => n + x.tu, 0)}`], []);
    if (a === 'evac') {
      const { leaving, staying } = e.evacSplit();
      const warns = [];
      if (staying.length) warns.push(`⚠ ${plural(staying.length, 'soldat reste', 'soldats restent')} sur place (perdus)`);
      if (!leaving.some(x => x.carrying)) warns.push('⚠ sans artefact : retraite, mission échouée');
      return this.preparePlain('evac', { type: 'evacuate' }, ['Évacuation', plural(leaving.length, 'soldat part', 'soldats partent'), leaving.some(x => x.carrying) ? 'artefact emporté' : 'sans artefact'], warns);
    }
    if (!u) return;
    const after = (c: number) => `${c} UT → reste ${u.tu - c}`;
    switch (a) {
      case 'reload': return this.preparePlain(a, { type: 'reload', unit: u.id }, ['Recharger', after(RULES.reloadTu), `chargeur ${WEAPONS[u.weapon]!.mag}/${WEAPONS[u.weapon]!.mag}`], []);
      case 'kneel': return this.preparePlain(a, { type: 'kneel', unit: u.id }, ['À genoux', after(RULES.kneelTu), `+${RULES.kneelAcc} % de précision, meilleur couvert`], []);
      case 'watch': return this.preparePlain(a, { type: 'watch', unit: u.id }, ['Surveillance', after(RULES.watchTu), 'réaction garantie, premier tir gratuit'], []);
      case 'interact': {
        const t = e.interactTarget(u);
        return this.preparePlain(a, { type: 'interact', unit: u.id }, [st.label, after(RULES.interactTu)], t === 'artifact' ? ['⚠ Les hostiles seront alertés'] : []);
      }
      case 'snap': case 'aimed': {
        if (this.pending?.kind === 'shoot') {
          const t = e.unit(this.pending.target!)!;
          if (this.pending.key === `shoot:${t.id}:${a}`) return void this.confirm();
          return this.shotPreview(u, t, a);
        }
        this.cancel(false); this.armed = a;
        const ts = e.visibleAliens().filter(t => !e.previewShot(u, t, a).error);
        if (ts.length === 1) return this.shotPreview(u, ts[0]!, a);
        this.scene.centerOn(u, 200);
        return this.render();
      }
      case 'grenade':
        if (this.pending?.kind === 'throw') return void this.confirm();
        this.cancel(false); this.armed = 'grenade'; return this.render();
      case 'heal': {
        if (this.pending?.kind === 'heal') return void this.confirm();
        this.cancel(false); this.armed = 'heal';
        const c = this.alive().filter(t => !e.canHeal(u, t));
        if (c.length === 1) return this.healPreview(u, c[0]!);
        return this.render();
      }
    }
  }

  private preparePlain(key: string, cmd: Command, chips: string[], warns: string[]) {
    if (this.pending?.key === key) { void this.confirm(); return; }
    this.cancel(false);
    this.setPending({ cmd, key, kind: key, chips, warns });
  }

  private async confirm() {
    const p = this.pending;
    if (!p || this.locked) return;
    audio.play('confirm');
    await this.run(p.cmd);
  }

  private async run(cmd: Command) {
    const e = this.engine;
    this.locked = true;
    this.pending = null; this.armed = null;
    this.scene.clearPreview();
    this.render();
    const ev = e.apply(cmd);
    if (!ev.length) {
      this.toast('Action refusée', 'warn');
      this.locked = false; this.cancel();
      return;
    }
    this.hooks.save(e);
    try {
      await this.scene.play(ev, (t, tone) => this.toast(t, tone));
    } finally {
      this.locked = false;
    }
    if (e.state.outcome !== 'ongoing') {
      this.hooks.finished(e);
      this.render();
      if (this.scene.speed < 99) await sleep(900);
      this.showSummary();
      return;
    }
    const cur = this.sel();
    if (cmd.type === 'endTurn' || !cur) {
      const next = this.alive()[0];
      this.selected = next?.id ?? '';
      this.scene.select(this.selected || null);
      if (next) this.scene.centerOn(next);
    }
    this.cancel(false);
    this.render();
  }

  // ---------- rendu DOM ----------

  private render() {
    const e = this.engine, s = e.state, u = this.sel();
    this.el.hud!.classList.toggle('locked', this.locked);

    const carrier = e.soldiers.find(x => x.carrying && x.alive && !x.evacuated);
    const art = carrier ? `<span>◆ Artefact : évacuer par le sas (porté par ${carrier.name})</span>` : s.objectives.artifact ? '<span>◆ Artefact : récupérer puis évacuer par le sas</span>' : '<span class="done">◆ Artefact : évacué ou neutralisé</span>';
    const logs = s.objectives.logsDone ? '<span class="done">◇ Journal du terminal : téléchargé ✓</span>' : '<span class="mut">◇ Journal du terminal</span>';
    this.el.obj!.innerHTML = `<div><span class="turn">Tour ${s.turn}</span>${s.alienAlert ? '<span class="alert">⚠ hostiles en alerte</span>' : ''}</div><div>${art}</div><div>${logs}</div>`;

    this.el.cards!.innerHTML = e.soldiers.map(x => {
      const w = WEAPONS[x.weapon]!;
      const out = !x.alive || x.evacuated;
      const icons = out ? (x.evacuated ? 'évacué' : 'perdu') :
        (x.kneeling ? '<span title="À genoux">▼</span>' : '') + (x.watching ? '<span title="Surveillance">◉</span>' : '') + (x.carrying ? '<span title="Porte l\'artefact">◆</span>' : '') + (x.wounds ? '<span title="Blessure">✚</span>' : '');
      const ammo = w.mag ? `<span class="ammo${x.ammo <= 1 ? ' low' : ''}" title="Munitions">▮${x.ammo}</span>` : '';
      return `<button class="card${x.id === this.selected ? ' sel' : ''}${out ? ' out' : ''}" data-id="${x.id}" ${out ? 'disabled' : ''}>
        <div class="c1"><span>${x.name}</span><span class="ico">${icons}</span></div>
        <div class="c2"><div class="bar hp${x.hp <= x.maxHp * 0.35 ? ' low' : ''}"><i style="width:${(100 * x.hp) / x.maxHp}%"></i><span>${x.hp}/${x.maxHp}</span></div>
        <div class="bar tu"><i style="width:${(100 * x.tu) / x.maxTu}%"></i><span>${x.tu}/${x.maxTu}</span></div>${ammo}</div></button>`;
    }).join('');

    const order: Act[] = ['snap', 'aimed', 'grenade', 'heal', 'reload', 'kneel', 'watch', 'interact'];
    if (e.evacSplit().leaving.length) order.push('evac');
    order.push('end');
    this.el.actions!.innerHTML = order.map(a => {
      const st = this.status(a, u);
      const cls = `act${st.ok ? '' : ' off'}${this.armed === a || this.pending?.key === a ? ' armed' : ''}${a === 'evac' ? ' evac' : ''}${a === 'end' ? ' end' : ''}`;
      return `<button class="${cls}" data-act="${a}" aria-disabled="${!st.ok}" title="${st.ok ? '' : st.reason}"><span>${st.label}</span><small>${st.sub}</small></button>`;
    }).join('');

    const pv = this.el.preview!, p = this.pending;
    pv.classList.toggle('empty', !p && !this.armed);
    if (p) {
      pv.innerHTML = p.chips.map((c, i) => `<span class="chip${i === 0 ? ' k' : ''}">${c}</span>`).join('') + p.warns.map(w => `<span class="chip w">${w}</span>`).join('') +
        '<span class="grow"></span><button class="primary" data-do="ok">Confirmer</button><button data-do="no" aria-label="Annuler">✕</button>';
    } else if (this.armed) {
      const hint = { snap: 'Tir rapide : touche un alien visible', aimed: 'Tir précis : touche un alien visible', grenade: `Grenade : touche la case visée (portée ${RULES.grenadeRange}, rayon ${RULES.grenadeRadius})`, heal: 'Soin : touche un allié au contact (ou toi-même)' }[this.armed];
      pv.innerHTML = `<span class="chip k">${hint}</span><span class="grow"></span><button data-do="no" aria-label="Annuler">✕</button>`;
    }
  }

  private showSummary() {
    const m = this.engine.summary();
    const retreat = m.outcome === 'defeat' && this.engine.soldiers.some(x => x.evacuated);
    const title = m.outcome === 'victory' ? 'MISSION ACCOMPLIE' : retreat ? 'RETRAITE : ARTEFACT PERDU' : 'ESCOUADE PERDUE';
    const yn = (b: boolean) => `<span class="${b ? 'ok' : 'ko'}">${b ? '✓' : '✗'}</span>`;
    this.el.summary!.innerHTML = `<div class="box"><h2 class="${m.outcome === 'victory' ? 'win' : 'lose'}">${title}</h2>
      <div class="grid">
        <div class="row"><span>◆ Artefact</span>${yn(m.artifact)}</div><div class="row"><span>◇ Journal du terminal</span>${yn(m.logs)}</div>
        <div class="row"><span>Tours</span><b>${m.turns}</b></div><div class="row"><span>Hostiles neutralisés</span><b>${m.kills}/${m.aliens}</b></div>
        <div class="row"><span>Soldats perdus</span><b>${m.lost}/${m.soldiers.length}</b></div><div class="row"><span>Seed</span><b>${this.engine.state.seed}</b></div>
      </div>
      <div class="men">${m.soldiers.map(x => `${x.name} : ${x.alive ? `${x.hp}/${x.maxHp} PV` : 'perdu'}, ${x.kills} neutralisé${x.kills > 1 ? 's' : ''}`).join(' · ')}</div>
      <div class="btns"><button class="primary" id="sumNew">Rejouer (nouvelle seed)</button><button id="sumSame">Même seed</button></div></div>`;
    this.el.summary!.hidden = false;
    document.getElementById('sumNew')!.onclick = () => this.hooks.newMission();
    document.getElementById('sumSame')!.onclick = () => this.hooks.sameSeed();
  }
}
