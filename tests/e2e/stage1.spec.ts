import { expect, type Locator, type Page, test } from "@playwright/test";

/**
 * Browser contract for Stage 1:
 *
 * - `start-game`, `audio-unlock`, `game-canvas`, `score`, `pause-game`,
 *   `resume-game`, `mute-toggle`, `restart-game`, and `game-over` are the
 *   preferred stable hooks.
 * - The corresponding controls must also have an accessible button name so
 *   this journey remains readable if a hook is renamed during implementation.
 * - `score` contains either a numeric value or text such as "Score: 12".
 * - `pause-overlay` is optional when the accessible text "Paused" is present.
 */

const button = (page: Page, testId: string, name: RegExp) =>
  page.getByTestId(testId).or(page.getByRole("button", { name })).first();

const textOrTestId = (page: Page, testId: string, text: RegExp) =>
  page.getByTestId(testId).or(page.getByText(text)).first();

const readScore = async (score: Locator) => {
  const content = (await score.textContent()) ?? "";
  const match = content.match(/(?:score\D*)?(\d+)/i);
  return match ? Number(match[1]) : -1;
};

test.use({ viewport: { width: 1280, height: 720 } });

test("Stage 1 player journey supports combat, audio, pause, and restart", async ({ page }) => {
  const browserErrors: string[] = [];
  page.on("pageerror", (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") browserErrors.push(`console: ${message.text()}`);
  });

  await page.goto("/");

  await expect(page.getByText(/vector siege/i).first()).toBeVisible();
  const startGame = button(page, "start-game", /start(?:\s+game)?/i);
  await expect(startGame).toBeVisible();
  const audioUnlock = button(page, "audio-unlock", /(?:enable|unlock)\s+audio/i);
  if (await audioUnlock.isVisible()) await audioUnlock.click();
  await startGame.click();
  if (await audioUnlock.isVisible()) {
    await audioUnlock.click();
  } else {
    await expect(audioUnlock).toBeVisible();
    await audioUnlock.click();
  }

  const arena = page.getByTestId("game-canvas").or(page.locator("canvas")).first();
  await expect(arena).toBeVisible();
  const arenaBounds = await arena.boundingBox();
  expect(arenaBounds).not.toBeNull();
  if (!arenaBounds) throw new Error("The Stage 1 arena must expose a visible canvas.");

  // Move inside the arena, then aim through the arena center while firing.
  await page.keyboard.down("ArrowRight");
  await page.waitForTimeout(350);
  await page.keyboard.up("ArrowRight");
  await page.keyboard.down("ArrowDown");
  await page.waitForTimeout(250);
  await page.keyboard.up("ArrowDown");
  await page.mouse.move(
    arenaBounds.x + arenaBounds.width / 2,
    arenaBounds.y + arenaBounds.height / 2,
  );

  for (let shot = 0; shot < 36; shot += 1) {
    await page.keyboard.press("Space");
    await page.waitForTimeout(100);
  }

  const score = textOrTestId(page, "score", /score\s*:?\s*\d+/i);
  await expect(score).toBeVisible();
  await expect.poll(() => readScore(score), { timeout: 15_000 }).toBeGreaterThan(0);

  const pauseGame = button(page, "pause-game", /pause/i);
  await expect(pauseGame).toBeVisible();
  await pauseGame.click();
  const paused = textOrTestId(page, "pause-overlay", /paused/i);
  await expect(paused).toBeVisible();

  const resumeGame = button(page, "resume-game", /resume/i);
  await expect(resumeGame).toBeVisible();
  await resumeGame.click();
  await expect(paused).toBeHidden();

  const muteToggle = button(page, "mute-toggle", /(?:mute|sound)/i);
  await expect(muteToggle).toBeVisible();
  await muteToggle.click();
  await expect
    .poll(async () => {
      const pressed = await muteToggle.getAttribute("aria-pressed");
      const label = `${(await muteToggle.getAttribute("aria-label")) ?? ""} ${(await muteToggle.textContent()) ?? ""}`;
      return pressed === "true" || /unmute|muted|sound\s+off/i.test(label);
    })
    .toBe(true);

  const restartGame = button(page, "restart-game", /restart/i);
  const gameOver = textOrTestId(page, "game-over", /game\s*over/i);
  await expect(restartGame.or(gameOver).first()).toBeVisible({ timeout: 15_000 });
  if (await restartGame.isVisible()) {
    await restartGame.click();
    await expect(page.getByTestId("game-canvas").or(page.locator("canvas")).first()).toBeVisible();
  }

  expect(browserErrors, browserErrors.join("\n")).toEqual([]);
});
