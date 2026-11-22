-- Music and sound effects. Every sound is a part (PlaybackRegion) of a few uploaded files, see Data/Audio.lua.
-- Without uploaded IDs every function quietly does nothing.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Root = script:FindFirstAncestor("Headliner")
local Audio = require(Root.Data.Audio)
local Map = require(Root.Data.AudioMap)
local UI = require(Root.Client.UI)

local New = UI.New
local SoundFX = {}

local groups = {}
local sfxSounds = {}
local channels = {} -- music: two sounds for cross-fades
local active = 1
local ambience = nil
local currentKey = nil

local function id(key)
	local n = Audio.IDS[key]
	if n == nil then
		-- a newer artist without an own recording plays the songs of a similar artist
		local ad = require(Root.Data.Artists).byId[key]
		n = ad and ad.audio and Audio.IDS[ad.audio]
	end
	if type(n) ~= "number" or n <= 0 then
		return nil
	end
	return "rbxassetid://" .. n
end

local function fade(sound, to, t, stopAfter)
	local tw = TweenService:Create(sound, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = to })
	tw:Play()
	if stopAfter then
		task.delay(t, function()
			if sound.Volume <= 0.01 then
				sound:Stop()
			end
		end)
	end
end

local function setRegion(sound, start, len, loop)
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(start, start + len)
	sound.LoopRegion = NumberRange.new(start, start + len)
	sound.Looped = loop == true
	sound.TimePosition = start
end

function SoundFX.init(settings)
	if groups.music then
		return
	end
	groups.music = New("SoundGroup", { Name = "HeadlinerMusic", Volume = 0.5, Parent = SoundService })
	groups.sfx = New("SoundGroup", { Name = "HeadlinerEffects", Volume = 0.6, Parent = SoundService })
	for i = 1, 2 do
		channels[i] = New("Sound", { Name = "Music" .. i, SoundGroup = groups.music, Volume = 0, Parent = SoundService })
	end
	ambience = New("Sound", { Name = "Crowd", SoundGroup = groups.sfx, Volume = 0, Parent = SoundService })
	if settings then
		SoundFX.setFlags(settings)
		SoundFX.setVolumes(settings.music, settings.effects)
	end
	-- every button click makes a sound
	UI.onClick = function()
		SoundFX.sfx("click", 0.7)
	end
	UI.onHover = function()
		SoundFX.sfx("hover", 0.25)
	end
end

-- what may play (settings): menu & office music, concert music, music while building, click sounds
SoundFX.flags = { menu = true, show = true, build = true, ui = true }
SoundFX.context = "menu" -- "menu" (main menu and the label building) | "show" | "build"
local musicVol, fxVol = 80, 80
local function applyVolumes()
	if groups.music then
		local on = SoundFX.flags[SoundFX.context] ~= false
		groups.music.Volume = on and (musicVol / 100 * 0.7) or 0
		groups.sfx.Volume = fxVol / 100 * 0.8
	end
end
-- music / effects volume 0..100 (settings)
function SoundFX.setVolumes(music, effects)
	musicVol, fxVol = music or 80, effects or 80
	applyVolumes()
end

-- where we are: "menu" (menu, office), "show" (a concert), "build" (stage builder)
function SoundFX.setContext(ctx)
	SoundFX.context = ctx or "menu"
	applyVolumes()
end
-- settings: { menuMusic, showMusic, buildMusic, uiSounds } (true / false)
function SoundFX.setFlags(st)
	if type(st) ~= "table" then
		return
	end
	SoundFX.flags.menu = st.menuMusic ~= false
	SoundFX.flags.show = st.showMusic ~= false
	SoundFX.flags.build = st.buildMusic ~= false
	SoundFX.flags.ui = st.uiSounds ~= false
	applyVolumes()
end

function SoundFX.sfx(name, volume)
	if (name == "click" or name == "hover") and not SoundFX.flags.ui then
		return
	end
	local sid = id("sfx")
	local r = Map.SFX and Map.SFX[name]
	if not sid or not r or not groups.sfx then
		return
	end
	local s = sfxSounds[name]
	if not s then
		s = New("Sound", { Name = "Sfx_" .. name, SoundId = sid, SoundGroup = groups.sfx, Parent = SoundService })
		sfxSounds[name] = s
	end
	setRegion(s, r[1], r[2], false)
	s.Volume = volume or 1
	s:Play()
end

-- plays a part of a file on the music channel (cross-fade from what played before)
local function playRegion(fileKey, start, len, loop, volume, key)
	local sid = id(fileKey)
	if not sid or not groups.music then
		return
	end
	if key and key == currentKey and channels[active].IsPlaying then
		return
	end
	currentKey = key
	local old = channels[active]
	active = 3 - active
	local s = channels[active]
	if old.IsPlaying then
		fade(old, 0, 1.2, true)
	end
	s.SoundId = sid
	setRegion(s, start, len, loop)
	s.Volume = 0
	s:Play()
	fade(s, volume or 1, 0.8)
