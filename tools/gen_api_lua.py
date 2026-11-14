# Converts the Roblox API dump into a compact Lua table used by the runtime mock (tools/mock_roblox.lua)
import json, sys
d = json.load(open(sys.argv[1]))
out = ["local CLASSES = {"]
def q(s): return '"' + s.replace('\\','\\\\').replace('"','\\"') + '"'
for c in d["Classes"]:
    props, events, funcs = [], [], []
    for m in c["Members"]:
        mt = m["MemberType"]
        if mt == "Property":
            vt = m["ValueType"]; tags = m.get("Tags") or []
            ro = "ReadOnly" in tags or "NotScriptable" in tags
            props.append(f'[{q(m["Name"])}]={{{q(vt["Category"])},{q(vt["Name"])},{str(ro).lower()}}}')
        elif mt == "Event": events.append(f'[{q(m["Name"])}]=true')
        elif mt in ("Function", "YieldFunction", "Callback"): funcs.append(f'[{q(m["Name"])}]=true')
    tags = c.get("Tags") or []
    sup = c["Superclass"]
    out.append(f'[{q(c["Name"])}]={{super={q(sup)},creatable={str("NotCreatable" not in tags).lower()},props={{{",".join(props)}}},events={{{",".join(events)}}},funcs={{{",".join(funcs)}}}}},')
out.append("}")
enums = ",".join('["%s"]={%s}' % (e["Name"], ",".join('"%s"' % i["Name"] for i in e["Items"])) for e in d["Enums"])
out.append("return { classes = CLASSES, enums = {" + enums + "} }")
open(sys.argv[2], "w").write("\n".join(out))
print("ok", len(d["Classes"]))
