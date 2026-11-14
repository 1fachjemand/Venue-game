import os, sys, subprocess
import lupa.luajit21 as LJ
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
# reuse run_mock setup
src = open(os.path.join(ROOT, "tools", "run_mock.py")).read()
src = src.replace('lua.execute(open(sys.argv[2]).read())', 'g.RENDER_LUA = os.path.join(ROOT, "tools", "render_html.lua"); g.OUT_DIR = OUT; g.WRITE = lambda p, s: open(p, "w").write(s); g.dofile = None\nlua.execute("dofile = function(p) return assert(loadfile(p))() end")\nlua.execute(open(os.path.join(ROOT, "tools", "scenario_screens.lua")).read())')
src = src.replace("sys.exit(1 if errs else 0)", "")
exec(compile(src, "run_mock", "exec"))
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1920, "height": 1080})
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".html"):
            pg.goto("file://" + os.path.join(OUT, f))
            pg.screenshot(path=os.path.join(OUT, f.replace(".html", ".png")))
    b.close()
print("screens done")
