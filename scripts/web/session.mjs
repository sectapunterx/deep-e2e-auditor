#!/usr/bin/env node
// Run one scripted session against a web app (or an Electron app) in a single browser context and
// record everything a reviewer needs: a screenshot after every step you mark, the accessibility tree,
// axe violations, console errors, failed requests, and a results.json with each step's outcome.
//
//   node session.mjs steps.json --out DIR
//
// steps.json:
// {
//   "target": {"url": "http://localhost:5173"}            // or {"electron": "path/to/main.js", "args": [], "cwd": "."}
//   "viewport": [1280, 800], "colorScheme": "dark", "locale": "ru-RU", "storageState": "state.json",
//   "steps": [
//     {"goto": "/settings"},
//     {"click": "role=button[name='Save']"},                 // any Playwright selector
//     {"click": {"x": 400, "y": 300}, "button": "right"},    // raw coordinates
//     {"hover": "text=Profile"}, {"fill": ["#email", "a@b.c"]}, {"type": "hello"}, {"press": "Control+K"},
//     {"drag": ["#card-1", "#column-done"]}, {"scroll": [0, 800]}, {"wait": 500}, {"waitFor": "text=Saved"},
//     {"shot": "settings_saved", "fullPage": false, "clip": [0,0,800,600]},
//     {"a11y": "settings"}, {"axe": "settings"}, {"inventory": "settings"},
//     {"eval": "document.title"}, {"expect": {"selector": "text=Saved", "visible": true}},
//     {"viewport": [375, 812]}, {"emulate": {"colorScheme": "light"}}, {"offline": true}
//   ]
// }
// Every step may carry "name" (used in results) and "optional": true (a failure does not stop the run).
// "inventory" lists every visible interactive element (role, name, box) - the map for right-clicking,
// hovering and tabbing through everything of one kind.
import fs from "node:fs";
import path from "node:path";
import { chromium, _electron as electron } from "playwright";

const args = process.argv.slice(2);
if (!args[0]) { console.error("usage: node session.mjs steps.json --out DIR"); process.exit(1); }
const spec = JSON.parse(fs.readFileSync(args[0], "utf8"));
const out = args.includes("--out") ? args[args.indexOf("--out") + 1] : "session-out";
fs.mkdirSync(path.join(out, "shots"), { recursive: true });

const log = { console: [], pageErrors: [], failedRequests: [], steps: [] };
let browser, context, page, app;

async function open() {
  const t = spec.target || {};
  if (t.electron) {
    app = await electron.launch({ args: [t.electron, ...(t.args || [])], cwd: t.cwd, env: { ...process.env, ...(t.env || {}) } });
    page = await app.firstWindow();
    if (spec.viewport) await page.setViewportSize({ width: spec.viewport[0], height: spec.viewport[1] }).catch(() => {});
  } else {
    browser = await chromium.launch({ headless: spec.headless !== false });
    context = await browser.newContext({
      viewport: spec.viewport ? { width: spec.viewport[0], height: spec.viewport[1] } : { width: 1280, height: 800 },
      colorScheme: spec.colorScheme, locale: spec.locale, storageState: spec.storageState,
      deviceScaleFactor: spec.scale || 1, reducedMotion: "reduce",
    });
    page = await context.newPage();
  }
  page.on("console", (m) => { if (["error", "warning"].includes(m.type())) log.console.push({ type: m.type(), text: m.text(), at: page.url() }); });
  page.on("pageerror", (e) => log.pageErrors.push({ text: String(e), at: page.url() }));
  page.on("requestfailed", (r) => log.failedRequests.push({ url: r.url(), error: r.failure()?.errorText }));
  page.on("response", (r) => { if (r.status() >= 400) log.failedRequests.push({ url: r.url(), status: r.status() }); });
  if (t.url) await page.goto(t.url, { waitUntil: "networkidle" }).catch((e) => log.pageErrors.push({ text: "goto: " + e }));
}

function loc(s) { return typeof s === "string" ? page.locator(s).first() : null; }

async function inventory() {
  return page.evaluate(() => {
    const sel = "a,button,input,select,textarea,summary,[role],[tabindex],[onclick],[contenteditable=true]";
    const rows = [];
    for (const el of document.querySelectorAll(sel)) {
      const r = el.getBoundingClientRect();
      const st = getComputedStyle(el);
      if (r.width < 2 || r.height < 2 || st.visibility === "hidden" || st.display === "none") continue;
      rows.push({
        tag: el.tagName.toLowerCase(), role: el.getAttribute("role") || "", name: (el.getAttribute("aria-label") || el.innerText || el.value || el.title || "").trim().slice(0, 80),
        x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
        font: st.fontSize + " " + st.fontWeight, color: st.color, bg: st.backgroundColor, radius: st.borderRadius, pad: st.padding,
        focusable: el.tabIndex >= 0,
      });
    }
    return rows;
  });
}

