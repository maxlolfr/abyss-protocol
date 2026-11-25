import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

describe('Architecture', () => {
  it('la simulation ne dépend ni de Phaser ni du DOM', () => {
    const dir = join(process.cwd(), 'src/sim');
    for (const f of readdirSync(dir)) {
      const code = readFileSync(join(dir, f), 'utf8');
      expect(/from ['"]phaser['"]|document\.|window\.|Math\.random/.test(code)).toBe(false);
    }
  });
});
