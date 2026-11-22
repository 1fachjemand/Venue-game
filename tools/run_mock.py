# Play-tests the game in the Roblox mock. Usage: python3 tools/run_mock.py <api_classes.lua> <scenario.lua>
import os, sys, json
import lupa.luajit21 as LJ
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LJ.LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.READFILE = lambda p: open(p, encoding="utf-8").read()
g.WRITEFILE = lambda p, s: open(p, "w", encoding="utf-8").write(s)
g.OUT_DIR = os.environ.get("OUT_DIR", ".")
g.ARGS = os.environ.get("SCENARIO_ARGS", "")
g.API_DATA = lua.execute(open(sys.argv[1]).read())
lua.execute(open(os.path.join(ROOT, "tools", "mock_roblox.lua")).read())

def py_to_lua(o):
    if isinstance(o, dict):
        t = lua.table()
        for k, v in o.items(): t[k] = py_to_lua(v)
        return t
    if isinstance(o, list):
        t = lua.table()
        for i, v in enumerate(o, 1): t[i] = py_to_lua(v)
        return t
    return o
g.MOCK.jsonDecode = lambda s: py_to_lua(json.loads(s))

def tree(path, name):
    node = {"class": "Folder", "name": name, "children": []}
    for e in sorted(os.listdir(path)):
        full = os.path.join(path, e)
        if os.path.isdir(full): node["children"].append(tree(full, e))
        elif e.endswith(".lua"): node["children"].append({"class": "ModuleScript", "name": e[:-4], "path": full})
    node["children"].append({"class": "Folder", "name": "Remotes", "children": [
        {"class": "RemoteFunction", "name": "Action"}]}) if name == "Headliner" else None
    return node
g.TREE = py_to_lua(tree(os.path.join(ROOT, "src", "Headliner"), "Headliner"))
g.MAIN_PATH = os.path.join(ROOT, "src", "client", "Main.client.lua")
g.SERVER_PATH = os.path.join(ROOT, "src", "server", "GameServer.server.lua")
lua.execute(open(sys.argv[2]).read())
errs = list(g.MOCK.errors.values())
print("\n==== RESULT:", "OK - no runtime errors" if not errs else f"{len(errs)} runtime error(s)")
sys.exit(1 if errs else 0)