async function run(step) {
  const k = Object.keys(step).find((x) => !["name", "optional", "button", "fullPage", "clip", "timeout"].includes(x));
  const v = step[k];
  const timeout = step.timeout || 8000;
  switch (k) {
    case "goto": return page.goto(new URL(v, page.url() === "about:blank" ? spec.target.url : page.url()).toString(), { waitUntil: "networkidle", timeout: 30000 });
    case "click":
      if (typeof v === "object") return page.mouse.click(v.x, v.y, { button: step.button || "left" });
      return loc(v).click({ button: step.button || "left", timeout });
    case "dblclick": return typeof v === "object" ? page.mouse.dblclick(v.x, v.y) : loc(v).dblclick({ timeout });
    case "hover": return typeof v === "object" ? page.mouse.move(v.x, v.y) : loc(v).hover({ timeout });
    case "fill": return loc(v[0]).fill(v[1], { timeout });
    case "type": return page.keyboard.type(v, { delay: 20 });
    case "press": return page.keyboard.press(v);
    case "drag": return loc(v[0]).dragTo(loc(v[1]), { timeout });
    case "scroll": return page.mouse.wheel(v[0], v[1]);
    case "wait": return page.waitForTimeout(v);
    case "waitFor": return loc(v).waitFor({ timeout });
    case "viewport": return page.setViewportSize({ width: v[0], height: v[1] });
    case "emulate": return page.emulateMedia(v);
    case "offline": return context ? context.setOffline(!!v) : null;
    case "eval": return page.evaluate(v);
    case "expect": {
      const l = loc(v.selector);
      if (v.visible !== undefined && (await l.isVisible()) !== v.visible) throw new Error(`expected ${v.selector} visible=${v.visible}`);
      if (v.text !== undefined && !(await l.innerText()).includes(v.text)) throw new Error(`expected ${v.selector} to contain ${v.text}`);
      return true;
    }
    case "shot": {
      const file = path.join(out, "shots", `${String(log.steps.length).padStart(3, "0")}_${v}.png`);
      const opt = { path: file, fullPage: !!step.fullPage, animations: "disabled" };
      if (step.clip) opt.clip = { x: step.clip[0], y: step.clip[1], width: step.clip[2], height: step.clip[3] };
      await page.screenshot(opt);
      return path.relative(out, file);
    }
    case "a11y": {
      const snap = await page.locator("body").ariaSnapshot().catch(async () => JSON.stringify(await page.accessibility.snapshot(), null, 1));
      fs.writeFileSync(path.join(out, `a11y_${v}.yml`), snap);
      return `a11y_${v}.yml`;
    }
    case "axe": {
      const { default: AxeBuilder } = await import("@axe-core/playwright");
      const res = await new AxeBuilder({ page }).analyze();
      const slim = res.violations.map((x) => ({ id: x.id, impact: x.impact, help: x.help, nodes: x.nodes.slice(0, 8).map((n) => n.target.join(" ")) }));
      fs.writeFileSync(path.join(out, `axe_${v}.json`), JSON.stringify(slim, null, 1));
      return `${slim.length} violations`;
    }
    case "inventory": {
      const rows = await inventory();
      fs.writeFileSync(path.join(out, `inventory_${v}.json`), JSON.stringify(rows, null, 1));
      return `${rows.length} elements`;
    }
    default: throw new Error("unknown step " + JSON.stringify(step));
  }
}

await open();
let failed = false;
for (const step of spec.steps || []) {
  const t0 = Date.now();
  try {
    const r = await run(step);
    log.steps.push({ step, ok: true, ms: Date.now() - t0, result: typeof r === "string" || typeof r === "number" ? r : undefined });
  } catch (e) {
    log.steps.push({ step, ok: false, ms: Date.now() - t0, error: String(e).slice(0, 400) });
    const file = path.join(out, "shots", `${String(log.steps.length).padStart(3, "0")}_FAILED.png`);
    await page.screenshot({ path: file }).catch(() => {});
    if (!step.optional) { failed = true; break; }
  }
}
fs.writeFileSync(path.join(out, "results.json"), JSON.stringify(log, null, 1));
if (app) await app.close(); else await browser.close();
const bad = log.steps.filter((s) => !s.ok).length;
console.log(`${failed ? "STOPPED" : "OK"} ${log.steps.length} steps, ${bad} failed, ${log.console.length} console warnings/errors, ${log.pageErrors.length} page errors, ${log.failedRequests.length} failed requests -> ${out}`);
process.exit(failed ? 1 : 0);
