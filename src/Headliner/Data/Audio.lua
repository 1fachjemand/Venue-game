-- Roblox asset IDs of the uploaded audio files (folder audio/ in the project, made by tools/music/make_audio.py).
-- 0 = not uploaded yet: the game simply stays silent for that part.
-- Every artist file holds 12 songs of 30 s (song n starts at (n - 1) * 30 s), see Data/AudioMap.lua.
local Audio = {}

Audio.IDS = {
	menu = 123393673750137,
	sfx = 119428042172938,
	lila = 79615076037073,
	juno = 102905097770073,
	rusty = 106077477782334,
	voltage = 88742464964477,
	kai = 132965588776987,
	neon = 118433531460119,
	ironclad = 131552906047910,
	velvet = 105665777573603,
	luna = 102018191320396,
	dusty = 137284398220708,
	starlyte = 139184253022183,
	nova = 75911027991327,
}

return Audio
