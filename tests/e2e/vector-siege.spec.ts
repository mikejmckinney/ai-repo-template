import { expect, test } from "@playwright/test";

type RunState = {
  status: string;
  tick: number;
  score: number;
  wave: number;
};

type Enemy = { x: number; y: number };

test("completes the Stage 1 browser journey without page errors", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  const browserErrors: string[] = [];
  page.on("pageerror", (error) => browserErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") browserErrors.push(message.text());
  });

  await page.goto("/");
  await expect(page.locator("#vector-siege-canvas")).toBeVisible();
  await expect(page.locator("#screen-reader-status")).toContainText("start screen");

  await page.keyboard.press("Enter");
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.status)).toBe("running");

  const canvas = page.locator("#vector-siege-canvas");
  const bounds = await canvas.boundingBox();
  expect(bounds).not.toBeNull();
  const scaleX = (bounds?.width ?? 1280) / 1280;
  const scaleY = (bounds?.height ?? 720) / 720;

  await page.keyboard.down("ArrowRight");
  await page.waitForTimeout(220);
  await page.keyboard.up("ArrowRight");

  const target = await page.evaluate(() => window.__VECTOR_SIEGE__?.getNearestEnemy() as Enemy | null);
  expect(target).not.toBeNull();
  await page.mouse.move((bounds?.x ?? 0) + (target?.x ?? 640) * scaleX, (bounds?.y ?? 0) + (target?.y ?? 360) * scaleY);
  await page.mouse.down();
  await page.waitForTimeout(900);
  await page.mouse.up();
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.score ?? 0)).toBeGreaterThan(0);

  const beforePause = await page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.tick ?? 0);
  await page.keyboard.press("p");
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.status)).toBe("paused");
  await page.waitForTimeout(160);
  const pausedTick = await page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.tick ?? 0);
  expect(pausedTick).toBe(beforePause);
  await page.keyboard.press("p");
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getState()?.status)).toBe("running");

  const initialMute = await page.evaluate(() => window.__VECTOR_SIEGE__?.getAudioPreferences().muted ?? false);
  await page.keyboard.press("m");
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getAudioPreferences().muted)).toBe(!initialMute);

  await page.evaluate(() => window.__VECTOR_SIEGE__?.restart());
  await expect.poll(async () => page.evaluate(() => window.__VECTOR_SIEGE__?.getState() as RunState | null)).toMatchObject({
    status: "running",
    score: 0,
    tick: 0,
  });
  expect(browserErrors).toEqual([]);
});
