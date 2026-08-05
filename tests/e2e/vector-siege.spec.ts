import { expect, test, type Locator } from '@playwright/test';

test.use({ viewport: { width: 1280, height: 720 } });

const SCORE_TIMEOUT = 15_000;
const GAME_OVER_TIMEOUT = 20_000;

async function readNumericValue(locator: Locator): Promise<number> {
  const text = (await locator.textContent()) ?? '';
  const match = text.replaceAll(',', '').match(/-?\d+/);

  return match ? Number(match[0]) : 0;
}

test('completes the Vector Siege Stage 1 browser journey', async ({ page }, testInfo) => {
  test.setTimeout(45_000);

  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];

  page.on('console', (message) => {
    if (message.type() === 'error') {
      consoleErrors.push(message.text());
    }
  });
  page.on('pageerror', (error) => {
    pageErrors.push(error.message);
  });

  try {
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    await expect(page.getByRole('heading', { name: /vector siege/i })).toBeVisible();

    const startMission = page.getByTestId('start-mission');
    await expect(startMission).toBeVisible();
    await expect(startMission).toHaveAccessibleName(/start mission/i);
    await startMission.click();

    const gameStatus = page.getByTestId('game-status');
    const scoreValue = page.getByTestId('score-value');
    const waveValue = page.getByTestId('wave-value');
    const canvas = page.getByTestId('game-canvas');

    await expect(gameStatus).toBeVisible();
    await expect(canvas).toBeVisible();

    await page.keyboard.down('ArrowRight');
    await page.waitForTimeout(250);
    await page.keyboard.up('ArrowRight');

    const canvasBounds = await canvas.boundingBox();
    if (!canvasBounds) {
      throw new Error('The game canvas did not expose a usable bounding box.');
    }

    const aimPoint = {
      x: canvasBounds.x + canvasBounds.width * 0.75,
      y: canvasBounds.y + canvasBounds.height * 0.5,
    };
    const sweepPoint = {
      x: canvasBounds.x + canvasBounds.width * 0.25,
      y: canvasBounds.y + canvasBounds.height * 0.5,
    };

    await page.mouse.click(aimPoint.x, aimPoint.y);
    await page.mouse.move(aimPoint.x, aimPoint.y);
    await page.mouse.down();
    try {
      await page.waitForTimeout(500);
      await page.mouse.move(sweepPoint.x, sweepPoint.y, { steps: 4 });
      await page.waitForTimeout(500);
    } finally {
      await page.mouse.up();
    }

    await page.keyboard.down('Space');
    try {
      await page.waitForTimeout(1_000);
    } finally {
      await page.keyboard.up('Space');
    }

    await expect
      .poll(() => readNumericValue(scoreValue), { timeout: SCORE_TIMEOUT })
      .toBeGreaterThan(0);

    const pauseGame = page.getByTestId('pause-game');
    const resumeGame = page.getByTestId('resume-game');
    await expect(pauseGame).toBeVisible();
    await pauseGame.click();
    await expect(gameStatus).toContainText(/paused/i);

    await expect(resumeGame).toBeVisible();
    await resumeGame.click();
    await expect(gameStatus).not.toContainText(/paused/i);

    const muteAudio = page.getByTestId('mute-audio');
    await expect(muteAudio).toBeVisible();
    await muteAudio.click();
    await expect
      .poll(async () => {
        const ariaPressed = await muteAudio.getAttribute('aria-pressed');
        const ariaLabel = await muteAudio.getAttribute('aria-label');
        const buttonText = (await muteAudio.textContent()) ?? '';
        const statusText = (await gameStatus.textContent()) ?? '';

        return (
          ariaPressed === 'true' ||
          /muted|unmute/i.test(`${ariaLabel ?? ''} ${buttonText} ${statusText}`)
        );
      })
      .toBe(true);

    const restartGame = page.getByTestId('restart-game');
    if (await restartGame.isVisible()) {
      await restartGame.click();
      await expect.poll(() => readNumericValue(waveValue)).toBe(1);
      await expect.poll(() => readNumericValue(scoreValue)).toBe(0);
      await expect(gameStatus).not.toContainText(/game over|paused/i);
    } else {
      await expect(gameStatus).toContainText(/game over/i, { timeout: GAME_OVER_TIMEOUT });
    }
  } finally {
    await testInfo.attach('browser-error-evidence', {
      body: JSON.stringify({ consoleErrors, pageErrors }, null, 2),
      contentType: 'application/json',
    });

    expect(consoleErrors, `Console errors: ${consoleErrors.join(' | ')}`).toEqual([]);
    expect(pageErrors, `Page errors: ${pageErrors.join(' | ')}`).toEqual([]);
  }
});
