#!/usr/bin/env python3
"""Turn a run's findings into the deliverables: REPORT.md (tier list) and gallery.html (every finding
with its screenshots, boxed where the problem is, plus the contact sheets).

  build_report.py RUN_DIR [--title "App - deep e2e audit"] [--lang en|ru]

RUN_DIR layout (see references/05-report.md):
  findings/*.jsonl   one JSON object per line (schema: templates/finding.schema.json)
  shots/             screenshots referenced by findings (relative paths)
  sheets/            contact sheets (optional; all are shown in the gallery)
  run.json           optional {"app":..,"version":..,"commit":..,"platforms":[..],"notes":..}
Writes RUN_DIR/REPORT.md, RUN_DIR/gallery.html, RUN_DIR/annotated/.
Findings with "verdict": "rejected" are left out; "duplicate_of" merges into the target.
"""
import argparse
import glob
import html
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "visual"))
from annotate import draw  # noqa: E402
from PIL import Image  # noqa: E402

TIERS = ["S", "A", "B", "C", "D"]
TIER_TEXT = {
    "en": {"S": "data loss / security / crash", "A": "core feature broken", "B": "visible bug or real UX defect",
           "C": "minor / polish / edge case", "D": "nit"},
    "ru": {"S": "потеря данных / безопасность / падение", "A": "ядро сломано", "B": "видимый баг / реальный UX-дефект",
           "C": "мелочь / полировка / край", "D": "придирка"},
}
KIND_TEXT = {"en": {"functional": "functional", "visual": "visual", "ux": "UX", "a11y": "accessibility", "perf": "performance"},
             "ru": {"functional": "функционал", "visual": "визуал", "ux": "UX", "a11y": "доступность", "perf": "производительность"}}


def load(run):
    items = {}
    for f in sorted(glob.glob(os.path.join(run, "findings", "*.jsonl"))):
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            try:
                fd = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"skip {os.path.basename(f)}:{n}: {e}")
                continue
            fd.setdefault("id", f"{os.path.basename(f)}:{n}")
            items[fd["id"]] = fd
    for fd in list(items.values()):
        dup = fd.get("duplicate_of")
        if dup and dup in items and dup != fd["id"]:
            items[dup].setdefault("also", []).append(fd["id"])
            items[dup].setdefault("evidence", {}).setdefault("shots", []).extend(fd.get("evidence", {}).get("shots", []))
            items[dup].setdefault("boxes", []).extend(fd.get("boxes", []))
            del items[fd["id"]]
    return [fd for fd in items.values() if fd.get("verdict") != "rejected"]


def annotate_all(run, findings):
    out = os.path.join(run, "annotated")
    os.makedirs(out, exist_ok=True)
    for fd in findings:
        by_img = {}
        for b in fd.get("boxes", []):
            by_img.setdefault(b["img"], []).append(b)
        fd["_images"] = []
        shots = list(dict.fromkeys(fd.get("evidence", {}).get("shots", []) + list(by_img)))
        for img in shots:
            src = img if os.path.isabs(img) else os.path.join(run, img)
            if not os.path.exists(src):
                src2 = os.path.join(run, "shots", img)
                src = src2 if os.path.exists(src2) else None
            if not src:
                continue
            if img in by_img:
                dst = os.path.join(out, f"{fd['id']}__{os.path.basename(img)}")
                draw(Image.open(src), by_img[img], "#ff3b30").save(dst)
                fd["_images"].append(os.path.relpath(dst, run))
            else:
                fd["_images"].append(os.path.relpath(src, run))


