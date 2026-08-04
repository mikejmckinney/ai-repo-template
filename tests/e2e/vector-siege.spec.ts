import { expect, test } from "@playwright/test";

test("Stage 1 player journey stays playable through combat, pause, mute, and restart", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await page.goto("/");
  await expect(page.locator("canvas")).toBeVisible();
  const status = page.locator("#game-status");
  await expect(status).toHaveAttribute("data-state", "menu");

  // The first click both unlocks browser audio and starts the run.
  await page.mouse.click(515, 520);
  await expect(status).toHaveAttribute("data-state", "running");

  await page.keyboard.down("d");
  await page.waitForTimeout(250);
  await page.keyboard.up("d");

  // Space has a deterministic nearest-target assist until the pointer is moved.
  await page.keyboard.down("Space");
  await page.waitForTimeout(2600);
  await page.keyboard.up("Space");
  await expect.poll(async () => Number(await status.getAttribute("data-score"))).toBeGreaterThan(0);

  await page.keyboard.press("p");
  await expect(status).toHaveAttribute("data-state", "paused");
  await page.keyboard.press("p");
  await expect(status).toHaveAttribute("data-state", "running");

  const mutedBefore = await status.getAttribute("data-muted");
  await page.keyboard.press("m");
  await expect(status).toHaveAttribute("data-muted", mutedBefore === "true" ? "false" : "true");

  await page.keyboard.press("r");
  await expect(status).toHaveAttribute("data-state", "running");
  await expect(status).toHaveAttribute("data-score", "0");

  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});
