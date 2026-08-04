import { expect, test } from "@playwright/test";

test("Stage 1 journey starts, fights, pauses, mutes, and restarts cleanly", async ({ page }) => {
  const browserErrors: string[] = [];
  page.on("pageerror", (error) => browserErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") {
      browserErrors.push(message.text());
    }
  });

  await page.goto("/");
  await expect(page.getByRole("button", { name: "START RUN" })).toBeVisible();
  await page.getByRole("button", { name: "START RUN" }).click();
  await expect(page.getByRole("button", { name: "PAUSE" })).toBeVisible();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "running");

  await page.keyboard.down("d");
  await page.waitForTimeout(180);
  await page.keyboard.up("d");

  const aimPoints = [
    [411, 20],
    [698, 18],
    [791, 700],
    [411, 20],
    [698, 18],
    [791, 700],
    [411, 20],
    [698, 18],
  ] as const;
  for (const [x, y] of aimPoints) {
    await page.mouse.move(x, y);
    await page.mouse.click(x, y);
    await page.waitForTimeout(90);
  }
  await page.keyboard.press("Space");
  await expect.poll(async () => Number(await page.locator("#game-shell").getAttribute("data-score")), {
    timeout: 5000,
  }).toBeGreaterThan(0);

  await page.getByRole("button", { name: "PAUSE" }).click();
  await expect(page.getByRole("button", { name: "RESUME" })).toBeVisible();
  await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "paused");
  await page.getByRole("button", { name: "RESUME" }).click();
  await expect(page.getByRole("button", { name: "PAUSE" })).toBeVisible();

  await page.getByRole("button", { name: "SOUND: ON" }).click();
  await expect(page.getByRole("button", { name: "SOUND: OFF" })).toBeVisible();
  await page.locator("#volume-slider").evaluate((element) => {
    const slider = element as HTMLInputElement;
    slider.value = "40";
    slider.dispatchEvent(new Event("input", { bubbles: true }));
  });

  const phase = await page.locator("#game-shell").getAttribute("data-phase");
  if (phase === "gameover") {
    await page.getByRole("button", { name: "RESTART RUN" }).click();
    await expect(page.locator("#game-shell")).toHaveAttribute("data-phase", "running");
  }

  expect(browserErrors).toEqual([]);
});
