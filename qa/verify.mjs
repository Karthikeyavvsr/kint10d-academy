import { chromium } from "playwright";
import fs from "node:fs";
import assert from "node:assert/strict";
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1440, height: 1000 },
});
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
await page.goto("http://127.0.0.1:5173/");
await page.getByText("Sign in with ChatGPT", { exact: true }).click();
await page.waitForFunction(() =>
  document.body.textContent.includes("Cloud progress loaded"),
);
await page.screenshot({ path: "qa/desktop.png", fullPage: true });
await page.getByRole("button", { name: "Curriculum", exact: true }).click();
await page.getByLabel("Choose subject").selectOption("AI & intelligence");
await page.getByLabel("Search lessons").fill("113B");
await page
  .getByRole("button")
  .filter({ has: page.getByRole("heading", { name: /What 10B/ }) })
  .click();
if (
  await page.getByRole("button", { name: "Mark as read", exact: true }).count()
) {
  await page.getByRole("button", { name: "Mark as read", exact: true }).click();
  await page.waitForFunction(() =>
    document.body.textContent.includes("Saved to your account"),
  );
}
await page
  .getByLabel("Lesson notes")
  .fill("QA note: 10B BF16 raw weights require 20 decimal GB.");
await page.getByRole("button", { name: "Save notes to account" }).click();
await page.waitForFunction(
  () =>
    document.body.textContent.includes("Saved to your account") &&
    !document.body.textContent.includes("device draft(s)"),
);
await page
  .getByRole("button", { name: /Bookmark / })
  .nth(1)
  .click();
await page.waitForFunction(() =>
  document.body.textContent.includes("Saved to your account"),
);
await page.screenshot({ path: "qa/lesson.png", fullPage: true });
await page.reload();
await page.waitForFunction(() =>
  document.body.textContent.includes("Cloud progress loaded"),
);
await page.getByRole("button", { name: /Continue learning/ }).click();
await page.getByLabel("Lesson notes").waitFor();
assert.match(
  await page.getByLabel("Lesson notes").inputValue(),
  /20 decimal GB/,
);
assert.equal(
  await page
    .getByRole("button", { name: "✓ Marked read", exact: true })
    .count(),
  1,
);
// A separate browser context simulates another device and signs into the same local identity.
const second = await browser.newContext({
  viewport: { width: 390, height: 844 },
});
const phone = await second.newPage();
await phone.goto("http://127.0.0.1:5173/signin-with-chatgpt?return_to=/");
await phone.waitForFunction(() =>
  document.body.textContent.includes("Cloud progress loaded"),
);
await phone.screenshot({ path: "qa/mobile.png", fullPage: true });
assert.equal(
  await phone.evaluate(() => document.documentElement.scrollWidth > innerWidth),
  false,
);
await phone.getByRole("button", { name: /Continue learning/ }).click();
assert.match(
  await phone.getByLabel("Lesson notes").inputValue(),
  /20 decimal GB/,
);
await phone.screenshot({ path: "qa/mobile-lesson.png", fullPage: true });
// API auth and optimistic concurrency protections.
const api = await context.request.get("http://127.0.0.1:5173/api/progress");
assert.equal(api.status(), 200);
const all = await api.json();
const existing = all.records.find((r) => r.key === "note:ai-06");
const conflict = await context.request.put(
  "http://127.0.0.1:5173/api/progress",
  {
    data: {
      key: existing.key,
      value: "stale overwrite",
      revision: existing.revision - 1,
    },
  },
);
assert.equal(conflict.status(), 409);
const evil = await context.request.put("http://127.0.0.1:5173/api/progress", {
  headers: { origin: "https://not-this-site.example" },
  data: { key: "note:test", value: "bad", revision: 0 },
});
assert.equal(evil.status(), 403);
const invalid = await context.request.put(
  "http://127.0.0.1:5173/api/progress",
  { data: { key: "review:test", value: "broken json", revision: 0 } },
);
assert.equal(invalid.status(), 400);
const anon = await browser.newContext();
assert.equal(
  (await anon.request.get("http://127.0.0.1:5173/api/progress")).status(),
  401,
);
await page.getByRole("button", { name: "Visual labs", exact: true }).click();
await page.getByRole("button", { name: "113B", exact: true }).click();
assert.match(await page.locator(".big-number").innerText(), /226/);
await page.getByRole("button", { name: "bonds", exact: true }).click();
assert.match(await page.locator(".big-number").innerText(), /1,000/);
await page.getByRole("button", { name: "gradient", exact: true }).click();
await page.getByRole("button", { name: "Take a step", exact: true }).click();
assert.match(await page.locator(".formula").innerText(), /3.4/);
await page.screenshot({ path: "qa/lab.png", fullPage: true });
await page.getByRole("button", { name: "Paper library", exact: true }).click();
assert.equal(await page.locator(".paper").count(), 22);
await page.getByRole("button", { name: "Settings", exact: true }).click();
await page.getByLabel("Reminder time", { exact: true }).fill("19:00");
await page
  .getByLabel("Reminder start date", { exact: true })
  .fill("2026-10-16");
const download = page.waitForEvent("download");
await page
  .getByRole("button", { name: "Download calendar reminder", exact: true })
  .click();
const event = await download;
await event.saveAs("qa/reminder.ics");
const ics = fs.readFileSync("qa/reminder.ics", "utf8");
assert.match(ics, /DTSTART:20261016T190000/);
assert.match(ics, /BEGIN:VALARM/);
await page.screenshot({ path: "qa/settings.png", fullPage: true });
fs.writeFileSync(
  "qa/local-report.json",
  JSON.stringify(
    {
      ok: errors.length === 0,
      errors,
      checks: [
        "signed-in save",
        "reload persistence",
        "separate-device readback",
        "stale-write conflict409",
        "cross-origin403",
        "malformed review400",
        "anonymous401",
        "mobile no overflow",
        "parameter memory arithmetic",
        "gradient update",
        "bond present value",
        "22 papers",
        "calendar event with alarm",
      ],
    },
    null,
    2,
  ),
);
assert.deepEqual(errors, []);
await browser.close();
console.log("All functional and layout checks passed.");
