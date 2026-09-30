#!/usr/bin/env node
// Map a web app: follow same-origin links breadth-first and, for every page, take screenshots at
// several widths and both colour schemes, run axe, record console errors, failed requests,
// horizontal overflow and the interactive-element inventory. This is the surface inventory for a
// web target - what exists, what it looks like everywhere, and where it already breaks - before the
// functional and visual agents go deep.
//
//   node crawl.mjs URL --out DIR [--max 40] [--depth 3] [--widths 375,768,1280,1920] [--schemes light,dark]
//                  [--storage state.json] [--include "/app/"] [--exclude "/logout,/delete"]
//
// Never follows links matching --exclude (defaults include logout/delete/remove/unsubscribe) and never
// submits forms: a crawl must not change data.
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const a = process.argv.slice(2);
const opt = (k, d) => (a.includes(k) ? a[a.indexOf(k) + 1] : d);
const start = a[0];
if (!start || start.startsWith("--")) { console.error("usage: node crawl.mjs URL --out DIR"); process.exit(1); }
const out = opt("--out", "crawl-out");
const max = +opt("--max", 40), depthMax = +opt("--depth", 3);
const widths = opt("--widths", "375,768,1280,1920").split(",").map(Number);
const schemes = opt("--schemes", "light,dark").split(",");
const include = opt("--include", "");
const exclude = ("logout,signout,sign-out,delete,remove,destroy,unsubscribe,deactivate," + opt("--exclude", "")).split(",").filter(Boolean);
fs.mkdirSync(path.join(out, "shots"), { recursive: true });

const origin = new URL(start).origin;
const browser = await chromium.launch();
const seen = new Set(), queue = [[start, 0]], pages = [];
const slug = (u) => (new URL(u).pathname.replace(/[^a-z0-9]+/gi, "_").replace(/^_|_$/g, "") || "root").slice(0, 60);
let AxeBuilder = null;
try { AxeBuilder = (await import("@axe-core/playwright")).default; } catch { console.warn("axe not installed - npm run setup"); }

while (queue.length && pages.length < max) {
  const [url, depth] = queue.shift();
  const key = url.split("#")[0];
  if (seen.has(key)) continue;
  seen.add(key);
  const rec = { url, depth, shots: [], console: [], failed: [], overflow: {}, axe: null, links: 0, inventory: 0 };
  for (const scheme of schemes) {
    const ctx = await browser.newContext({ colorScheme: scheme, storageState: opt("--storage", undefined), reducedMotion: "reduce" });
    const page = await ctx.newPage();
    page.on("console", (m) => { if (m.type() === "error") rec.console.push(m.text().slice(0, 300)); });
    page.on("pageerror", (e) => rec.console.push("pageerror: " + String(e).slice(0, 300)));
    page.on("response", (r) => { if (r.status() >= 400) rec.failed.push(`${r.status()} ${r.url()}`); });
    for (const w of widths) {
      await page.setViewportSize({ width: w, height: Math.round(w < 600 ? w * 2.1 : w * 0.62) });
      try { await page.goto(url, { waitUntil: "networkidle", timeout: 30000 }); } catch (e) { rec.console.push("goto: " + e); break; }
      const file = path.join("shots", `${String(pages.length).padStart(3, "0")}_${slug(url)}_${w}_${scheme}.png`);
      await page.screenshot({ path: path.join(out, file), fullPage: true, animations: "disabled" });
      rec.shots.push(file);
      rec.overflow[`${w}_${scheme}`] = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    }
    if (scheme === schemes[0]) {
      if (AxeBuilder) {
        const res = await new AxeBuilder({ page }).analyze().catch(() => null);
        rec.axe = res ? res.violations.map((v) => ({ id: v.id, impact: v.impact, count: v.nodes.length, help: v.help })) : null;
      }
      const inv = await page.evaluate(() => [...document.querySelectorAll("a,button,input,select,textarea,[role],[tabindex]")]
        .filter((e) => { const r = e.getBoundingClientRect(); return r.width > 1 && r.height > 1; })
        .map((e) => ({ tag: e.tagName.toLowerCase(), role: e.getAttribute("role") || "", name: (e.getAttribute("aria-label") || e.innerText || e.value || "").trim().slice(0, 60) })));
      fs.writeFileSync(path.join(out, `inventory_${String(pages.length).padStart(3, "0")}_${slug(url)}.json`), JSON.stringify(inv, null, 1));
      rec.inventory = inv.length;
      if (depth < depthMax) {
        const links = await page.evaluate(() => [...document.querySelectorAll("a[href]")].map((l) => l.href));
        rec.links = links.length;
        for (const l of links) {
          try {
            const u = new URL(l);
            if (u.origin !== origin || (include && !u.pathname.includes(include))) continue;
            if (exclude.some((x) => u.href.toLowerCase().includes(x))) continue;
            if (!seen.has(u.href.split("#")[0])) queue.push([u.href, depth + 1]);
          } catch { /* not a URL */ }
        }
      }
    }
    await ctx.close();
  }
  pages.push(rec);
  console.log(`${pages.length}. ${url}  shots=${rec.shots.length} console=${rec.console.length} failed=${rec.failed.length} axe=${rec.axe ? rec.axe.length : "-"}`);
}
fs.writeFileSync(path.join(out, "crawl.json"), JSON.stringify({ start, widths, schemes, pages }, null, 1));
await browser.close();
const over = pages.filter((p) => Object.values(p.overflow).some((v) => v > 0)).length;
console.log(`OK ${pages.length} pages; ${over} with horizontal overflow; ${pages.reduce((s, p) => s + p.console.length, 0)} console errors -> ${out}/crawl.json`);
