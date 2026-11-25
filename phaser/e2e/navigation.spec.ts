import { expect, test } from '@playwright/test';

// Parcours tactile de base : démarrer, sélectionner, déplacer (aperçu puis confirmation), finir le tour, 0 erreur console.
test('navigation : commencer, sélectionner, déplacer, finir le tour', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(e.message));

  await page.goto('/?seed=e2e');
  await expect(page.getByRole('button', { name: 'Commencer', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Commencer', exact: true }).click();
  await page.waitForFunction(() => !!window.__abyss?.scene?.sys.isActive(), null, { timeout: 30_000 });
  await page.waitForTimeout(1000);
  await expect(page.locator('.card')).toHaveCount(4);
  expect((await page.locator('#cards').boundingBox())!.width).toBeLessThanOrEqual(120); // roster étroit
  await expect(page.locator('#obj')).toContainText('Artefact');

  // sélection d'un soldat par sa carte
  await page.locator('[data-id=s3]').click();
  await expect(page.locator('.card.sel')).toHaveAttribute('data-id', 's3');
  await page.waitForTimeout(600); // fin du recentrage caméra

  // aperçu d'un déplacement : toucher une case atteignable de la carte (coordonnées écran calculées depuis la caméra)
  const tile = await page.evaluate(() => {
    const e = window.__abyss!.engine, u = e.unit('s3')!, r = e.reach(u);
    let best: { x: number; y: number; c: number } | null = null;
    for (const [i, c] of r.cost) {
      if (c < 18 || c > 36) continue;
      const x = i % e.state.width, y = Math.floor(i / e.state.width);
      if (!best || c > best.c) best = { x, y, c };
    }
    return best!;
  });
  const screenOf = () => page.evaluate(({ x, y }) => {
    const c = window.__abyss!.scene!.cameras.main;
    return { x: ((x - y) * 32 - c.worldView.x) * c.zoom, y: ((x + y) * 16 - c.worldView.y) * c.zoom };
  }, tile);
  let p = await screenOf();
  await page.mouse.click(p.x, p.y);
  await expect(page.locator('#preview')).toContainText('Déplacement');
  await expect(page.locator('#preview')).toContainText('UT');

  const before = await page.evaluate(() => { const u = window.__abyss!.engine.unit('s3')!; return { x: u.x, y: u.y, tu: u.tu }; });
  p = await screenOf();
  await page.mouse.click(p.x, p.y); // re-toucher la même case : confirmer
  await page.waitForFunction(() => !document.getElementById('hud')!.classList.contains('locked'), null, { timeout: 30_000 });
  const after = await page.evaluate(() => { const u = window.__abyss!.engine.unit('s3')!; return { x: u.x, y: u.y, tu: u.tu }; });
  expect(after.tu).toBeLessThan(before.tu);
  expect(`${after.x},${after.y}`).not.toBe(`${before.x},${before.y}`);

  // fin du tour (aperçu puis confirmation), vitesse « Passer » pour accélérer le tour alien
  for (let i = 0; i < 3; i++) await page.locator('#speed').click(); // ×1 → ×2 → ×4 → Passer
  await expect(page.locator('#speed')).toHaveText('Passer');
  await page.locator('[data-act=end]').click();
  await expect(page.locator('#preview')).toContainText('Fin du tour');
  await page.locator('[data-act=end]').click();
  await page.waitForFunction(() => window.__abyss!.engine.state.turn >= 2 && !document.getElementById('hud')!.classList.contains('locked'), null, { timeout: 60_000 });
  await expect(page.locator('#obj')).toContainText('Tour 2');

  expect(errors).toEqual([]);
});
