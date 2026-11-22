-- Stage design catalog.
-- cost  = production cost per show (crew, transport, power)
-- pts   = production value points (more points = more impressive show)
-- tags  = used for genre bonuses
-- mount = "floor" (stands on the stage deck / ground) or "rig" (hangs from the lighting rig)
-- deck  = true if performers can walk on it (other items can be placed on top)

local StageItems = {}

StageItems.CATEGORIES = {
	{ id = "Stage", name = "Stage" },
	{ id = "Artist", name = "Artist" },
	{ id = "Band", name = "Band" },
	{ id = "Lights", name = "Lights" },
	{ id = "Screens", name = "Screens" },
	{ id = "FX", name = "Effects" },
	{ id = "Set", name = "Set Pieces" },
	{ id = "Decor", name = "Decor" },
	{ id = "Shapes", name = "Shapes" },
}

-- Up to this many artist spots (= songs in the setlist)
StageItems.MAX_SPOTS = 20

local H = { 1, 2, 4, 6, 8, 10, 14 }
StageItems.list = {
	-- Stage structure. "size" = resizable (w = width along x, d = depth along z); decks have selectable heights.
	{ id = "deck", name = "Stage Deck", cat = "Stage", cost = 600, pts = 3, tags = {}, mount = "floor", deck = true, shape = "rect", size = { w = 16, d = 12, minW = 4, maxW = 160, minD = 4, maxD = 120 }, h = 6, heights = H, desc = "Rectangular platform. Resize, rotate and stack it to build any stage, runway or B-stage." },
	{ id = "deck_tri", name = "Triangle Deck", cat = "Stage", cost = 500, pts = 3, tags = { "intimate" }, mount = "floor", deck = true, shape = "tri", size = { w = 16, d = 16, minW = 4, maxW = 80, minD = 4, maxD = 80 }, h = 6, heights = H, desc = "Triangle platform (tip points forward). Great for triangle catwalks." },
	{ id = "deck_corner", name = "Corner Deck", cat = "Stage", cost = 400, pts = 2, tags = {}, mount = "floor", deck = true, shape = "corner", size = { w = 12, d = 12, minW = 4, maxW = 60, minD = 4, maxD = 60 }, h = 6, heights = H, desc = "Right-angled triangle for diagonal corners and angled runways." },
	{ id = "deck_corner_r", name = "Corner Deck (right)", cat = "Stage", cost = 400, pts = 2, tags = {}, mount = "floor", deck = true, shape = "corner", size = { w = 12, d = 12, minW = 4, maxW = 60, minD = 4, maxD = 60 }, h = 6, heights = H, desc = "The same right-angled triangle, the other way round (the corner on the right)." },
	{ id = "deck_oct", name = "Octagon Deck", cat = "Stage", cost = 800, pts = 4, tags = { "spectacle" }, mount = "floor", deck = true, shape = "oct", size = { w = 20, d = 20, minW = 6, maxW = 120, minD = 6, maxD = 120 }, h = 6, heights = H, desc = "Eight sides: a strong centre stage or B-stage." },
	{ id = "deck_hex", name = "Hexagon Deck", cat = "Stage", cost = 750, pts = 4, tags = {}, mount = "floor", deck = true, shape = "hex", size = { w = 20, d = 17, minW = 6, maxW = 120, minD = 6, maxD = 120 }, h = 6, heights = H, desc = "Six sides, pointed left and right. Put several together like a honeycomb." },
	{ id = "deck_trap", name = "Trapezoid Deck", cat = "Stage", cost = 650, pts = 3, tags = {}, mount = "floor", deck = true, shape = "trap", size = { w = 24, d = 12, minW = 6, maxW = 160, minD = 4, maxD = 80 }, h = 6, heights = H, desc = "Wide at the back, half as wide at the front: a stage that narrows into a runway." },
	{ id = "deck_half", name = "Half Round Deck", cat = "Stage", cost = 700, pts = 4, tags = { "intimate" }, mount = "floor", deck = true, shape = "half", size = { w = 24, minW = 6, maxW = 120 }, h = 6, heights = H, desc = "A half circle: the flat side at the back, the round side towards the fans." },
	{ id = "deck_ring", name = "Ring Deck", cat = "Stage", cost = 1400, pts = 6, tags = { "spectacle" }, mount = "floor", deck = true, shape = "ring", size = { w = 40, minW = 16, maxW = 160 }, h = 6, heights = H, desc = "A round runway around a hole: fans in the middle, the artist walks all the way round." },
	{ id = "deck_rounded", name = "Rounded Deck", cat = "Stage", cost = 650, pts = 3, tags = {}, mount = "floor", deck = true, shape = "rounded", size = { w = 20, d = 14, minW = 6, maxW = 160, minD = 6, maxD = 120 }, h = 6, heights = H, desc = "A rectangle with soft round corners." },
	{ id = "deck_round", name = "Round Deck", cat = "Stage", cost = 700, pts = 4, tags = { "spectacle" }, mount = "floor", deck = true, shape = "round", size = { w = 16, minW = 6, maxW = 100 }, h = 6, heights = H, desc = "Round platform: a B-stage or the heart of a center stage." },
	{ id = "stairs", name = "Stairs", cat = "Stage", cost = 300, pts = 0, tags = {}, mount = "floor", deck = true, shape = "stairs", size = { w = 6, d = 8, minW = 3, maxW = 30, minD = 3, maxD = 30 }, h = 6, heights = { 2, 4, 6, 8, 10, 14 }, desc = "Steps up to a higher deck. The low end points to the front." },
	-- shapes to build your own things: any size, any colour (colour wheel), any material
	{ id = "prim_block", name = "Block", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 4, d = 4, minW = 0.5, maxW = 200, minD = 0.5, maxD = 200 }, h = 4, freeH = { 0.5, 120 }, desc = "A block. Pull the handles for any size, Style for colour and material." },
	{ id = "prim_cyl", name = "Cylinder", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 4, minW = 0.5, maxW = 120 }, h = 4, freeH = { 0.5, 120 }, desc = "A standing cylinder: pillars, podiums, drums, poles." },
	{ id = "prim_ball", name = "Ball", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 4, d = 4, minW = 0.5, maxW = 120, minD = 0.5, maxD = 120 }, h = 4, freeH = { 0.5, 120 }, desc = "A ball (stretch it into an egg or a lens)." },
	{ id = "prim_wedge", name = "Wedge", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 4, d = 4, minW = 0.5, maxW = 200, minD = 0.5, maxD = 200 }, h = 4, freeH = { 0.5, 120 }, desc = "A ramp / wedge." },
	{ id = "prim_corner", name = "Corner Wedge", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 4, d = 4, minW = 0.5, maxW = 200, minD = 0.5, maxD = 200 }, h = 4, freeH = { 0.5, 120 }, desc = "A corner of a pyramid." },
	{ id = "prim_tube", name = "Ring", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 8, minW = 2, maxW = 120 }, h = 1, freeH = { 0.3, 20 }, desc = "A flat ring: halos, frames, portals (turn it upright with a Block behind)." },
	{ id = "prim_disc", name = "Disc", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 6, minW = 0.5, maxW = 120 }, h = 0.4, freeH = { 0.1, 6 }, desc = "A thin round plate: table tops, round platforms, halos." },
	{ id = "prim_cone", name = "Cone", cat = "Shapes", cost = 80, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 4, minW = 0.5, maxW = 120 }, h = 6, freeH = { 0.5, 120 }, desc = "A smooth cone: towers, trees, party hats, spikes." },
	{ id = "prim_frustum", name = "Cut Cone", cat = "Shapes", cost = 80, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 6, minW = 0.5, maxW = 120 }, h = 4, freeH = { 0.5, 120 }, desc = "A cone with a flat top: podiums, lamp shades, skirts." },
	{ id = "prim_pyramid", name = "Pyramid", cat = "Shapes", cost = 80, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 6, minW = 0.5, maxW = 160 }, h = 5, freeH = { 0.5, 120 }, desc = "A square pyramid." },
	{ id = "prim_dome", name = "Dome", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 8, minW = 1, maxW = 160 }, h = 4, freeH = { 0.5, 80 }, desc = "Half a ball: domes, igloos, bells (taller or flatter with the top handle)." },
	{ id = "prim_hex", name = "Hexagon", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 6, minW = 0.5, maxW = 120 }, h = 2, freeH = { 0.2, 120 }, desc = "A hexagon column or plate." },
	{ id = "prim_oct", name = "Octagon", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 6, minW = 0.5, maxW = 120 }, h = 2, freeH = { 0.2, 120 }, desc = "An octagon column or plate." },
	{ id = "prim_pipe", name = "Pipe", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 10, d = 1, minW = 0.5, maxW = 200, minD = 0.2, maxD = 40 }, desc = "A cylinder lying down: pipes, logs, rails, rollers." },
	{ id = "prim_halfcyl", name = "Half Cylinder", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 10, d = 6, minW = 0.5, maxW = 200, minD = 0.5, maxD = 80 }, desc = "Half a cylinder, round side up: tunnels, humps, roofs." },
	{ id = "prim_arch", name = "Arch", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 10, d = 1, minW = 1, maxW = 160, minD = 0.2, maxD = 40 }, h = 12, freeH = { 1, 120 }, desc = "A standing arch: doorways, portals, bridges (width, depth and height)." },
	{ id = "prim_curve", name = "Curved Wall", cat = "Shapes", cost = 80, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 12, minW = 2, maxW = 160 }, h = 8, freeH = { 0.5, 120 }, desc = "A quarter of a round wall (the size is its radius)." },
	{ id = "prim_prism", name = "Prism", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 8, d = 4, minW = 0.5, maxW = 200, minD = 0.5, maxD = 120 }, h = 3, freeH = { 0.3, 120 }, desc = "A triangular prism lying down: roofs, tents, ramps both ways." },
	{ id = "prim_star", name = "Star", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 6, d = 0.6, minW = 1, maxW = 120, minD = 0.1, maxD = 20 }, desc = "A five-pointed star standing upright." },
	{ id = "prim_heart", name = "Heart", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 6, d = 0.6, minW = 1, maxW = 120, minD = 0.1, maxD = 20 }, desc = "A heart standing upright." },
	{ id = "prim_frame", name = "Frame", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 8, d = 0.6, minW = 1, maxW = 200, minD = 0.1, maxD = 30 }, h = 10, freeH = { 1, 120 }, desc = "An empty frame standing upright: picture frames, windows, doors." },
	{ id = "prim_cross", name = "Plus", cat = "Shapes", cost = 60, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 6, d = 0.6, minW = 1, maxW = 120, minD = 0.1, maxD = 20 }, h = 6, freeH = { 1, 120 }, desc = "A plus sign standing upright." },
	{ id = "prim_steps", name = "Step Block", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 6, d = 6, minW = 1, maxW = 120, minD = 1, maxD = 60 }, h = 4, freeH = { 0.8, 40 }, desc = "A block with steps (in your own colour and material)." },
	{ id = "prim_torus", name = "Torus", cat = "Shapes", cost = 90, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, shape = "round", size = { w = 10, minW = 1, maxW = 120 }, h = 1, freeH = { 0.2, 20 }, desc = "A ring with a round cross-section (a doughnut): halos, life rings, wreaths." },
	{ id = "prim_capsule", name = "Capsule", cat = "Shapes", cost = 70, pts = 0, tags = {}, mount = "floor", deck = false, prim = true, size = { w = 8, d = 2, minW = 1, maxW = 120, minD = 0.3, maxD = 40 }, desc = "A pill shape lying down." },
	-- old item, kept for saved stages only (crowd barriers are now part of every venue)
	{ id = "pit", name = "Pit Barrier", cat = "Stage", hidden = true, cost = 800, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 20, d = 12, minW = 6, maxW = 80, minD = 6, maxD = 80 }, desc = "Fenced VIP pit on the floor. Fans fill the pit first." },
	{ id = "truss_beam", name = "Truss Beam", cat = "Stage", cost = 300, pts = 1, tags = {}, mount = "rig", deck = false, size = { w = 24, minW = 8, maxW = 240 }, desc = "Horizontal truss in the rig. Lights snap onto it." },
	{ id = "stadiumroof", name = "Stadium Structure", cat = "Stage", cost = 25000, pts = 22, tags = { "spectacle" }, mount = "floor", ground = true, deck = false, size = { w = 140, d = 64, minW = 60, maxW = 240, minD = 40, maxD = 95, dLabel = "Height" }, desc = "The giant scaffold of a stadium tour: two towers with PA hangs, a roof with lights and covered wings. Stands on the ground over the stage, side lights clamp onto its front columns." },
	{ id = "delaytower", name = "Delay Tower", cat = "Stage", cost = 3000, pts = 4, tags = {}, mount = "floor", deck = false, desc = "Speaker and follow-spot tower in the crowd, so the back rows of a stadium hear the show too." },
	{ id = "truss", name = "Truss Tower", cat = "Stage", cost = 400, pts = 1, tags = {}, mount = "floor", deck = false, desc = "Vertical truss tower. Always reaches up to the rig, so truss beams can rest on it." },
	{ id = "truss_xl", name = "Heavy Truss Tower", cat = "Stage", cost = 1800, pts = 3, tags = { "spectacle" }, mount = "floor", deck = false, desc = "Wide box truss tower for arenas and stadiums with a heavy base. Reaches the rig, side lights and speakers clamp onto it." },
	{ id = "sidespeaker", name = "Hanging Speakers", cat = "Stage", cost = 900, pts = 3, tags = {}, mount = "side", deck = false, desc = "Line array hanging on the side of a Truss Tower, like at big shows. Put it on a tower and lift it up." },
	{ id = "speakers", name = "Speaker Stack", cat = "Stage", cost = 400, pts = 2, tags = {}, mount = "floor", deck = false, desc = "Subwoofers with a line array on top." },
	-- Artist: where the artist performs and what they play
	{ id = "spot", name = "Artist Spot", cat = "Artist", cost = 0, pts = 0, tags = {}, mount = "floor", deck = false, desc = "One spot = one song. The artist walks to spot 1 for the first song, spot 2 for the second, and so on. More spots = longer setlist (up to 12)." },
	{ id = "lift", name = "Artist Lift", cat = "Artist", cost = 6000, pts = 12, tags = { "spectacle" }, mount = "floor", deck = false, desc = "The artist rises out of the stage. Choose the song it is used for." },
	{ id = "poplift", name = "Pop-Up Lift", cat = "Artist", cost = 8500, pts = 14, tags = { "spectacle", "energy" }, mount = "floor", deck = false, desc = "Toaster lift: a trapdoor opens and the artist is shot up onto the stage in a burst of sparks and CO2. Choose the song." },
	{ id = "towerlift", name = "Tower Lift", cat = "Artist", cost = 12000, pts = 16, tags = { "spectacle", "intimate" }, mount = "floor", deck = false, desc = "Round B-stage platform on a telescopic column. During its song it lifts the artist high above the crowd. Put it at the end of a runway or in the crowd." },
	{ id = "scissor", name = "Scissor Lift", cat = "Artist", cost = 7500, pts = 12, tags = { "spectacle" }, mount = "floor", deck = false, desc = "Platform that rises high during the finale." },
	{ id = "piano", name = "Grand Piano", cat = "Artist", cost = 1500, pts = 4, tags = { "intimate" }, mount = "floor", deck = false, desc = "Black grand piano. The artist can play it during one song." },
	{ id = "keys", name = "Keyboard Rig", cat = "Artist", cost = 1100, pts = 3, tags = { "intimate", "band" }, mount = "floor", deck = false, desc = "Two keyboards on a stand, like a B-stage acoustic moment." },
	{ id = "drums", name = "Drum Kit", cat = "Artist", cost = 900, pts = 3, tags = { "band" }, mount = "floor", deck = false, desc = "Drum riser with kit. Bands use it, solo artists can play it in one song." },
	{ id = "djbooth", name = "DJ Booth", cat = "Artist", cost = 1500, pts = 4, tags = { "dj" }, mount = "floor", deck = false, desc = "DJ table with LED front." },
	{ id = "acoustic", name = "Acoustic Set", cat = "Artist", cost = 900, pts = 4, tags = { "intimate" }, mount = "floor", deck = false, desc = "Stool, mic and an acoustic guitar for the quiet part of the show. Choose the song the artist plays it in." },
	{ id = "harp", name = "Concert Harp", cat = "Artist", cost = 2400, pts = 5, tags = { "intimate" }, mount = "floor", deck = false, desc = "Golden concert harp. The artist can play it in one song." },
	{ id = "upright_bass", name = "Double Bass", cat = "Artist", cost = 900, pts = 2, tags = { "band", "retro" }, mount = "floor", deck = false, desc = "Upright bass on its stand for jazzy and acoustic sets." },
	{ id = "strings", name = "String Section", cat = "Artist", cost = 2600, pts = 6, tags = { "intimate", "spectacle" }, mount = "floor", deck = false, desc = "Four chairs with music stands, violins and cellos." },
	{ id = "horns", name = "Horn Section", cat = "Artist", cost = 2200, pts = 5, tags = { "band", "party" }, mount = "floor", deck = false, desc = "Trumpet, saxophone and trombone on stands with lit music desks." },
	{ id = "choir", name = "Choir Risers", cat = "Artist", cost = 1800, pts = 4, tags = { "spectacle", "intimate" }, mount = "floor", deck = false, desc = "Curved three-step risers for a choir or dancers, with glowing edges." },
	-- Band: live musicians who play the whole show next to the artist (the artist keeps their own instruments)
	{ id = "band_drums", name = "Band Drummer", cat = "Band", cost = 1400, pts = 4, tags = { "band" }, mount = "floor", deck = false, desc = "A drummer on a riser who plays the whole show. The artist's own drum kit (Artist tab) stays free for the artist." },
	{ id = "band_guitar", name = "Band Guitarist", cat = "Band", cost = 1000, pts = 3, tags = { "band" }, mount = "floor", deck = false, desc = "A guitarist with an amp and pedals, playing every song." },
	{ id = "band_bass", name = "Band Bassist", cat = "Band", cost = 1000, pts = 3, tags = { "band" }, mount = "floor", deck = false, desc = "A bass player with a big bass cabinet." },
	{ id = "band_keys", name = "Band Keyboarder", cat = "Band", cost = 1100, pts = 3, tags = { "band", "intimate" }, mount = "floor", deck = false, desc = "Keys player behind two keyboards." },
	{ id = "band_backing", name = "Backing Singer", cat = "Band", cost = 700, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, desc = "Backing vocals: sings and dances along to every song." },
	{ id = "showerstage", name = "Shower Stage", cat = "Artist", cost = 24000, pts = 20, tags = { "spectacle", "intimate" }, mount = "floor", deck = false, desc = "A round B-stage under a giant chrome rain shower. In its song the artist walks onto it, the shower head lights up and a few seconds later the rain pours down on them (wet floor, mist, splashes)." },
	{ id = "flyharness", name = "Flying Harness", cat = "Artist", cost = 30000, pts = 22, tags = { "spectacle" }, mount = "rig", deck = false, desc = "A winch on a track in the rig. In its song the artist is lifted up and flies out over the front of the stage and back." },
	{ id = "descendcube", name = "Glass Cube Lift", cat = "Artist", cost = 22000, pts = 18, tags = { "spectacle", "screens" }, mount = "rig", deck = false, desc = "A glass cube on a plinth. In its song the artist walks in, the glass walls roll down, the cube lifts them high above the stage on four cables and brings them back down." },
	{ id = "gownriser", name = "Gown Riser", cat = "Artist", cost = 26000, pts = 20, tags = { "spectacle" }, mount = "floor", deck = false, desc = "A giant dress. In its song the artist steps onto the round hem in the middle, then the dress grows out of the stage around them in four layers and lifts them about 18 studs high. It goes back down at the end of the song." },
	{ id = "floatplat", name = "Floating Platform", cat = "Artist", cost = 28000, pts = 21, tags = { "spectacle", "intimate" }, mount = "floor", deck = false, desc = "A round platform on four cables. In its song it waits until the artist stands on it, then lifts them straight up; up there every artist has their own pose (lying down, sitting on the edge, kneeling ...)." },
	{ id = "micstand", name = "Mic Stand", cat = "Artist", cost = 150, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Classic microphone stand." },
	{ id = "amps", name = "Amp Stack", cat = "Artist", cost = 500, pts = 2, tags = { "band", "retro" }, mount = "floor", deck = false, desc = "Wall of guitar amps." },
	{ id = "guitarstand", name = "Guitar Stand", cat = "Artist", cost = 200, pts = 1, tags = { "band" }, mount = "floor", deck = false, desc = "Spare guitar on a stand." },
	{ id = "wedge", name = "Monitor Wedge", cat = "Artist", cost = 150, pts = 1, tags = {}, mount = "floor", deck = false, desc = "Floor speaker so the artist hears the band." },
	{ id = "congas", name = "Percussion", cat = "Artist", cost = 600, pts = 2, tags = { "band", "party" }, mount = "floor", deck = false, desc = "Congas and a cymbal for the percussionist." },
	{ id = "stool", name = "Bar Stool", cat = "Artist", cost = 80, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "High stool for an acoustic moment." },
	{ id = "chair", name = "Chair", cat = "Artist", cost = 80, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Simple wooden chair." },
	-- Lights
	{ id = "par", name = "PAR Wash", cat = "Lights", cost = 150, pts = 2, tags = { "lights" }, mount = "rig", deck = false, desc = "Coloured wash light." },
	{ id = "moving", name = "Moving Head", cat = "Lights", cost = 900, pts = 4, tags = { "lights" }, mount = "rig", deck = false, desc = "Sweeping beam light." },
	{ id = "beambar", name = "Beam Light", cat = "Lights", cost = 800, pts = 4, tags = { "lights" }, mount = "floor", deck = false, desc = "Floor beam shooting up into the sky." },
	-- side mounts: they clamp onto a Truss Tower (Stage category) at any height
	{ id = "sidewash", name = "Side Wash", cat = "Lights", cost = 220, pts = 2, tags = { "lights" }, mount = "side", deck = false, desc = "PAR can on a side clamp. Put it on a Truss Tower: it lights the stage and the crowd from the side." },
	{ id = "sidebeam", name = "Side Beam", cat = "Lights", cost = 900, pts = 4, tags = { "lights" }, mount = "side", deck = false, desc = "Beam light clamped to the side of a Truss Tower. Its beam sweeps out over the crowd." },
	{ id = "sideblinder", name = "Side Blinder", cat = "Lights", cost = 550, pts = 3, tags = { "lights", "energy" }, mount = "side", deck = false, desc = "Audience blinder for the side of a Truss Tower." },
	{ id = "sidestrobe", name = "Side Strobe", cat = "Lights", cost = 500, pts = 3, tags = { "lights", "energy" }, mount = "side", deck = false, desc = "Strobe on a side clamp of a Truss Tower." },
	{ id = "strobe", name = "Strobe", cat = "Lights", cost = 450, pts = 3, tags = { "lights", "energy" }, mount = "rig", deck = false, desc = "Flashes on the beat." },
	{ id = "blinder", name = "Audience Blinder", cat = "Lights", cost = 500, pts = 3, tags = { "lights", "energy" }, mount = "rig", deck = false, desc = "Warm flash towards the crowd on big moments." },
	{ id = "followspot", name = "Follow Spot", cat = "Lights", cost = 1100, pts = 3, tags = { "lights", "intimate" }, mount = "floor", deck = false, desc = "Follows the artist everywhere." },
	{ id = "kinetic", name = "Kinetic Light Bars", cat = "Lights", cost = 3200, pts = 9, tags = { "lights", "spectacle" }, mount = "rig", deck = false, size = { w = 24, minW = 8, maxW = 160 }, desc = "Glowing bars on motor winches that move up and down in waves." },
	{ id = "discoball", name = "Disco Ball", cat = "Lights", cost = 700, pts = 3, tags = { "retro" }, mount = "rig", deck = false, desc = "Spinning mirror ball." },
	{ id = "uplight", name = "Floor Uplight", cat = "Lights", cost = 120, pts = 1, tags = { "lights" }, mount = "floor", deck = false, desc = "Small light on the floor that washes walls and set pieces in colour." },
	{ id = "ledbar", name = "LED Bar", cat = "Lights", cost = 300, pts = 2, tags = { "lights" }, mount = "floor", deck = false, size = { w = 8, minW = 2, maxW = 240 }, desc = "Pixel bar for stage edges and risers. Colours run along it." },
	{ id = "lightpole", name = "Light Pole", cat = "Lights", cost = 250, pts = 2, tags = { "lights" }, mount = "floor", deck = false, desc = "Glowing vertical tube." },
	{ id = "stringlights", name = "String Lights", cat = "Lights", cost = 400, pts = 2, tags = { "retro", "intimate" }, mount = "rig", deck = false, size = { w = 24, minW = 6, maxW = 80 }, desc = "Warm fairy lights hanging in a curve." },
	{ id = "lanterns", name = "Paper Lanterns", cat = "Lights", cost = 350, pts = 2, tags = { "intimate", "retro" }, mount = "rig", deck = false, desc = "Three glowing lanterns." },
	-- Screens
	{ id = "led", name = "LED Wall", cat = "Screens", cost = 3000, pts = 8, tags = { "screens", "spectacle" }, mount = "floor", deck = false, size = { w = 16, d = 9, minW = 4, maxW = 200, minD = 3, maxD = 70, dLabel = "Height" }, desc = "Video wall. Shows song titles, text, images or a live camera." },
	{ id = "led_side", name = "Side Screen", cat = "Screens", cost = 3500, pts = 8, tags = { "screens" }, mount = "floor", deck = false, desc = "Tall side screen, perfect for the live camera." },
	{ id = "ledcube", name = "LED Cube", cat = "Screens", cost = 9000, pts = 16, tags = { "screens", "spectacle" }, mount = "rig", deck = false, desc = "Video cube over a center stage (like in-the-round arena shows). Lowers during the ballad." },
	{ id = "ledtower", name = "LED Tower", cat = "Screens", cost = 6500, pts = 12, tags = { "screens", "spectacle" }, mount = "floor", deck = false, desc = "Tall tower with screens on top. Put 4 to 8 around a center stage." },
	{ id = "ledpillar", name = "LED Pillar", cat = "Screens", cost = 1600, pts = 5, tags = { "screens" }, mount = "floor", deck = false, size = { w = 4, d = 16, minW = 2, maxW = 24, minD = 4, maxD = 90, dLabel = "Height" }, desc = "Slim LED column. Line them up behind the band." },
	{ id = "led_flat", name = "LED Wall (no feet)", cat = "Screens", cost = 3000, pts = 8, tags = { "screens", "spectacle" }, mount = "floor", deck = false, size = { w = 16, d = 9, minW = 2, maxW = 200, minD = 2, maxD = 70, dLabel = "Height" }, desc = "A video wall standing right on the stage, no feet or frame: line it up with the deck edge or use it as a side wall." },
	{ id = "led_hang", name = "Hanging LED Wall", cat = "Screens", cost = 3600, pts = 9, tags = { "screens", "spectacle" }, mount = "rig", deck = false, size = { w = 20, d = 11, minW = 4, maxW = 200, minD = 3, maxD = 60, dLabel = "Height" }, desc = "A video wall hanging from the rig on steel cables. Great over the stage or at the sides." },
	{ id = "led_flown", name = "Flown Side Screen", cat = "Screens", cost = 3800, pts = 8, tags = { "screens" }, mount = "rig", deck = false, desc = "A tall portrait screen hanging from the rig next to the stage (the live camera screens of arena shows)." },
	{ id = "led_ribbon", name = "LED Ribbon", cat = "Screens", cost = 1400, pts = 4, tags = { "screens" }, mount = "floor", deck = false, size = { w = 24, d = 2, minW = 2, maxW = 240, minD = 0.5, maxD = 8, dLabel = "Height" }, desc = "A thin video strip: along the front of a deck, on a riser, as a header over the stage." },
	{ id = "led_curve", name = "Curved LED Wall", cat = "Screens", cost = 6200, pts = 12, tags = { "screens", "spectacle" }, mount = "floor", deck = false, size = { w = 40, d = 16, minW = 16, maxW = 200, minD = 4, maxD = 70, dLabel = "Height" }, desc = "A video wall that bends around the stage: the sides come towards the fans." },
	{ id = "led_round", name = "Round Screen", cat = "Screens", cost = 5200, pts = 10, tags = { "screens", "spectacle" }, mount = "rig", deck = false, size = { w = 16, minW = 4, maxW = 140 }, desc = "A round video screen in a glowing ring, hanging from the rig." },
	{ id = "led_kinetic", name = "Kinetic Screens", cat = "Screens", cost = 9500, pts = 15, tags = { "screens", "spectacle" }, mount = "rig", deck = false, size = { w = 36, minW = 12, maxW = 160 }, desc = "A row of screen panels on winches: they move up and down in waves during the show." },
	{ id = "led_floor", name = "LED Floor", cat = "Screens", cost = 4500, pts = 9, tags = { "screens" }, mount = "floor", deck = false, size = { w = 16, d = 16, minW = 4, maxW = 200, minD = 4, maxD = 200 }, desc = "Animated light-up floor. Put it on top of a deck." },
	{ id = "portal", name = "Portal Ring", cat = "Screens", cost = 7000, pts = 13, tags = { "screens", "spectacle" }, mount = "floor", deck = false, size = { w = 24, minW = 10, maxW = 70 }, desc = "Giant glowing ring the artist can step through." },
	{ id = "neonsign", name = "Neon Logo", cat = "Screens", cost = 1800, pts = 5, tags = { "retro" }, mount = "floor", deck = false, desc = "The artist's name in neon." },
	{ id = "tvstack", name = "Retro TV Stack", cat = "Screens", cost = 1200, pts = 4, tags = { "retro", "screens" }, mount = "floor", deck = false, desc = "Pile of old TVs flashing with the beat." },
	{ id = "neonheart", name = "Neon Heart", cat = "Screens", cost = 600, pts = 3, tags = { "retro" }, mount = "floor", deck = false, desc = "Glowing heart sign." },
	{ id = "neonstar", name = "Neon Star", cat = "Screens", cost = 600, pts = 3, tags = { "retro" }, mount = "floor", deck = false, desc = "Glowing star sign." },
	{ id = "neonbolt", name = "Neon Lightning", cat = "Screens", cost = 600, pts = 3, tags = { "retro", "energy" }, mount = "floor", deck = false, desc = "Glowing lightning bolt." },
	-- Special effects
	{ id = "pyro", name = "Flame Pyro", cat = "FX", cost = 2000, pts = 8, tags = { "pyro", "energy" }, mount = "floor", deck = false, desc = "Huge flame bursts." },
	{ id = "flamebar", name = "Flame Bar", cat = "FX", cost = 3200, pts = 9, tags = { "pyro", "energy" }, mount = "floor", deck = false, size = { w = 16, minW = 6, maxW = 60 }, desc = "A row of flame jets: they fire one after the other, then all at once." },
	{ id = "sparkrain", name = "Spark Rain", cat = "FX", cost = 2600, pts = 7, tags = { "pyro", "spectacle" }, mount = "rig", deck = false, size = { w = 24, minW = 8, maxW = 100 }, desc = "Hangs in the rig: a curtain of sparks rains down." },
	{ id = "halo", name = "Light Halo", cat = "Lights", cost = 3800, pts = 9, tags = { "lights", "spectacle" }, mount = "rig", deck = false, size = { w = 20, minW = 10, maxW = 60 }, desc = "A big turning ring of lights in the rig. A light runs round it, everything flashes on the beat." },
	{ id = "sparks", name = "Spark Fountain", cat = "FX", cost = 1400, pts = 6, tags = { "pyro" }, mount = "floor", deck = false, desc = "Golden spark fountain." },
	{ id = "confetti", name = "Confetti Cannon", cat = "FX", cost = 1100, pts = 5, tags = { "party" }, mount = "floor", deck = false, desc = "Confetti for the finale." },
	{ id = "streamers", name = "Streamer Cannon", cat = "FX", cost = 1300, pts = 5, tags = { "party" }, mount = "floor", deck = false, desc = "Long shiny streamers rain down on the crowd." },
	{ id = "co2", name = "CO2 Jet", cat = "FX", cost = 1200, pts = 5, tags = { "energy" }, mount = "floor", deck = false, desc = "Freezing white jets on the drop." },
	{ id = "laser", name = "Laser Array", cat = "FX", cost = 2500, pts = 9, tags = { "lasers" }, mount = "rig", deck = false, desc = "Fan of sweeping lasers." },
	{ id = "haze", name = "Haze Machine", cat = "FX", cost = 300, pts = 3, tags = { "atmosphere" }, mount = "floor", deck = false, desc = "Stage haze for atmosphere." },
	{ id = "lowfog", name = "Low Fog", cat = "FX", cost = 1500, pts = 5, tags = { "atmosphere", "intimate" }, mount = "floor", deck = false, desc = "Thick cloud carpet on the floor for the ballad." },
	{ id = "balls", name = "Giant Balloons", cat = "FX", cost = 2600, pts = 8, tags = { "party", "spectacle" }, mount = "floor", deck = false, desc = "Huge balloons fly into the crowd in the finale. Fans bounce them around." },
	{ id = "wristbands", name = "LED Wristbands", cat = "FX", cost = 9000, pts = 14, tags = { "spectacle", "party" }, mount = "floor", deck = false, desc = "Every fan gets a glowing wristband that lights up with the music. Place the control desk anywhere." },
	{ id = "fireworks", name = "Fireworks Rack", cat = "FX", cost = 7000, pts = 14, tags = { "pyro", "spectacle" }, mount = "floor", deck = false, desc = "Fireworks for the grand finale (open-air venues). The shells burst high above the stage." },
	{ id = "raincurtain", name = "Rain Curtain", cat = "FX", cost = 9000, pts = 13, tags = { "spectacle", "atmosphere", "intimate" }, mount = "rig", deck = false, size = { w = 24, minW = 8, maxW = 120 }, desc = "A pipe in the rig: rain pours down onto the stage in its songs (or in the ballad). Put an artist spot under it for a big wet moment." },
	{ id = "rimfireworks", name = "Roof Fireworks", cat = "FX", cost = 16000, pts = 18, tags = { "pyro", "spectacle" }, mount = "floor", deck = false, desc = "Stadiums: fireworks shoot up all around the top edge of the stadium roof, like at the biggest stadium shows. Place the firing box anywhere on the stage." },
	{ id = "bubbles", name = "Bubble Machine", cat = "FX", cost = 400, pts = 2, tags = { "party", "intimate" }, mount = "floor", deck = false, desc = "Soap bubbles float over the front rows in calm songs." },
	{ id = "snow", name = "Snow Machine", cat = "FX", cost = 900, pts = 3, tags = { "intimate" }, mount = "rig", deck = false, desc = "Snowflakes fall during the ballad." },
	{ id = "windfan", name = "Wind Machine", cat = "FX", cost = 350, pts = 1, tags = {}, mount = "floor", deck = false, desc = "Big fan for the windswept-hair moment." },
	-- Set pieces (inspired by famous tour productions)
	{ id = "curtain", name = "Kabuki Curtain", cat = "Set", cost = 2200, pts = 7, tags = { "spectacle" }, mount = "floor", deck = false, size = { w = 40, d = 24, minW = 10, maxW = 200, minD = 8, maxD = 80, dLabel = "Height" }, desc = "Hides the stage before the show and drops in one second when the first song starts." },
	{ id = "moon", name = "Giant Moon", cat = "Set", cost = 4500, pts = 10, tags = { "spectacle", "intimate" }, mount = "floor", deck = false, size = { w = 18, minW = 8, maxW = 50 }, desc = "Glowing moon at the end of a runway." },
	{ id = "skyline", name = "City Skyline", cat = "Set", cost = 5000, pts = 11, tags = { "spectacle", "retro" }, mount = "floor", deck = false, size = { w = 48, minW = 16, maxW = 220 }, desc = "A whole city as the backdrop. The windows flash with the music." },
	{ id = "statue", name = "Giant Statue", cat = "Set", cost = 6000, pts = 12, tags = { "spectacle" }, mount = "floor", deck = false, desc = "Chrome giant that slowly turns its head." },
	{ id = "robotarm", name = "Robot Arm", cat = "Set", cost = 5500, pts = 11, tags = { "spectacle", "energy" }, mount = "floor", deck = false, desc = "Industrial robot arm with a light that dances with the show." },
	{ id = "house", name = "Little House", cat = "Set", cost = 2800, pts = 7, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "Cosy cabin set with glowing windows for an acoustic part." },
	{ id = "arch", name = "Light Arch", cat = "Set", cost = 1800, pts = 6, tags = { "lights", "retro" }, mount = "floor", deck = false, size = { w = 20, minW = 8, maxW = 60 }, desc = "Glowing archway over a runway." },
	{ id = "flowers", name = "Flower Garden", cat = "Set", cost = 900, pts = 3, tags = { "intimate" }, mount = "floor", deck = false, desc = "Colourful flower bed." },
	{ id = "inflatable", name = "Giant Inflatable", cat = "Set", cost = 5000, pts = 10, tags = { "spectacle", "party" }, mount = "floor", deck = false, desc = "Giant inflatable that blows up during the show." },
	{ id = "vintagecar", name = "Vintage Car", cat = "Set", cost = 4200, pts = 9, tags = { "retro", "spectacle" }, mount = "floor", deck = false, desc = "1950s convertible with fins, chrome and white-wall tyres." },
	{ id = "motorbike", name = "Chopper Bike", cat = "Set", cost = 2600, pts = 6, tags = { "retro", "energy" }, mount = "floor", deck = false, desc = "Chrome chopper on its kickstand." },
	{ id = "throne", name = "Royal Throne", cat = "Set", cost = 3000, pts = 7, tags = { "spectacle" }, mount = "floor", deck = false, desc = "Gold throne with velvet cushions on a round dais." },
	{ id = "hand", name = "Giant Hand", cat = "Set", cost = 5200, pts = 11, tags = { "spectacle" }, mount = "floor", deck = false, desc = "A chrome hand rising out of the stage, palm up." },
	{ id = "swing", name = "Stage Swing", cat = "Set", cost = 2400, pts = 6, tags = { "intimate", "spectacle" }, mount = "floor", deck = false, desc = "Swing with flower garlands that sways gently during the show." },
	{ id = "ferris", name = "Ferris Wheel", cat = "Set", cost = 7800, pts = 13, tags = { "spectacle", "party", "retro" }, mount = "floor", deck = false, desc = "Small lit Ferris wheel that turns slowly." },
	{ id = "rocket", name = "Retro Rocket", cat = "Set", cost = 6200, pts = 12, tags = { "spectacle", "pyro" }, mount = "floor", deck = false, desc = "Rocket on a launch pad. Smoke and fire blast out on the big moments." },
	{ id = "fountain", name = "Stage Fountain", cat = "Set", cost = 3600, pts = 8, tags = { "intimate", "spectacle" }, mount = "floor", deck = false, desc = "Marble fountain with a lit rim. The water jet dances with the music." },
	{ id = "lighthouse", name = "Lighthouse", cat = "Set", cost = 4800, pts = 10, tags = { "spectacle", "lights" }, mount = "floor", deck = false, desc = "Striped lighthouse whose beam sweeps across the crowd." },
	{ id = "cloud", name = "Floating Cloud", cat = "Set", cost = 2200, pts = 6, tags = { "intimate", "atmosphere" }, mount = "rig", deck = false, desc = "Fluffy cloud hanging in the rig, glowing from inside." },
	{ id = "rainbow", name = "Rainbow Arch", cat = "Set", cost = 3400, pts = 8, tags = { "party", "spectacle" }, mount = "floor", deck = false, size = { w = 30, minW = 16, maxW = 80 }, desc = "Seven neon tubes in rainbow colours, standing on two clouds." },
	{ id = "column", name = "Grand Column", cat = "Set", cost = 1200, pts = 4, tags = { "intimate", "spectacle" }, mount = "floor", deck = false, desc = "White column with a lit top. Line up a few for a temple or a palace set." },
	{ id = "giantguitar", name = "Giant Guitar", cat = "Set", cost = 3800, pts = 9, tags = { "band", "retro", "spectacle" }, mount = "floor", deck = false, desc = "A guitar as tall as a house, leaning on its stand, with glowing strings." },
	{ id = "palm", name = "Neon Palm", cat = "Set", cost = 800, pts = 3, tags = { "party", "retro" }, mount = "floor", deck = false, desc = "Glowing palm tree." },
	-- Decor: small things that make a stage feel like a place
	-- big backdrops: width with the side handles, height with the top handle
	{ id = "backdrop", name = "Stage Cloth", cat = "Set", cost = 1200, pts = 4, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 48, d = 22, minW = 10, maxW = 240, minD = 8, maxD = 70, dLabel = "Height" }, desc = "A plain dark cloth behind the stage. Simple and clean, the lights give it colour." },
	{ id = "starcloth", name = "Star Cloth", cat = "Set", cost = 2600, pts = 7, tags = { "intimate", "atmosphere" }, mount = "floor", deck = false, size = { w = 48, d = 22, minW = 10, maxW = 200, minD = 8, maxD = 60, dLabel = "Height" }, desc = "Black cloth full of tiny twinkling lights, like a night sky." },
	{ id = "scrim", name = "Gauze Scrim", cat = "Set", cost = 1800, pts = 5, tags = { "atmosphere", "lights" }, mount = "floor", deck = false, size = { w = 40, d = 20, minW = 10, maxW = 200, minD = 8, maxD = 60, dLabel = "Height" }, desc = "A thin white sheet that glows in the colour of the lights." },
	{ id = "panelwall", name = "Light Panel Wall", cat = "Set", cost = 4200, pts = 9, tags = { "lights", "spectacle", "energy" }, mount = "floor", deck = false, size = { w = 36, d = 18, minW = 6, maxW = 160, minD = 6, maxD = 60, dLabel = "Height" }, desc = "Square light panels in a frame. Patterns jump with the beat." },
	{ id = "bulbwall", name = "Bulb Wall", cat = "Set", cost = 3600, pts = 8, tags = { "retro", "lights" }, mount = "floor", deck = false, size = { w = 30, d = 16, minW = 6, maxW = 120, minD = 6, maxD = 50, dLabel = "Height" }, desc = "A retro wall of round light bulbs with running chasers." },
	{ id = "slatwall", name = "Slat Wall", cat = "Set", cost = 2400, pts = 6, tags = { "intimate", "lights" }, mount = "floor", deck = false, size = { w = 32, d = 16, minW = 6, maxW = 160, minD = 6, maxD = 50, dLabel = "Height" }, desc = "Dark wooden slats with coloured light shining through the gaps." },
	{ id = "brickwall", name = "Brick Wall", cat = "Set", cost = 1500, pts = 4, tags = { "retro", "band" }, mount = "floor", deck = false, size = { w = 40, d = 18, minW = 8, maxW = 200, minD = 6, maxD = 50, dLabel = "Height" }, desc = "An old brick wall with pillars: the club / warehouse look." },
	{ id = "scaffold", name = "Scaffold Wall", cat = "Set", cost = 3800, pts = 8, tags = { "energy", "band", "lights" }, mount = "floor", deck = false, size = { w = 40, d = 18, minW = 8, maxW = 200, minD = 6, maxD = 50, dLabel = "Height" }, desc = "Industrial scaffolding with LED strips on every level." },
	{ id = "mirrorwall", name = "Mirror Wall", cat = "Set", cost = 4600, pts = 9, tags = { "spectacle", "lights" }, mount = "floor", deck = false, size = { w = 30, d = 16, minW = 6, maxW = 140, minD = 6, maxD = 50, dLabel = "Height" }, desc = "Tilted mirror tiles that throw the light back into the hall." },
	{ id = "operahouse", name = "Opera House", cat = "Set", cost = 30000, pts = 22, tags = { "spectacle", "retro" }, mount = "floor", deck = false, size = { w = 60, minW = 30, maxW = 160 }, desc = "A gothic opera house front with three levels of boxes, gold railings and red curtains." },
	{ id = "housefront", name = "House Front", cat = "Set", cost = 12000, pts = 12, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "A two-storey house with warm windows, a door and a balcony: a home on the stage." },
	{ id = "ruinedhouse", name = "Ruined House", cat = "Set", cost = 14000, pts = 13, tags = { "atmosphere", "intimate" }, mount = "floor", deck = false, desc = "A burnt, broken house with a fallen roof, slowly taken over by flowers." },
	{ id = "flowerwall", name = "Flower Wall", cat = "Set", cost = 3400, pts = 7, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 20, d = 10, minW = 4, maxW = 120, minD = 3, maxD = 40, dLabel = "Height" }, desc = "A wall full of flowers in soft colours." },
	{ id = "staircase", name = "Grand Staircase", cat = "Set", cost = 5200, pts = 10, tags = { "spectacle", "retro" }, mount = "floor", deck = false, size = { w = 30, minW = 12, maxW = 120 }, desc = "A wide white staircase across the back of the stage, with light lines in the steps." },
	-- neutral decor
	{ id = "ampwall", name = "Amp Wall", cat = "Decor", cost = 900, pts = 2, tags = { "band", "energy" }, mount = "floor", deck = false, desc = "A wall of guitar cabinets with amp heads: classic rock backline." },
	{ id = "lightcube", name = "Light Cube", cat = "Decor", cost = 300, pts = 1, tags = { "party" }, mount = "floor", deck = false, desc = "A glowing cube to sit on. Changes colour with the music." },
	{ id = "planter", name = "Planter Box", cat = "Decor", cost = 350, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 12, minW = 4, maxW = 60 }, desc = "A long box with round green shrubs." },
	{ id = "neonline", name = "Neon Line", cat = "Decor", cost = 250, pts = 1, tags = { "lights" }, mount = "floor", deck = false, size = { w = 16, minW = 2, maxW = 120 }, desc = "A neon tube for stage edges and floor lines." },
	{ id = "hedge", name = "Hedge", cat = "Decor", cost = 300, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 12, minW = 4, maxW = 80 }, desc = "A trimmed green hedge." },
	{ id = "rope", name = "Velvet Rope", cat = "Decor", cost = 250, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 12, minW = 4, maxW = 60 }, desc = "Brass posts with a red velvet rope." },
	{ id = "sofa", name = "Sofa", cat = "Decor", cost = 500, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, desc = "Cosy sofa for a living-room set." },
	{ id = "rug", name = "Rug", cat = "Decor", cost = 150, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Round rug in the artist's colour." },
	{ id = "floorlamp", name = "Floor Lamp", cat = "Decor", cost = 150, pts = 1, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "Standing lamp with a warm shade." },
	{ id = "table", name = "Side Table", cat = "Decor", cost = 150, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Small table with a drink and a vase." },
	{ id = "candles", name = "Candles", cat = "Decor", cost = 200, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Group of flickering candles." },
	{ id = "plant", name = "Potted Plant", cat = "Decor", cost = 120, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Green plant in a pot." },
	{ id = "tree", name = "Tree", cat = "Decor", cost = 400, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, desc = "Small tree, nice with string lights." },
	{ id = "bench", name = "Park Bench", cat = "Decor", cost = 200, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Wooden bench." },
	{ id = "streetlamp", name = "Street Lamp", cat = "Decor", cost = 300, pts = 2, tags = { "retro" }, mount = "floor", deck = false, desc = "Old-style street lamp." },
	{ id = "roadcase", name = "Road Cases", cat = "Decor", cost = 150, pts = 0, tags = { "band" }, mount = "floor", deck = false, desc = "Stacked flight cases, the rock'n'roll look." },
	{ id = "balloonarch", name = "Balloon Arch", cat = "Decor", cost = 700, pts = 3, tags = { "party" }, mount = "floor", deck = false, size = { w = 16, minW = 8, maxW = 40 }, desc = "Arch of balloons." },
	{ id = "drapes", name = "Velvet Drapes", cat = "Decor", cost = 600, pts = 2, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "Red velvet curtains on a frame, tied back at the sides. A little theatre on the stage." },
	{ id = "barrels", name = "Barrels and Crates", cat = "Decor", cost = 180, pts = 1, tags = { "band", "retro" }, mount = "floor", deck = false, desc = "Old wooden barrels and crates for a saloon or harbour look." },
	{ id = "bookshelf", name = "Bookshelf", cat = "Decor", cost = 350, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, desc = "Tall shelf with books, records and a lamp: a living-room set." },
	{ id = "lanternline", name = "Lantern Line", cat = "Decor", cost = 450, pts = 2, tags = { "intimate", "party" }, mount = "floor", deck = false, desc = "Two poles with glowing paper lanterns on a line between them." },
	{ id = "golddiscs", name = "Gold Disc Wall", cat = "Decor", cost = 800, pts = 2, tags = { "retro" }, mount = "floor", deck = false, desc = "Framed gold and platinum records on a stand: the artist's hits." },
	{ id = "vanity", name = "Vanity Mirror", cat = "Decor", cost = 900, pts = 3, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "A dressing table with a bulb-lit mirror, make-up and roses: the backstage look." },
	{ id = "armchair", name = "Velvet Armchair", cat = "Decor", cost = 600, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, desc = "A deep velvet armchair with rolled arms (in the artist's colour)." },
	{ id = "bathtub", name = "Claw-Foot Bathtub", cat = "Decor", cost = 1200, pts = 4, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "A white bathtub on golden feet, full of foam." },
	{ id = "grandclock", name = "Grandfather Clock", cat = "Decor", cost = 1100, pts = 3, tags = { "retro", "intimate" }, mount = "floor", deck = false, desc = "A tall old clock with a swinging pendulum." },
	{ id = "phonebooth", name = "Phone Box", cat = "Decor", cost = 1500, pts = 4, tags = { "retro" }, mount = "floor", deck = false, desc = "A red telephone box with glowing windows." },
	{ id = "picketfence", name = "Picket Fence", cat = "Decor", cost = 300, pts = 1, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 12, minW = 3, maxW = 120 }, desc = "A white wooden fence (any length)." },
	{ id = "neonheart", name = "Neon Heart", cat = "Decor", cost = 800, pts = 3, tags = { "lights", "intimate" }, mount = "floor", deck = false, desc = "A glowing neon heart on a black board." },
	{ id = "brokencolumn", name = "Broken Column", cat = "Decor", cost = 900, pts = 3, tags = { "retro" }, mount = "floor", deck = false, desc = "A broken marble column with the fallen top next to it." },
	{ id = "chandelier", name = "Crystal Chandelier", cat = "Decor", cost = 2400, pts = 6, tags = { "retro", "intimate", "lights" }, mount = "rig", deck = false, desc = "A big crystal chandelier with candle lights, hanging from the rig." },
	{ id = "hangingstars", name = "Hanging Stars", cat = "Decor", cost = 1400, pts = 4, tags = { "intimate", "lights" }, mount = "rig", deck = false, size = { w = 24, minW = 6, maxW = 160 }, desc = "Glowing stars on thin wires at different heights." },
	{ id = "cherrytree", name = "Cherry Blossom Tree", cat = "Set", cost = 2600, pts = 7, tags = { "intimate" }, mount = "floor", deck = false, desc = "A tree in full pink blossom, petals on the floor." },
	{ id = "gazebo", name = "Garden Gazebo", cat = "Set", cost = 4200, pts = 9, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "A white gazebo with eight columns, a domed roof and fairy lights. Open at the front." },
	{ id = "spiralstair", name = "Spiral Staircase", cat = "Set", cost = 3800, pts = 8, tags = { "spectacle", "retro" }, mount = "floor", deck = false, desc = "A tall white spiral staircase with a golden handrail (a set piece)." },
	{ id = "circustent", name = "Circus Tent", cat = "Set", cost = 4600, pts = 10, tags = { "spectacle", "party" }, mount = "floor", deck = false, desc = "A red and white big top with a glowing entrance and bulbs." },
	{ id = "rowboat", name = "Rowing Boat", cat = "Set", cost = 1800, pts = 5, tags = { "intimate" }, mount = "floor", deck = false, desc = "A little wooden boat with oars on a pool of water: a ballad on the lake." },
	{ id = "bed", name = "Four-Poster Bed", cat = "Set", cost = 2200, pts = 6, tags = { "intimate", "retro" }, mount = "floor", deck = false, desc = "A big bed with posts, a canopy and curtains (in the artist's colour)." },
	{ id = "banner", name = "Logo Banner", cat = "Decor", cost = 500, pts = 2, tags = {}, mount = "rig", deck = false, desc = "Hanging fabric banner with the artist's name." },
}

-- Genre bonus per tag (multiplies the item's points)
StageItems.GENRE_TAGS = {
	Pop = { spectacle = 1.3, screens = 1.2, party = 1.2, lights = 1.1 },
	Rock = { pyro = 1.25, lights = 1.2, band = 1.2 },
	["Hip-Hop"] = { pyro = 1.3, screens = 1.2, energy = 1.2 },
	EDM = { lasers = 1.4, energy = 1.3, lights = 1.2, dj = 1.4 },
	Metal = { pyro = 1.5, energy = 1.2, band = 1.2, party = 0.7 },
	Indie = { intimate = 1.4, retro = 1.2, pyro = 0.8, spectacle = 0.8 },
	["K-Pop"] = { spectacle = 1.3, screens = 1.3, lights = 1.2, party = 1.1 },
	Country = { retro = 1.2, band = 1.2, pyro = 1.1 },
	Latin = { party = 1.3, energy = 1.2, pyro = 1.1 },
	["R&B"] = { intimate = 1.25, lights = 1.2, atmosphere = 1.2 },
}

-- Ready-made designs every new game starts with. Coordinates in studs (stage deck: x -32..32, z -24..8).
-- Ready-made designs every new game starts with (free). Coordinates in studs, audience towards +z.
local function ring(t, n, r, y)
	local out = {}
	for i = 0, n - 1 do
		local a = i * 2 * math.pi / n
		table.insert(out, { t = t, x = math.floor(math.sin(a) * r + 0.5), z = math.floor(math.cos(a) * r + 0.5), r = math.floor(math.deg(a) + 0.5) })
	end
	return out
end
local function join(...)
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, x in ipairs(list) do
			table.insert(out, x)
		end
	end
	return out
end
local function line(t, n, x0, x1, z, extra)
	local out = {}
	for i = 0, n - 1 do
		local rec = { t = t, x = math.floor(x0 + (x1 - x0) * (n > 1 and i / (n - 1) or 0.5) + 0.5), z = z, r = 0 }
		for k, v in pairs(extra or {}) do
			rec[k] = v
		end
		table.insert(out, rec)
	end
	return out
end

-- Designs every new game starts with (free) and tour-inspired templates you can buy in the "New stage" dialog.
-- shop = true: only offered as a template (you pay for the equipment).
StageItems.PRESETS = {
	{
		name = "Club Stage", class = "Club", layout = "end",
		items = join(
			{ { t = "deck", x = 0, z = -12, r = 0, w = 32, d = 16, h = 4 } },
			{ { t = "spot", x = 0, z = -8, r = 0 }, { t = "spot", x = -8, z = -9, r = 0 }, { t = "spot", x = 8, z = -9, r = 0 }, { t = "spot", x = 0, z = -6, r = 0 } },
			{ { t = "micstand", x = 0, z = -7, r = 0 }, { t = "amps", x = -12, z = -17, r = 0 }, { t = "amps", x = 12, z = -17, r = 0 } },
			{ { t = "speakers", x = -19, z = -6, r = 0 }, { t = "speakers", x = 19, z = -6, r = 0 } },
			{ { t = "truss_beam", x = 0, z = -8, r = 0, w = 34 } },
			line("par", 4, -12, 12, -8),
			{ { t = "discoball", x = 0, z = 6, r = 0 }, { t = "haze", x = 0, z = -18, r = 0 } }
		),
	},
	{
		name = "Arena End Stage", class = "Arena", layout = "end",
		items = join(
			{ { t = "deck", x = 0, z = -8, r = 0, w = 64, d = 32, h = 6 }, { t = "deck", x = 0, z = 22, r = 0, w = 8, d = 28, h = 6 }, { t = "deck_round", x = 0, z = 42, r = 0, w = 18, h = 6 } },
			{ { t = "spot", x = -20, z = -6, r = 0 }, { t = "spot", x = 20, z = -6, r = 0 }, { t = "spot", x = 0, z = 42, r = 0 }, { t = "spot", x = 0, z = -2, r = 0 } },
			{ { t = "lift", x = 0, z = -4, r = 0, play = 1 }, { t = "led", x = 0, z = -21, r = 0, w = 40, d = 18 } },
			{ { t = "speakers", x = -38, z = 4, r = 0 }, { t = "speakers", x = 38, z = 4, r = 0 } },
			{ { t = "truss_beam", x = 0, z = -10, r = 0, w = 70 }, { t = "truss_beam", x = 0, z = 4, r = 0, w = 70 } },
			line("moving", 6, -25, 25, -10),
			line("par", 4, -20, 20, 4),
			{ { t = "pyro", x = -26, z = 5, r = 0 }, { t = "pyro", x = 26, z = 5, r = 0 }, { t = "co2", x = -14, z = 6, r = 0 }, { t = "co2", x = 14, z = 6, r = 0 } },
			{ { t = "confetti", x = -30, z = -20, r = 0 }, { t = "confetti", x = 30, z = -20, r = 0 } }
		),
	},
	{
		name = "Center Stage", class = "Arena", layout = "center",
		items = join(
			{ { t = "deck_round", x = 0, z = 0, r = 0, w = 34, h = 6 } },
			{ { t = "spot", x = 10, z = 0, r = 0 }, { t = "spot", x = 0, z = 10, r = 0 }, { t = "spot", x = -10, z = 0, r = 0 }, { t = "spot", x = 0, z = -10, r = 0 } },
			{ { t = "lift", x = 0, z = 0, r = 0, play = 1 }, { t = "led_floor", x = 0, z = 0, r = 0, w = 20, d = 20 } },
			ring("moving", 8, 24),
			ring("speakers", 4, 30),
			ring("sparks", 6, 15)
		),
	},
	{
		name = "The Cube", class = "Arena", layout = "center", shop = true,
		desc = "In the round: LED cube overhead, LED floor and 8 video towers around the crowd.",
		items = join(
			{ { t = "deck_round", x = 0, z = 0, r = 0, w = 40, h = 6, skin = "led" } },
			{ { t = "spot", x = 12, z = 0, r = 0 }, { t = "spot", x = 0, z = 12, r = 0 }, { t = "spot", x = -12, z = 0, r = 0 }, { t = "spot", x = 0, z = -12, r = 0 }, { t = "spot", x = 0, z = 0, r = 0 } },
			{ { t = "lift", x = 0, z = 0, r = 0, play = 1 }, { t = "ledcube", x = 0, z = 0, r = 0 }, { t = "lowfog", x = 22, z = 0, r = 0 }, { t = "wristbands", x = 0, z = 56, r = 0 } },
			ring("ledtower", 8, 54),
			ring("moving", 8, 28),
			ring("co2", 4, 21)
		),
	},
	{
		name = "Portal Ring", class = "Arena", layout = "end", shop = true,
		desc = "A giant glowing ring as the centrepiece, robot arms and a runway to a B-stage.",
		items = join(
			{ { t = "deck", x = 0, z = -14, r = 0, w = 76, d = 30, h = 6, skin = "mirror" }, { t = "deck", x = 0, z = 16, r = 0, w = 8, d = 30, h = 6 }, { t = "deck_round", x = 0, z = 38, r = 0, w = 20, h = 6, skin = "led" } },
			{ { t = "portal", x = 0, z = -22, r = 0, w = 30 }, { t = "robotarm", x = -28, z = -20, r = 0 }, { t = "robotarm", x = 28, z = -20, r = 0 } },
			{ { t = "spot", x = 0, z = -18, r = 0 }, { t = "spot", x = -18, z = -10, r = 0 }, { t = "spot", x = 18, z = -10, r = 0 }, { t = "spot", x = 0, z = 38, r = 0 }, { t = "spot", x = 0, z = 16, r = 0 }, { t = "spot", x = 0, z = -12, r = 0 } },
			{ { t = "led_side", x = -48, z = -6, r = 0 }, { t = "led_side", x = 48, z = -6, r = 0 } },
			{ { t = "truss_beam", x = 0, z = -4, r = 0, w = 80 } },
			line("moving", 8, -35, 35, -4),
			line("blinder", 4, -30, 30, -4),
			{ { t = "laser", x = -20, z = -4, r = 0 }, { t = "laser", x = 20, z = -4, r = 0 } },
			{ { t = "pyro", x = -34, z = 0, r = 0 }, { t = "pyro", x = 34, z = 0, r = 0 }, { t = "streamers", x = -30, z = -24, r = 0 }, { t = "streamers", x = 30, z = -24, r = 0 } }
		),
	},
	{
		name = "Runway & Moon", class = "Stadium", layout = "end", shop = true,
		desc = "Stadium show: city skyline behind the stage, a runway through the crowd to a giant moon.",
		items = join(
			{ { t = "deck", x = 0, z = -22, r = 0, w = 120, d = 36, h = 8 }, { t = "deck", x = 0, z = 50, r = 0, w = 10, d = 108, h = 8 }, { t = "deck_round", x = 0, z = 116, r = 0, w = 28, h = 8 } },
			{ { t = "skyline", x = 0, z = -38, r = 0, w = 140 }, { t = "moon", x = 0, z = 140, r = 0, w = 26 }, { t = "statue", x = -72, z = -24, r = 0 }, { t = "arch", x = 0, z = 70, r = 0, w = 22 } },
			{ { t = "spot", x = -36, z = -16, r = 0 }, { t = "spot", x = 36, z = -16, r = 0 }, { t = "spot", x = 0, z = 60, r = 0 }, { t = "spot", x = 0, z = 116, r = 0 }, { t = "spot", x = 0, z = 110, r = 0 }, { t = "spot", x = 0, z = -12, r = 0 } },
			{ { t = "lift", x = 0, z = -16, r = 0, play = 1 }, { t = "led_side", x = 70, z = -6, r = 0 }, { t = "led_side", x = -84, z = 0, r = 0 } },
			{ { t = "truss_beam", x = 0, z = -14, r = 0, w = 120 } },
			line("moving", 10, -54, 54, -14),
			line("pyro", 6, -50, 50, -2),
			{ { t = "sparks", x = -8, z = 24, r = 0 }, { t = "sparks", x = 8, z = 24, r = 0 }, { t = "sparks", x = -8, z = 80, r = 0 }, { t = "sparks", x = 8, z = 80, r = 0 } },
			{ { t = "fireworks", x = -60, z = -40, r = 0 }, { t = "fireworks", x = 60, z = -40, r = 0 }, { t = "balls", x = 0, z = 6, r = 0 } },
			{ { t = "speakers", x = -66, z = 0, r = 0 }, { t = "speakers", x = 66, z = 0, r = 0 } }
		),
	},
	{
		name = "Stadium Tour", class = "Stadium", layout = "end", shop = true,
		desc = "A real stadium production: giant scaffold with PA towers, a 120-wide LED wall, a runway to a B-stage where a tower lift takes the artist up high, delay towers in the crowd.",
		items = join(
			{ { t = "deck", x = 0, z = -30, r = 0, w = 150, d = 44, h = 8 }, { t = "deck", x = 0, z = 40, r = 0, w = 12, d = 96, h = 8 }, { t = "deck_round", x = 0, z = 110, r = 0, w = 34, h = 8 } },
			{ { t = "stadiumroof", x = 0, z = -36, r = 0, w = 170, d = 70 }, { t = "led", x = 0, z = -50, r = 0, w = 120, d = 46 }, { t = "led_side", x = 100, z = -20, r = 0 }, { t = "led_side", x = -100, z = -20, r = 0 } },
			{ { t = "poplift", x = 0, z = -20, r = 0, play = 1 }, { t = "towerlift", x = 0, z = 110, r = 0 } },
			{ { t = "spot", x = -50, z = -24, r = 0 }, { t = "spot", x = 50, z = -24, r = 0 }, { t = "spot", x = 0, z = 40, r = 0 }, { t = "spot", x = 0, z = 80, r = 0 }, { t = "spot", x = -30, z = -34, r = 0 } },
			{ { t = "delaytower", x = -60, z = 150, r = 0 }, { t = "delaytower", x = 60, z = 150, r = 0 } },
			{ { t = "truss_beam", x = 0, z = -16, r = 0, w = 150 } },
			line("moving", 12, -70, 70, -16),
			line("pyro", 8, -70, 70, -10),
			{ { t = "co2", x = -22, z = -10, r = 0 }, { t = "co2", x = 22, z = -10, r = 0 }, { t = "confetti", x = -40, z = -12, r = 0 }, { t = "confetti", x = 40, z = -12, r = 0 } },
			{ { t = "sparks", x = -7, z = 20, r = 0 }, { t = "sparks", x = 7, z = 20, r = 0 }, { t = "sparks", x = -7, z = 70, r = 0 }, { t = "sparks", x = 7, z = 70, r = 0 } },
			{ { t = "fireworks", x = -80, z = -56, r = 0 }, { t = "fireworks", x = 80, z = -56, r = 0 } }
		),
	},
}

StageItems.byId = {}
for i, it in ipairs(StageItems.list) do
	it.order = i
	StageItems.byId[it.id] = it
end

return StageItems