def md(run, findings, title, lang, meta):
    t = TIER_TEXT[lang]
    counts = {k: sum(1 for f in findings if f.get("severity") == k) for k in TIERS}
    L = [f"# {title}", ""]
    def show(v):
        if isinstance(v, list):
            return ", ".join(str(x) for x in v)
        if isinstance(v, dict):
            return ", ".join(f"{k}: {x}" for k, x in v.items())
        return str(v)

    if meta:
        L += [" · ".join(f"**{k}:** {show(v)}" for k, v in meta.items() if k != "notes"), ""]
        if meta.get("notes"):
            L += [meta["notes"], ""]
    total = "Итог" if lang == "ru" else "Total"
    L += [f"**{total}: {len(findings)}** — " + " · ".join(f"{k} {counts[k]}" for k in TIERS), ""]
    verified = sum(1 for f in findings if f.get("verdict") == "confirmed")
    L += [(f"Перепроверено повторным прогоном: {verified}." if lang == "ru" else f"Re-verified by an independent re-run: {verified}."), ""]
    L += [("Галерея со скриншотами: `gallery.html`." if lang == "ru" else "Screenshots for every finding: `gallery.html`."), ""]
    # Hand-written sections (how it was tested, top items, what works, not covered, cleanup) live in
    # RUN/extra.md so a rebuild never loses them.
    extra = os.path.join(run, "extra.md")
    if os.path.exists(extra):
        L += [open(extra, encoding="utf-8").read().rstrip(), "", "---", ""]
    for k in TIERS:
        group = [f for f in findings if f.get("severity") == k]
        if not group:
            continue
        L += [f"## {k} — {t[k]} ({len(group)})", "", "| ID | " + ("Вид" if lang == "ru" else "Kind") + " | "
              + ("Дефект" if lang == "ru" else "Defect") + " | " + ("Где" if lang == "ru" else "Where") + " |", "|---|---|---|---|"]
        for f in sorted(group, key=lambda x: x["id"]):
            mark = " ✔" if f.get("verdict") == "confirmed" else ""
            kind = KIND_TEXT[lang].get(f.get("kind", ""), f.get("kind", ""))
            where = f.get("surface", "") or ", ".join(f.get("code_refs", [])[:2])
            desc = f.get("title", "")
            if f.get("actual"):
                desc += f" — {f['actual']}"
            L.append(f"| {f['id']}{mark} | {kind} | {desc.replace('|', '/')} | {where.replace('|', '/')} |")
        L.append("")
    return "\n".join(L) + "\n"


