import { expect, test } from "@playwright/test";

test("completes the Stage 1 browser journey without uncaught errors", async ({ page }) => {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await page.goto("/?seed=playwright-stage-1");
  await expect(page.getByRole("button", { name: /start mission/i })).toBeVisible();
  await expect(page.locator("canvas")).toBeVisible();

  await page.getByRole("button", { name: /start mission/i }).click();
  await expect(page.locator("#menu-panel")).toBeHidden();
  await expect(page.locator("#game-hud")).toBeVisible();

  await page.keyboard.down("d");
  await page.waitForTimeout(260);
  await page.keyboard.up("d");

  const canvas = page.locator("canvas");
  const bounds = await canvas.boundingBox();
  if (!bounds) {
    throw new Error("Phaser canvas did not expose a layout box");
  }
  const aimX = bounds.x + bounds.width * 0.84;
  const aimY = bounds.y + bounds.height * 0.5;
  await page.mouse.move(aimX, aimY);
  await page.mouse.down();
  await page.waitForTimeout(1700);
  await page.mouse.up();
  await expect(page.locator("#score-value")).not.toHaveText("00000", { timeout: 4000 });

  await page.getByRole("button", { name: /pause game/i }).click();
  await expect(page.locator("#pause-panel")).toBeVisible();
  await page.getByRole("button", { name: /resume/i }).click();
  await expect(page.locator("#pause-panel")).toBeHidden();

  await page.getByRole("button", { name: /mute audio/i }).click();
  await expect(page.locator("#mute-toggle")).toHaveAttribute("data-muted", "true");

  await page.waitForTimeout(8500);
  await expect(page.locator("#game-over-panel")).toBeVisible({ timeout: 5000 });
  await expect(page.locator("#final-tick")).not.toHaveText("0");

  const urlBeforeRestart = page.url();
  await page.getByRole("button", { name: /restart mission/i }).click();
  await expect(page.locator("#game-over-panel")).toBeHidden();
  await expect(page.locator("#game-hud")).toBeVisible();
  expect(page.url()).toBe(urlBeforeRestart);
  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});

