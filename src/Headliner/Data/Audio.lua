-- Roblox asset IDs of the uploaded audio files (folder audio/ in the project, made by tools/music/make_audio.py).
-- 0 = not uploaded yet: the game simply stays silent for that part.
-- Every artist file holds 12 songs of 30 s (song n starts at (n - 1) * 30 s), see Data/AudioMap.lua.
local Audio = {}

Audio.IDS = {
	menu = 0,
	sfx = 0,
	lila = 0,
	juno = 0,
	rusty = 0,
	voltage = 0,
	kai = 0,
	neon = 0,
	ironclad = 0,
	velvet = 0,
	luna = 0,
	dusty = 0,
	starlyte = 0,
	nova = 0,
}

return Audio