def gallery(run, findings, title, lang):
    t = TIER_TEXT[lang]
    sheets = sorted(glob.glob(os.path.join(run, "sheets", "*.png")))
    css = """
:root{--bg:#f7f7f5;--fg:#1d1d1f;--muted:#6e6e73;--card:#fff;--line:#e3e3e0;--S:#b3261e;--A:#c2410c;--B:#a16207;--C:#4d7c0f;--D:#57534e}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e8e8e8;--muted:#9a9a9a;--card:#1f1f1f;--line:#2e2e2e}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
header{position:sticky;top:0;background:var(--bg);border-bottom:1px solid var(--line);padding:12px 16px;z-index:2}
h1{font-size:20px;margin:0 0 8px}main{max-width:1200px;margin:0 auto;padding:16px}
.filters button{border:1px solid var(--line);background:var(--card);color:var(--fg);border-radius:999px;padding:4px 12px;margin:0 6px 6px 0;cursor:pointer}
.filters button.on{outline:2px solid var(--fg)}
.f{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:0 0 14px}
.f h2{font-size:16px;margin:0 0 6px}.tag{display:inline-block;border-radius:6px;padding:0 7px;color:#fff;font-weight:600;margin-right:8px}
.meta{color:var(--muted);font-size:13px;margin-bottom:8px}.f img{max-width:100%;border:1px solid var(--line);border-radius:8px;margin:6px 0;cursor:zoom-in}
dl{display:grid;grid-template-columns:max-content 1fr;gap:2px 12px;margin:6px 0}dt{color:var(--muted)}dd{margin:0}
ol{margin:4px 0 4px 18px;padding:0}.sheet img{max-width:100%}
#zoom{position:fixed;inset:0;background:rgba(0,0,0,.85);display:none;align-items:center;justify-content:center;z-index:9}#zoom img{max-width:96vw;max-height:96vh}
@media (max-width:640px){main{padding:10px}dl{grid-template-columns:1fr}}
"""
    H = [f"<!doctype html><html lang='{lang}'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         f"<title>{html.escape(title)}</title><style>{css}</style></head><body><header><h1>{html.escape(title)}</h1><div class='filters'>"]
    H.append("<button data-t='all' class='on'>all</button>" + "".join(
        f"<button data-t='{k}'>{k} · {sum(1 for f in findings if f.get('severity') == k)}</button>" for k in TIERS))
    kinds = sorted({f.get("kind", "") for f in findings if f.get("kind")})
    H.append("".join(f"<button data-k='{k}'>{html.escape(KIND_TEXT[lang].get(k, k))}</button>" for k in kinds))
    H.append("</div></header><main>")
    for k in TIERS:
        for f in sorted((x for x in findings if x.get("severity") == k), key=lambda x: x["id"]):
            H.append(f"<section class='f' data-t='{k}' data-k='{html.escape(f.get('kind', ''))}' id='{html.escape(f['id'])}'>")
            H.append(f"<h2><span class='tag' style='background:var(--{k})'>{k}</span>{html.escape(f['id'])} — {html.escape(f.get('title', ''))}</h2>")
            bits = [KIND_TEXT[lang].get(f.get("kind", ""), f.get("kind", "")), f.get("area", ""), f.get("surface", ""),
                    "✔ " + ("перепроверено" if lang == "ru" else "re-verified") if f.get("verdict") == "confirmed" else ""]
            H.append("<div class='meta'>" + " · ".join(html.escape(b) for b in bits if b) + "</div><dl>")
            for key, label in (("expected", "Ожидалось" if lang == "ru" else "Expected"), ("actual", "На деле" if lang == "ru" else "Actual"),
                               ("why", "Почему важно" if lang == "ru" else "Why it matters"), ("fix_hint", "Как чинить" if lang == "ru" else "Fix hint")):
                if f.get(key):
                    H.append(f"<dt>{label}</dt><dd>{html.escape(str(f[key]))}</dd>")
            if f.get("code_refs"):
                H.append(f"<dt>{'Код' if lang == 'ru' else 'Code'}</dt><dd>{html.escape(', '.join(f['code_refs']))}</dd>")
            H.append("</dl>")
            if f.get("repro"):
                H.append("<ol>" + "".join(f"<li>{html.escape(s)}</li>" for s in f["repro"]) + "</ol>")
            for img in f.get("_images", []):
                H.append(f"<img loading='lazy' src='{html.escape(img.replace(os.sep, '/'))}' alt='{html.escape(f['id'])}'>")
            H.append("</section>")
    if sheets:
        H.append("<h2>" + ("Листы сравнения" if lang == "ru" else "Contact sheets") + "</h2>")
        for s in sheets:
            rel = os.path.relpath(s, run).replace(os.sep, "/")
            H.append(f"<section class='f sheet'><h2>{html.escape(os.path.basename(s))}</h2><img loading='lazy' src='{html.escape(rel)}'></section>")
    H.append("""</main><div id='zoom'><img></div><script>
const z=document.getElementById('zoom');document.querySelectorAll('main img').forEach(i=>i.onclick=()=>{z.firstChild.src=i.src;z.style.display='flex'});z.onclick=()=>z.style.display='none';
let T='all',K=null;function apply(){document.querySelectorAll('.f[data-t]').forEach(s=>{s.style.display=((T==='all'||s.dataset.t===T)&&(!K||s.dataset.k===K))?'':'none'})}
document.querySelectorAll('[data-t]').forEach(b=>{if(b.tagName!=='BUTTON')return;b.onclick=()=>{T=b.dataset.t;document.querySelectorAll('button[data-t]').forEach(x=>x.classList.toggle('on',x===b));apply()}});
document.querySelectorAll('button[data-k]').forEach(b=>b.onclick=()=>{K=K===b.dataset.k?null:b.dataset.k;document.querySelectorAll('button[data-k]').forEach(x=>x.classList.toggle('on',x.dataset.k===K));apply()});
</script></body></html>""")
    return "\n".join(H)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run")
    ap.add_argument("--title", default="Deep e2e audit")
    ap.add_argument("--lang", default="en", choices=["en", "ru"])
    a = ap.parse_args()
    meta = {}
    if os.path.exists(os.path.join(a.run, "run.json")):
        meta = json.load(open(os.path.join(a.run, "run.json"), encoding="utf-8"))
    findings = load(a.run)
    annotate_all(a.run, findings)
    open(os.path.join(a.run, "REPORT.md"), "w", encoding="utf-8").write(md(a.run, findings, a.title, a.lang, meta))
    open(os.path.join(a.run, "gallery.html"), "w", encoding="utf-8").write(gallery(a.run, findings, a.title, a.lang))
    counts = " ".join(f"{k}{sum(1 for f in findings if f.get('severity') == k)}" for k in TIERS)
    print(f"OK {len(findings)} findings ({counts}) -> REPORT.md, gallery.html")


if __name__ == "__main__":
    main()
