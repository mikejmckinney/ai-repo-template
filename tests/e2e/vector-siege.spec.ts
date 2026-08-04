import { expect, test } from "@playwright/test";

test("Stage 1 mission journey has live combat and lifecycle controls", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => consoleErrors.push(error.message));

  await page.goto("/");
  await expect(page.locator("#start-button")).toBeVisible();
  await page.locator("#start-button").click();
  await expect(page.locator("#hud")).toBeVisible();
  await expect(page.locator("#game-state")).toHaveText("RUNNING");

  const initialPosition = await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().player);
  await page.mouse.move(1080, 405);
  await page.keyboard.down("a");
  await page.waitForTimeout(180);
  await page.keyboard.up("a");
  await expect.poll(async () => (await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().player.x ?? 0))).toBeLessThan(initialPosition?.x ?? 640);

  await page.keyboard.down("Space");
  await page.waitForTimeout(1200);
  await page.keyboard.up("Space");
  await expect.poll(async () => (await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().score ?? 0))).toBeGreaterThan(0);

  await page.locator("#pause-button").click();
  await expect(page.locator("#game-state")).toHaveText("PAUSED");
  const pausedTick = await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().tick ?? -1);
  await page.waitForTimeout(160);
  await expect.poll(async () => (await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().tick ?? -1))).toBe(pausedTick);

  await page.locator("#resume-button").click();
  await expect(page.locator("#game-state")).toHaveText("RUNNING");
  await page.locator("#hud-mute-button").click();
  await expect(page.locator("#hud-mute-button")).toHaveAttribute("aria-pressed", "true");

  await page.evaluate(() => window.__VECTOR_SIEGE__?.restart("journey-restart"));
  await expect.poll(async () => (await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().seed ?? ""))).toBe("journey-restart");
  await expect.poll(async () => (await page.evaluate(() => window.__VECTOR_SIEGE__?.getState().score ?? -1))).toBe(0);

  expect(consoleErrors).toEqual([]);
});

