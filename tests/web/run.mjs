// Тесты веб-версии в настоящем браузере. Запуск из корня: node tests/web/run.mjs
// Время в браузере подменяем, поэтому двухминутный тайм проходит за секунды.
import { chromium } from "playwright";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";
import fs from "node:fs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const gameUrl = pathToFileURL(path.join(root, "index.html")).href;
const shots = path.join(root, "tests/web/screenshots");

const launchOptions = { headless: true };
if (process.env.PLAYWRIGHT_BROWSERS_PATH && fs.existsSync("/opt/pw-browsers/chromium")) {
  launchOptions.executablePath = "/opt/pw-browsers/chromium";
}
const browser = await chromium.launch(launchOptions).catch(() => chromium.launch({ headless: true }));

let passed = 0;
let failed = 0;

async function test(name, fn, viewport = { width: 1280, height: 800 }) {
  const page = await browser.newPage({ viewport });
  await page.route(/fonts\.(googleapis|gstatic)\.com/, (r) => r.abort());
  await page.clock.install();
  await page.goto(gameUrl);
  try {
    await fn(page);
    passed++;
    console.log(`PASS  ${name}`);
  } catch (e) {
    failed++;
    fs.mkdirSync(shots, { recursive: true });
    const file = path.join(shots, `${name.split(" ")[0]}.png`);
    await page.screenshot({ path: file });
    console.log(`FAIL  ${name}\n      ${e.message.split("\n")[0]}\n      снимок: ${path.relative(root, file)}`);
  }
  await page.close();
}

function expect(cond, what) {
  if (!cond) throw new Error(what);
}

const timer = (page) => page.locator("#time").innerText();
const seconds = (t) => {
  const [m, s] = t.split(":").map(Number);
  return m * 60 + s;
};

await test("T1 Экран старта читается", async (page) => {
  expect(await page.getByText("Убеги от динозавров!").isVisible(), "не видно заголовка «Убеги от динозавров!»");
  expect(await page.getByRole("button", { name: "Играть" }).isVisible(), "не видно кнопки «Играть»");
});

await test("T2 Игра начинается", async (page) => {
  await page.getByRole("button", { name: "Играть" }).click();
  await page.clock.runFor(2000);
  expect(!(await page.locator("#startScreen").isVisible()), "экран правил не исчез после «Играть»");
  const t = seconds(await timer(page));
  expect(t < 120 && t > 100, `таймер должен идти, а показывает ${await timer(page)}`);
});

await test("T3 Тайм заканчивается кубком, «Ещё раз» начинает заново", async (page) => {
  await page.getByRole("button", { name: "Играть" }).click();
  for (let i = 0; i < 25; i++) await page.clock.runFor(5000);
  expect(await page.locator("#endScreen").isVisible(), "экран с кубком не появился через 2 минуты");
  const title = await page.locator("#endTitle").innerText();
  expect(/Кубок у|Ничья/.test(title), `странный заголовок: ${title}`);
  const h = Number((await page.locator("#hScore").innerText()).match(/\d+/)[0]);
  const d = Number((await page.locator("#dScore").innerText()).match(/\d+/)[0]);
  expect(h + d > 0, "за 2 минуты никто не набрал очков");
  await page.getByRole("button", { name: "Ещё раз" }).click();
  await page.clock.runFor(500);
  expect(!(await page.locator("#endScreen").isVisible()), "экран с кубком не исчез после «Ещё раз»");
  expect(seconds(await timer(page)) >= 119, `после «Ещё раз» таймер ${await timer(page)}, а не 2:00`);
});

await test(
  "T4 Телефон: нет прокрутки вбок",
  async (page) => {
    const wide = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    expect(!wide, "страница шире экрана телефона");
    expect(await page.locator("header").isVisible(), "не видно табло");
    const box = await page.locator("#c").boundingBox();
    expect(box && box.height > 200, "поле игры слишком маленькое");
  },
  { width: 390, height: 844 },
);

await browser.close();
console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
