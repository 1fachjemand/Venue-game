# Runs the pure-Lua game logic (Logic/*, Data/*) in a Lua 5.1 interpreter with a tiny Roblox `script`/`require` shim.
import sys, lupa.lua51 as L
lua = L.LuaRuntime(unpack_returned_tuples=True)
ROOT = "src/Headliner"
lua.execute(r'''
ROOT_DIR = "%s"
local cache = {}
local nodeMT = {}
local rootNode
local function makeNode(p) return setmetatable({_path = p}, nodeMT) end
nodeMT.__index = function(self, key)
  if key == "FindFirstAncestor" then return function() return rootNode end end
  return makeNode(rawget(self, "_path") .. "/" .. key)
end
rootNode = makeNode(ROOT_DIR)
ROOT = rootNode
function require(node)
  local p = rawget(node, "_path")
  if cache[p] then return cache[p] end
  local f = assert(loadfile(p .. ".lua"))
  setfenv(f, setmetatable({script = node}, {__index = _G}))
  local r = f(); cache[p] = r; return r
end
math.log10 = math.log10 or function(x) return math.log(x)/math.log(10) end
''' % ROOT)
lua.execute(open("tools/test_logic.lua").read())
