import { expect, test } from "@playwright/test";

test("Stage 1 journey starts, scores, pauses, mutes, and restarts", async ({ page }) => {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await page.goto("/");
  const state = page.locator("#vector-siege-state");
  await expect(state).toContainText("phase=menu", { timeout: 8_000 });
  await expect(page.locator("canvas")).toBeVisible();

  // The start click is also the browser gesture that unlocks Phaser audio.
  await page.mouse.click(640, 418);
  await expect(state).toContainText("phase=running", { timeout: 3_000 });

  await page.keyboard.down("d");
  await page.waitForTimeout(260);
  await page.keyboard.up("d");
  await page.mouse.move(1080, 360);
  await page.mouse.down();
  await page.waitForTimeout(1_050);
  await page.mouse.up();
  await expect.poll(() => state.textContent() ?? "", { timeout: 5_000 }).toMatch(/phase=running score=[1-9]/);

  await page.keyboard.press("p");
  await expect(state).toContainText("phase=paused", { timeout: 2_000 });
  await page.waitForTimeout(180);
  await page.keyboard.press("p");
  await expect(state).toContainText("phase=running", { timeout: 2_000 });

  await page.mouse.click(1164, 43);
  await expect(state).toContainText("muted=true", { timeout: 2_000 });
  const persistedMute = await page.evaluate(() => window.localStorage.getItem("vector-siege.audio-preferences"));
  expect(persistedMute).toContain('"muted":true');

  // Stop firing and let the deterministic contact loop reach the game-over screen.
  await expect(state).toContainText("phase=gameover", { timeout: 12_000 });
  await page.mouse.click(640, 448);
  await expect(state).toContainText("phase=running", { timeout: 3_000 });
  await expect(state).toContainText("tick=0", { timeout: 3_000 });

  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});