end

-- "title" (main menu) or "office" (game screens)
function SoundFX.menu(which)
	local r = Map.MENU and Map.MENU[which]
	if r then
		playRegion("menu", r[1], r[2], true, (which == "office") and 0.6 or 0.9, "menu_" .. which)
		if channels[active] then
			channels[active].PlaybackSpeed = 1
		end
	end
end

-- recordings that sound alike (a long setlist borrows songs from these, a little faster or slower)
local SIMILAR = {
	juno = { "nova", "starlyte" }, nova = { "juno", "starlyte" }, starlyte = { "juno", "nova" },
	rusty = { "neon", "ironclad" }, neon = { "lila", "rusty" }, ironclad = { "rusty", "voltage" },
	lila = { "neon", "dusty" }, dusty = { "lila", "rusty" }, voltage = { "kai", "starlyte" },
	kai = { "velvet", "voltage" }, velvet = { "kai", "luna" }, luna = { "velvet", "juno" },
}
local function hashOf(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 100003
	end
	return h
end
-- where song n of an artist is: { file key, start (s), playback speed }. Songs 1..12 are the artist's own
-- recording (an artist without an own one uses a similar artist's, a little faster or slower so two artists
-- never sound the same); songs 13+ come from similar recordings, so a long show never repeats a song.
function SoundFX.songSource(artistId, n)
	local per = Map.SONGS_PER_FILE or 12
	local len = Map.SONG_LEN or 30
	local ad = require(Root.Data.Artists).byId[artistId]
	local own = (Audio.IDS[artistId] ~= nil) and artistId or (ad and ad.audio) or artistId
	local h = hashOf(artistId)
	local speed = 1
	if own ~= artistId then
		speed = ({ 0.94, 0.97, 1.03, 1.06 })[h % 4 + 1]
	end
	if n <= per then
		return own, (n - 1) * len, speed
	end
	local sims = SIMILAR[own] or { own }
	local k = math.floor((n - 1) / per) -- 1, 2 ...
	local file = sims[(k - 1) % #sims + 1]
	local idx = ((n - 1) % per + (h % 5)) % per + 1
	local s2 = ({ 0.95, 1.05, 0.97, 1.03 })[(h + k) % 4 + 1]
	return file, (idx - 1) * len, s2
end

-- recordings that did not load (e.g. an upload Roblox has not approved): they are skipped from then on
SoundFX.broken = {}
-- song n of an artist, e.g. during a show
function SoundFX.song(artistId, n, volume)
	local len = Map.SONG_LEN or 30
	local file, start, speed = SoundFX.songSource(artistId, n)
	if SoundFX.broken[file] then
		-- this recording does not work: a similar one plays instead (never a silent show)
		for _, alt in ipairs(SIMILAR[file] or {}) do
			if not SoundFX.broken[alt] then
				file = alt
				break
			end
		end
	end
	local key = artistId .. "_" .. n .. "_" .. tostring(os.clock())
	playRegion(file, start, len, false, volume or 1, key)
	local s = channels[active]
	if s and s.SoundId ~= "" then
		s.PlaybackSpeed = speed or 1
		-- still not loaded after a few seconds: mark it and play the song from a similar recording
		task.delay(4, function()
			if currentKey == key and s.TimeLength == 0 and not SoundFX.broken[file] then
				SoundFX.broken[file] = true
				warn("[Headliner] audio '" .. tostring(file) .. "' did not load (is the upload approved?); using a similar recording")
				SoundFX.song(artistId, n, volume)
			end
		end)
	end
end

-- listen to an artist (their big hit), then back to the office music
function SoundFX.preview(artistId)
	if not id(artistId) then
		return false
	end
	SoundFX.song(artistId, Map.HIT_INDEX or 8, 1)
	local token = os.clock()
	SoundFX.previewToken = token
	task.delay(22, function()
		if SoundFX.previewToken == token then
			SoundFX.menu("office")
		end
	end)
	return true
end

function SoundFX.stopMusic(t)
	currentKey = nil
	for _, s in ipairs(channels) do
		if s.IsPlaying then
			fade(s, 0, t or 1, true)
		end
	end
end

-- crowd noise under a show (volume 0..1, 0 = off)
function SoundFX.crowd(volume)
	local sid = id("sfx")
	local r = Map.SFX and Map.SFX.crowd
	if not sid or not r or not ambience then
		return
	end
	if volume and volume > 0 then
		if not ambience.IsPlaying then
			ambience.SoundId = sid
			setRegion(ambience, r[1], r[2], true)
			ambience:Play()
		end
		fade(ambience, volume, 1)
	elseif ambience.IsPlaying then
		fade(ambience, 0, 1.5, true)
	end
end

function SoundFX.available()
	return id("sfx") ~= nil or id("menu") ~= nil
end

return SoundFX
