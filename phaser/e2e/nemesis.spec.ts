import { expect, test } from '@playwright/test';

// Démo Phaser 4 « salle Némésis » : démarrer, sélectionner, déplacer au toucher (aperçu puis confirmation),
// finir le tour, 0 erreur console. Canvas Retina : coordonnées CSS = pixels du canvas / pixelRatio.
test('démo Némésis : commencer, sélectionner, déplacer, finir le tour', async ({ page }) => {
  test.setTimeout(180_000); // rendu logiciel en CI (pas de GPU) : chaque image coûte cher
  const errors: string[] = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(e.message));

  await page.goto('/nemesis.html?seed=e2e&q=allegee');
  await page.getByRole('button', { name: 'Entrer dans la salle' }).click();
  await page.waitForFunction(() => !!window.__abyss?.scene?.sys.isActive(), null, { timeout: 30_000 });
  await page.waitForTimeout(1200);
  await expect(page.locator('.card')).toHaveCount(4);
  await expect(page.locator('#obj')).toContainText('Artefact');

  await page.locator('[data-id=s3]').click();
  await expect(page.locator('.card.sel')).toHaveAttribute('data-id', 's3');
  await page.waitForTimeout(600);

  const tile = await page.evaluate(() => {
    const e = window.__abyss!.engine, u = e.unit('s3')!, r = e.reach(u);
    let best: { x: number; y: number; c: number } | null = null;
    for (const [i, c] of r.cost) {
      if (c < 12 || c > 30) continue;
      const x = i % e.state.width, y = Math.floor(i / e.state.width);
      if (e.state.units.some(o => o.alive && o.x === x && o.y === y)) continue;
      if (!best || c > best.c) best = { x, y, c };
    }
    return best!;
  });
  const screenOf = () => page.evaluate(({ x, y }) => {
    const s = window.__abyss!.scene!, c = s.cameras.main, w = s.worldOf({ x, y }), k = s.pixelRatio ?? 1;
    return { x: ((w.sx - c.worldView.x) * c.zoom) / k, y: ((w.sy - c.worldView.y) * c.zoom) / k };
  }, tile);
  let p = await screenOf();
  await page.mouse.click(p.x, p.y);
  await expect(page.locator('#preview')).toContainText('Déplacement');

  const before = await page.evaluate(() => { const u = window.__abyss!.engine.unit('s3')!; return { x: u.x, y: u.y, tu: u.tu }; });
  p = await screenOf();
  await page.mouse.click(p.x, p.y);
  await page.waitForFunction(() => !document.getElementById('hud')!.classList.contains('locked'), null, { timeout: 30_000 });
  const after = await page.evaluate(() => { const u = window.__abyss!.engine.unit('s3')!; return { x: u.x, y: u.y, tu: u.tu }; });
  expect(after.tu).toBeLessThan(before.tu);
  expect(`${after.x},${after.y}`).not.toBe(`${before.x},${before.y}`);

  for (let i = 0; i < 3; i++) await page.locator('#speed').click();
  await expect(page.locator('#speed')).toHaveText('Passer');
  await page.locator('[data-act=end]').click();
  await page.locator('[data-act=end]').click();
  await page.waitForFunction(() => window.__abyss!.engine.state.turn >= 2 && !document.getElementById('hud')!.classList.contains('locked'), null, { timeout: 120_000 });
  await expect(page.locator('#obj')).toContainText('Tour 2');

  expect(errors).toEqual([]);
});
