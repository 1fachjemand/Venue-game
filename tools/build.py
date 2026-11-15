# Builds Headliner.rbxlx (Roblox XML place file) from ./src
import os, uuid, html
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "Headliner.rbxlx")

def ref():
    return "RBX" + uuid.uuid4().hex.upper()

def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, props="", children=""):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{html.escape(name)}</string>{props}</Properties>{children}</Item>\n')

def script_item(cls, name, path):
    src = open(path, encoding="utf-8").read()
    props = f'<ProtectedString name="Source">{cdata(src)}</ProtectedString>'
    if cls != "ModuleScript":
        props = '<bool name="Disabled">false</bool>' + props
    return item(cls, name, props)

def folder_tree(path, name):
    children = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children += item("Folder", entry, "", folder_tree(full, entry))
        elif entry.endswith(".lua"):
            children += script_item("ModuleScript", entry[:-4], full)
    return children

def build():
    hl = folder_tree(os.path.join(SRC, "Headliner"), "Headliner")
    remotes = item("Folder", "Remotes", "", item("RemoteFunction", "Action"))
    headliner = item("Folder", "Headliner", "", hl + remotes)
    xml = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n',
           '<External>null</External>\n<External>nil</External>\n',
           item("Workspace", "Workspace", '<bool name="StreamingEnabled">false</bool>'),
           item("Lighting", "Lighting", '<token name="Technology">4</token><bool name="GlobalShadows">false</bool>'),
           item("Players", "Players", '<bool name="CharacterAutoLoads">false</bool>'),
           item("ReplicatedStorage", "ReplicatedStorage", "", headliner),
           item("ServerScriptService", "ServerScriptService", "", script_item("Script", "GameServer", os.path.join(SRC, "server", "GameServer.server.lua"))),
           item("StarterPlayer", "StarterPlayer", "", item("StarterPlayerScripts", "StarterPlayerScripts", "", script_item("LocalScript", "Main", os.path.join(SRC, "client", "Main.client.lua")))),
           '</roblox>\n']
    open(OUT, "w", encoding="utf-8").write("".join(xml))
    print("wrote", OUT, os.path.getsize(OUT), "bytes")

if __name__ == "__main__":
    build()
