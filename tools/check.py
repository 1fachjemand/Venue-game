# Static checks for the Luau sources (we can't run Roblox here):
#  1) syntax (Lua 5.1 parser - the code avoids Luau-only syntax on purpose)
#  2) undefined variables (scope-aware AST walk)
#  3) Roblox API: classes, properties in New()/Instance.new() tables & assignments, Enum items, services, method names
import os, re, sys, json, glob
import lupa.lua51 as L
from luaparser import ast, astnodes as N

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = sys.argv[1] if len(sys.argv) > 1 else None
files = sorted(glob.glob(os.path.join(ROOT, "src", "**", "*.lua"), recursive=True))
errors = []
def err(f, msg): errors.append(f"{os.path.relpath(f, ROOT)}: {msg}")

# ---------- 1) syntax
lua = L.LuaRuntime()
compile_ = lua.eval("function(src, name) local f, e = loadstring(src, name) return e end")
for f in files:
    e = compile_(open(f).read(), os.path.basename(f))
    if e: err(f, "SYNTAX " + str(e))

# ---------- 2) undefined variables
ALLOWED = set("""game workspace script shared Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum TweenInfo NumberSequence
NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint NumberRange RaycastParams Random task math string table os
pairs ipairs require setmetatable getmetatable type tostring tonumber pcall error print warn next select unpack rawget
rawset typeof tick utf8 Ray Font Faces Axes""".split())
def check_globals(f, src):
    try:
        tree = ast.parse(src)
    except Exception as e:
        err(f, "PARSE " + str(e)[:200]); return
    def defined(name, scope):
        return any(name in s for s in scope)
    def visit_fn(args, body, scope, extra=()):
        scope.append(set(extra))
        for a in args:
            if isinstance(a, N.Name): scope[-1].add(a.id)
        visit(body, scope)
        scope.pop()
    def visit(node, scope):
        if node is None: return
        if isinstance(node, list):
            for n in node: visit(n, scope)
            return
        if not isinstance(node, N.Node): return
        if isinstance(node, N.Name):
            if not defined(node.id, scope) and node.id not in ALLOWED:
                err(f, f"UNDEFINED '{node.id}' line {node.line if hasattr(node,'line') else '?'}")
            return
        if isinstance(node, N.Index):
            visit(node.value, scope)
            if node.notation == N.IndexNotation.SQUARE: visit(node.idx, scope)
            return
        if isinstance(node, N.Invoke):
            visit(node.source, scope); visit(node.args, scope); return
        if isinstance(node, N.Field):
            if getattr(node, "between_brackets", False) or not isinstance(node.key, N.Name):
                visit(node.key, scope)
            visit(node.value, scope); return
        if isinstance(node, N.LocalAssign):
            visit(node.values, scope)
            for t in node.targets: scope[-1].add(t.id)
            return
        if isinstance(node, N.LocalFunction):
            scope[-1].add(node.name.id); visit_fn(node.args, node.body, scope); return
        if isinstance(node, N.Function):
            if isinstance(node.name, N.Name):
                if not defined(node.name.id, scope): err(f, f"GLOBAL FUNCTION '{node.name.id}'")
            else: visit(node.name, scope)
            visit_fn(node.args, node.body, scope); return
        if isinstance(node, N.Method):
            visit(node.source, scope); visit_fn(node.args, node.body, scope, ("self",)); return
        if isinstance(node, N.AnonymousFunction):
            visit_fn(node.args, node.body, scope); return
        if isinstance(node, N.Fornum):
            visit(node.start, scope); visit(node.stop, scope); visit(node.step, scope)
            scope.append({node.target.id}); visit(node.body, scope); scope.pop(); return
        if isinstance(node, N.Forin):
            visit(node.iter, scope)
            scope.append({t.id for t in node.targets}); visit(node.body, scope); scope.pop(); return
        if isinstance(node, N.Block):
            scope.append(set()); visit(node.body, scope); scope.pop(); return
        if isinstance(node, N.Assign):
            for t in node.targets:
                if isinstance(t, N.Name) and not defined(t.id, scope):
                    err(f, f"ASSIGN TO GLOBAL '{t.id}'")
                else: visit(t, scope)
            visit(node.values, scope); return
        for k, v in vars(node).items():
            if k in ("comments", "wrapped", "line", "start_char", "stop_char", "parent"): continue
            if isinstance(v, (N.Node, list)): visit(v, scope)
    visit(tree.body, [set()])

for f in files:
    check_globals(f, open(f).read())

