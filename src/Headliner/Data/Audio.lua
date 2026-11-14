-- Roblox asset IDs of the uploaded audio files (folder audio/ in the project, made by tools/music/make_audio.py).
-- 0 = not uploaded yet: the game simply stays silent for that part.
-- Every artist file holds 12 songs of 30 s (song n starts at (n - 1) * 30 s), see Data/AudioMap.lua.
local Audio = {}

Audio.IDS = {
	menu = 102733154930319,
	sfx = 119428042172938,
	lila = 81723638120772,
	juno = 115464068768993,
	rusty = 110510340663014,
	voltage = 99620305358160,
	kai = 107157349335044,
	neon = 87721168005264,
	ironclad = 101275480792637,
	velvet = 123845710479345,
	luna = 74225603281313,
	dusty = 100901883872328,
	starlyte = 125180697119017,
	nova = 79935303723184,
}

return Audio
