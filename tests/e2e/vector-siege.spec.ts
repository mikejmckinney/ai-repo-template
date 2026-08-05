import { expect, test } from "@playwright/test";

test("completes the Stage 1 player journey without browser errors", async ({ page }) => {
  const browserErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      browserErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => browserErrors.push(error.message));

  await page.goto("/");
  await expect(page).toHaveTitle("Vector Siege");
  await expect(page.getByRole("heading", { name: "Hold the line." })).toBeVisible();
  await expect(page.getByTestId("start-button")).toBeVisible();

  await page.getByTestId("start-button").click();
  await expect(page.getByRole("region", { name: "Game status" })).toBeVisible();
  await page.keyboard.down("d");
  await page.waitForTimeout(140);
  await page.keyboard.up("d");

  await page.mouse.move(1100, 360);
  await page.mouse.down();
  await page.waitForTimeout(1450);
  await page.mouse.up();
  await expect.poll(async () => Number((await page.getByTestId("score").textContent()) ?? "0")).toBeGreaterThan(0);

  await page.getByTestId("pause-button").click();
  await expect(page.getByRole("heading", { name: "Systems paused." })).toBeVisible();
  const pausedTick = await page.locator("#pause-tick").textContent();
  await page.waitForTimeout(180);
  await expect(page.locator("#pause-tick")).toHaveText(pausedTick ?? "");
  await page.getByTestId("resume-button").click();
  await expect(page.getByRole("heading", { name: "Systems paused." })).toBeHidden();

  await page.getByRole("button", { name: "Mute sound" }).click();
  await expect(page.getByRole("button", { name: "Unmute sound" })).toHaveText("SOUND OFF");
  await expect.poll(async () => page.evaluate(() => window.localStorage.getItem("vectorSiege.muted"))).toBe("true");

  await expect(page.getByTestId("restart-button")).toBeVisible({ timeout: 20000 });
  await page.getByTestId("restart-button").click();
  await expect(page.getByTestId("restart-button")).toBeHidden();
  await expect(page.getByTestId("score")).toHaveText("000000");
  expect(browserErrors).toEqual([]);
});