# ---------- 3) Roblox API
if API:
    d = json.load(open(API))
    C = {c["Name"]: c for c in d["Classes"]}
    E = {e["Name"]: {i["Name"] for i in e["Items"]} for e in d["Enums"]}
    def members(cls):
        out = {}
        while cls and cls in C:
            for m in C[cls]["Members"]:
                out.setdefault(m["Name"], m)
            sup = C[cls]["Superclass"]
            cls = None if sup == "<<<ROOT>>>" else sup
        return out
    all_methods = set()
    for c in d["Classes"]:
        for m in c["Members"]:
            if m["MemberType"] in ("Function", "YieldFunction", "Event", "Callback"): all_methods.add(m["Name"])
    # datatype methods & Lua string methods & our own
    all_methods |= set("""Lerp Inverse ToWorldSpace ToObjectSpace PointToWorldSpace PointToObjectSpace VectorToWorldSpace Dot Cross
FuzzyEq Max Min Abs Floor Ceil Sign Angle NextInteger NextNumber NextUnitVector Shuffle Clone Connect Once Wait Disconnect
gsub sub find format upper lower rep reverse byte len match gmatch split Play Cancel Pause Emit Destroy""".split())
    own = set()
    for f in files:
        for m in re.finditer(r"function\s+[\w.]+[:.](\w+)\s*\(", open(f).read()): own.add(m.group(1))
        for m in re.finditer(r"\b(\w+)\s*=\s*function\b", open(f).read()): own.add(m.group(1))
    all_methods |= own

    def table_keys(src, start):
        # returns keys at depth 1 of the table literal starting at src[start] == '{'
        depth, i, keys, n = 0, start, [], len(src)
        while i < n:
            ch = src[i]
            if ch in "\"'":
                q = ch; i += 1
                while i < n and src[i] != q:
                    if src[i] == "\\": i += 1
                    i += 1
            elif src.startswith("--", i):
                while i < n and src[i] != "\n": i += 1
            elif ch in "{([":
                depth += 1
            elif ch in "})]":
                depth -= 1
                if depth == 0: return keys
            elif depth == 1:
                m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", src[i:])
                if m and (i == 0 or not (src[i-1].isalnum() or src[i-1] in "_.")):
                    keys.append(m.group(1)); i += m.end() - 1
            i += 1
        return keys

    def check_prop(f, cls, key, where):
        mem = members(cls).get(key)
        if key == "Parent": return
        if not mem or mem["MemberType"] != "Property":
            err(f, f"API: {cls}.{key} is not a property ({where})"); return
        tags = mem.get("Tags") or []
        if "ReadOnly" in tags or "NotScriptable" in tags:
            err(f, f"API: {cls}.{key} is {tags} ({where})")
        if "Deprecated" in tags:
            err(f, f"API (warning): {cls}.{key} is deprecated ({where})")

    for f in files:
        src = open(f).read()
        lines = src.split("\n")
        # New("Class", {...}) and UI.New(...)
        for m in re.finditer(r"\bNew\(\s*\"(\w+)\"\s*(,\s*)?", src):
            cls = m.group(1)
            line = src.count("\n", 0, m.start()) + 1
            if cls not in C: err(f, f"API: unknown class {cls} line {line}"); continue
            if "NotCreatable" in (C[cls].get("Tags") or []): err(f, f"API: {cls} not creatable line {line}")
            if m.group(2):
                j = m.end()
                if src[j] == "{":
                    for k in table_keys(src, j): check_prop(f, cls, k, f"line {line}")
        for m in re.finditer(r"Instance\.new\(\"(\w+)\"\)", src):
            if m.group(1) not in C: err(f, f"API: unknown class {m.group(1)}")
        # variable class tracking: local x = New("Class" ...) / Instance.new
        var_cls = {}
        for ln, text in enumerate(lines, 1):
            m = re.match(r"\s*(?:local\s+)?([\w.]+)\s*=\s*(?:UI\.)?(?:New|Instance\.new)\(\s*\"(\w+)\"", text)
            if m: var_cls[m.group(1)] = m.group(2); continue
            m = re.match(r"\s*(?:local\s+)?([\w.]+)\s*=\s*(.+)$", text)
            if m and m.group(1) in var_cls and "New(" not in text and not text.strip().startswith(m.group(1) + "."):
                pass
            for a in re.finditer(r"\b([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)*)\.([A-Z]\w*)\s*=(?!=)", text):
                obj, prop = a.group(1), a.group(2)
                if obj in var_cls: check_prop(f, var_cls[obj], prop, f"line {ln}")
        # Enums
        for m in re.finditer(r"\bEnum\.(\w+)\.(\w+)", src):
            en, it = m.groups()
            if en not in E: err(f, f"API: unknown Enum.{en}")
            elif it not in E[en]: err(f, f"API: Enum.{en}.{it} does not exist")
        # services
        for m in re.finditer(r"GetService\(\"(\w+)\"\)", src):
            if m.group(1) not in C: err(f, f"API: unknown service {m.group(1)}")
        # method names
        for m in re.finditer(r":([A-Za-z_]\w*)\s*\(", src):
            if m.group(1) not in all_methods:
                line = src.count("\n", 0, m.start()) + 1
                err(f, f"API: unknown method :{m.group(1)}() line {line}")
        # well-known property reads on services
        for m in re.finditer(r"\b(Lighting|UserInputService)\.([A-Z]\w*)", src):
            cls = m.group(1)
            if m.group(2) not in members(cls): err(f, f"API: {cls}.{m.group(2)} unknown")

print("\n".join(errors) if errors else "No problems found.")
print(f"checked {len(files)} files, {len(errors)} issue(s)")
