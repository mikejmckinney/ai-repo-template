import { expect, test } from "@playwright/test";

test("Stage 1 run supports audio unlock, combat, pause, mute, and restart", async ({ page }) => {
  const browserErrors: string[] = [];
  page.on("pageerror", (error) => browserErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") browserErrors.push(`console: ${message.text()}`);
  });

  await page.goto("/?seed=23017");
  await expect(page).toHaveTitle(/Vector Siege/);
  await expect(page.getByRole("button", { name: /initiate run/i })).toBeVisible();

  // The click is the browser-gesture audio unlock. Hold fire on the first
  // deterministic spawn lane long enough for a projectile to score.
  await page.getByRole("button", { name: /initiate run/i }).click();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "running");
  await page.keyboard.down("d");
  await page.waitForTimeout(180);
  await page.keyboard.up("d");
  await page.mouse.move(373, 498);
  await page.mouse.down();
  await page.waitForTimeout(1300);
  await page.mouse.up();

  await expect.poll(async () => page.locator("#game-shell").getAttribute("data-score")).not.toBe("0");

  await page.getByRole("button", { name: /^pause$/i }).click();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "paused");
  await page.getByRole("button", { name: /resume run/i }).click();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "running");

  const mute = page.getByRole("button", { name: /audio: on/i }).first();
  await mute.click();
  await expect(page.getByRole("button", { name: /audio: off/i }).first()).toBeVisible();
  await page.getByRole("button", { name: /audio: off/i }).first().click();
  await expect(page.getByRole("button", { name: /audio: on/i }).first()).toBeVisible();

  await page.getByRole("button", { name: /^restart$/i }).click();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "running");
  await expect(page.locator("#game-shell")).toHaveAttribute("data-score", "0");
  expect(browserErrors).toEqual([]);
});
