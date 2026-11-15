-- Fan posts for the SOCIAL feed. Placeholders: {artist} {venue} {city} {country} {tour} {song} {price} {tag} {item} {label}
-- mood: 1 = positive, 0 = neutral, -1 = negative. photo = the post shows a concert photo.
local Social = {}

Social.FIRST = {
	"Mia", "Leo", "Emma", "Noah", "Zoe", "Liam", "Ava", "Kai", "Lena", "Max", "Sofia", "Jonas", "Aria", "Finn", "Chloe", "Mateo",
	"Yuna", "Ben", "Lucia", "Tom", "Nora", "Elias", "Hana", "Sam", "Ines", "Ravi", "Maya", "Oscar", "Lea", "Diego", "Ivy", "Jae",
}
Social.HANDLE_A = { "lunar", "neon", "starry", "velvet", "indie", "popcorn", "midnight", "glitter", "sunset", "moshpit", "frontrow", "golden", "electric", "sugar", "echo", "cosmic", "vinyl", "encore", "barricade", "confetti" }
Social.HANDLE_B = { "girl", "kid", "fan", "lover", "vibes", "era", "daily", "stan", "club", "x", "99", "2027", "heart", "soul", "times", "updates" }

Social.POSTS = {
	announce = {
		{ 1, "{artist} JUST ANNOUNCED {tour}!!! I'm not okay" },
		{ 1, "Tickets for {artist} in {city}?? Setting 12 alarms for the presale" },
		{ 1, "{artist} coming to {city} is the best news of the year {tag}" },
		{ 1, "Already planning my outfit for {artist} in {city}" },
		{ 0, "{tour} dates are out. Who's going to {venue}?" },
		{ -1, "{artist} skipping my country AGAIN. Please come to {country}" },
		{ 0, "Me refreshing the ticket page every 3 seconds for {artist}" },
		{ 1, "Screenshot or it didn't happen: {artist} {tour} poster is HERE" },
		{ 1, "Booking the hotel in {city} before I even have tickets. Priorities" },
		{ 0, "Presale code for {artist}? Asking for me" },
		{ 1, "The {tour} poster is so pretty I want it framed" },
		{ 1, "{city} we are SO back. {artist} is coming {tag}" },
		{ 0, "Who wants to road trip to {city} for {artist}? I have snacks" },
		{ -1, "Why is {artist} only doing one night in {city}??" },
		{ 1, "Told my boss I'm sick on the day of {artist} in {city}. Already." },
	},
	price_high = {
		{ -1, "{price} for {artist}?? My wallet is crying" },
		{ -1, "Love {artist} but {price} a ticket is a lot. Hope it's worth it" },
		{ -1, "Ticket prices for {tour} are wild. Students can't afford this" },
		{ -1, "VIP for {artist} costs more than my rent. No thanks" },
		{ -1, "{price} plus fees... the fees are the real villain here" },
		{ 0, "Saving every coin for {tour}. Instant noodles for a month" },
		{ -1, "Remember when concerts were affordable? {label} please" },
	},
	price_low = {
		{ 1, "Only {price} for {artist}? That's actually fair. Buying two!" },
		{ 1, "Respect to {label} for keeping tickets affordable" },
		{ 1, "Fair prices for {tour}! Bringing my little sister" },
		{ 1, "{price} for {artist}?? Fans first, love that" },
		{ 1, "Cheap enough to go twice. Two nights in {city} it is" },
	},
	soldout = {
		{ 1, "{venue} SOLD OUT for {artist}! We did that {tag}" },
		{ 1, "Got my tickets for {city} before it sold out. Still shaking" },
		{ -1, "Sold out in minutes and I got nothing. Please add a second night in {city}!" },
		{ -1, "Resale prices for {artist} in {city} are criminal" },
		{ 0, "{artist} sold out {venue}. Next stop: stadiums?" },
		{ 1, "Ticket secured. Section 112, row 4. See you {city}!" },
		{ 1, "Waiting room: 48,000 people ahead of me... and I GOT THEM" },
		{ -1, "Website crashed right when I clicked buy. Pain." },
		{ 1, "{artist} at {venue} SOLD OUT. Proud of this fandom" },
		{ 0, "Anyone selling a ticket for {city} at face value? Please" },
	},
	lowsales = {
		{ -1, "Lots of tickets still left for {artist} at {venue}... come on {city}!" },
		{ 0, "Is anyone else going to {artist} in {city}? Want to meet up!" },
		{ -1, "Maybe {venue} was a bit too big for {artist} right now" },
		{ 0, "Tickets for {artist} in {city} still available. Last chance!" },
		{ -1, "Upper tier at {venue} is still empty for {artist}. Weird" },
		{ 0, "Good seats still left for {artist} in {city}, just saying" },
		{ -1, "{artist} needs a smaller venue in {city} honestly" },
	},
	show_great = {
		{ 1, "{artist} at {venue} was LIFE CHANGING {tag}" },
		{ 1, "I screamed so much at {artist} tonight that I have no voice left" },
		{ 1, "Best concert of my life. {city} was so loud tonight" },
		{ 1, "{song} live hit different. I cried. Twice." },
		{ 1, "The production for {tour} is insane. Every song had a moment" },
		{ 1, "Still not over last night. {artist} in {city} 10/10" },
		{ 1, "{artist} said {city} was the loudest crowd of the tour and I believe it" },
		{ 1, "The crowd sang {song} so loud {artist} stopped and just listened" },
		{ 1, "Lost my voice, my shoe and my dignity at {venue}. Worth it" },
		{ 1, "{artist} looked right at our section during {song}. I'm gone" },
		{ 1, "That opening in {city}. Goosebumps from the first second" },
		{ 1, "Ears ringing, heart full. Thank you {artist} {tag}" },
		{ 1, "The encore in {city} was the best five minutes of my year" },
		{ 1, "Not one bad seat at {venue}. The show was everywhere" },
		{ 1, "Saw {artist} 4 times now and {city} was the best one" },
		{ 1, "The light show during {song}... someone give the crew an award" },
	},
	show_ok = {
		{ 0, "{artist} in {city} was good! Sound was a bit quiet where I stood" },
		{ 0, "Fun night at {venue}. Wish the show was a bit longer" },
		{ 1, "{song} was the highlight for me. Crowd was a bit sleepy though" },
		{ 0, "Solid show from {artist}. Not the best, not the worst" },
		{ -1, "The stage looked kind of empty for a venue that big" },
		{ 0, "Good vibes in {city}, but the sound in the upper tier was muddy" },
		{ 0, "{artist} was great, the crowd around me just kept talking" },
		{ 1, "Happy I went. {song} alone was worth it" },
		{ 0, "Nice show. Next tour bigger stage please {artist}" },
	},
	show_bad = {
		{ -1, "{artist} in {city}... honestly disappointing" },
		{ -1, "Paid {price} for that? The stage was so bare" },
		{ -1, "Couldn't see anything from my seat and the show felt rushed" },
		{ -1, "Love {artist} but tonight wasn't it. Hope the next shows are better" },
		{ -1, "Half the songs I wanted weren't even played" },
		{ -1, "Waited 3 hours outside for a show that felt like a rehearsal" },
		{ -1, "The screens were too small, couldn't see {artist} at all" },
		{ -1, "Sound was so bad in {city} I could barely hear {song}" },
		{ -1, "{venue} was half empty and you could feel it" },
	},
	photo = {
		{ 1, "me and the girls at {venue} last night!!" },
		{ 1, "front row for {artist}. Worth every hour in the queue" },
		{ 1, "Matching outfits for {tour} with my best friend" },
		{ 1, "View from my seat in {city}. Unreal" },
		{ 1, "We made it to {artist}! {tag}" },
		{ 1, "Group photo before the show, the queue was already huge" },
		{ 1, "Blurry but it's MY blurry photo of {artist}" },
		{ 1, "Phone lights during {song}. {city} looked like a galaxy" },
		{ 1, "Barricade gang. My arms still hurt, worth it" },
		{ 1, "Caught the confetti! It's going in a frame" },
		{ 1, "The fire!! I felt the heat from row 10" },
		{ 1, "Not me zooming in 30x to see {artist}'s face" },
		{ 1, "Upper tier view at {venue}. Still magic" },
		{ 1, "Outfit check before {artist} in {city}" },
		{ 1, "The stage at {venue} is so much bigger in real life" },
		{ 1, "Last song, last photo, best night {tag}" },
		{ 1, "Found my concert twin in the crowd, matching shirts!" },
		{ 1, "Golden hour in the queue at {venue}" },
	},
	fanproject = {
		{ 1, "FAN PROJECT for {city}: everyone hold up a light during {song}! Spread the word {tag}" },
		{ 1, "Fan project: we're printing signs that say 'THANK YOU {artist}' for the {city} show" },
		{ 1, "Making friendship bracelets for {tour}. 200 done, 300 to go" },
		{ 1, "Fan project for {venue}: confetti hearts in the encore. Who's in?" },
		{ 0, "Fan chat for {artist} in {city} is open. Let's meet before doors" },
		{ 1, "Sign for {city} is done! Hope {artist} sees it" },
		{ 1, "Seat map project: everyone in sections 100-120 bring pink paper for {song}" },
		{ 1, "Banner project: '{city} LOVES {artist}'. Meet at gate 3 at 5pm" },
		{ 0, "Free water and bracelets in the queue at {venue} tomorrow, find the girl in the yellow hat" },
	},
	setlist = {
		{ 1, "{song} live is unreal" },
		{ -1, "Why didn't they play my favourite song?? Put it back in the setlist {artist}" },
		{ 1, "The {song} transition in the setlist is genius" },
		{ 0, "Setlist for {tour} leaked. Mixed feelings about the encore" },
		{ 1, "Surprise song in {city} was {song}!! Never played live before" },
		{ 0, "The setlist is the same every night but I still love it" },
		{ 1, "Acoustic version of {song} in the B-stage... crying in the club" },
		{ -1, "Dropping {song} from the setlist is a crime" },
	},
	outfit = {
		{ 1, "{artist}'s outfit tonight!! Iconic" },
		{ 1, "The second outfit change in {city} was everything" },
		{ 0, "Hot take: the {tour} outfits are better than the last tour" },
		{ 1, "Sequins, platform boots and a cape. {artist} understood the assignment" },
		{ 1, "Recreating the {tour} outfit for Halloween, wish me luck" },
		{ 0, "The {city} outfit was a bit much but {artist} made it work" },
		{ 1, "Every outfit on {tour} is a whole era" },
	},
	stage = {
		{ 1, "The {item} moment had the whole arena screaming" },
		{ 1, "Nobody talks enough about the {item} on this tour" },
		{ 1, "When the {item} started I lost it" },
		{ 1, "The {item} in {city}... the crowd went silent and then exploded" },
		{ 1, "Who designed this stage? The {item} is genius" },
		{ 1, "{tour} has the best stage I've ever seen. That {item}!!" },
		{ 0, "Rumour says the {item} cost a fortune. It shows" },
	},
	merch = {
		{ 1, "Got the {tour} hoodie. Never taking it off" },
		{ -1, "Merch line at {venue} took 2 hours. Worth it? Maybe" },
		{ 0, "Which {tour} shirt should I get? Help" },
		{ 1, "Tour shirt, tote bag, poster. My bank account says no, my heart says yes" },
		{ 1, "Merch haul from {venue}!" },
		{ -1, "Sold out of my size again. Restock the hoodies please" },
		{ 1, "Wearing my {tour} hoodie to school every day now" },
		{ 0, "Is the vinyl at the merch stand signed or just pretty?" },
	},
	sign = {
		{ 1, "{artist} signed with {label}! Big things coming" },
		{ 0, "{label} just signed {artist}. Curious what they'll do" },
		{ 1, "{artist} x {label} is the collab we needed" },
		{ 1, "Welcome to the label {artist}! Can't wait for the first tour" },
		{ 0, "New label, new era for {artist}? Let's see" },
	},
	cancel = {
		{ -1, "{tour} CANCELLED?? I already booked my train" },
		{ -1, "Refunds are fine but I wanted to see {artist}. So sad" },
		{ -1, "What is {label} doing?? First announce, then cancel" },
		{ -1, "Cancelled shows in {city}. Not the news I wanted today" },
		{ -1, "Got my refund. Still sad. {artist} come back soon" },
	},
	cancelshow = {
		{ -1, "{artist} cancelled the {city} show?? I had tickets for {venue}" },
		{ -1, "No {artist} in {city} anymore. Low sales they say. I was going!" },
		{ -1, "Refund for {venue} came in. I'd rather have the show, {label}" },
		{ 0, "Heard the {city} date of {tour} is gone. Guess I'm travelling to the next one" },
		{ -1, "Cancelled in {city} but they still play everywhere else? Hmm" },
		{ 0, "Sad about {city}, but please come back with a smaller venue {artist}" },
	},
	countdown = {
		{ 1, "{artist} in {city} is in a few days. Not sleeping until then" },
		{ 0, "Packing list for {artist}: tickets, charger, earplugs, snacks" },
		{ 1, "Learning every lyric of {song} before {city}" },
		{ 1, "Ticket printed, outfit ready, playlist on repeat. {city} here I come" },
		{ 1, "One week until {artist}! Counting the sleeps" },
		{ 0, "Should I queue at {venue} from the morning? Asking veterans" },
		{ 1, "Glitter: bought. Tissues for {song}: bought" },
		{ 1, "My ticket for {artist} is the most valuable thing I own" },
	},
}

-- photos fans attach: chance per post kind and the kinds of photo (see SocialScreen.photo)
Social.PHOTOS = {
	photo = { 1, { "stage", "selfie", "wide", "closeup", "confetti", "pyro", "phones", "barricade", "queue", "sign" } },
	show_great = { 0.35, { "stage", "wide", "phones", "confetti", "closeup" } },
	show_ok = { 0.15, { "stage", "wide" } },
	stage = { 0.7, { "pyro", "stage", "confetti", "wide" } },
	outfit = { 0.8, { "closeup" } },
	merch = { 0.75, { "merch" } },
	countdown = { 0.5, { "ticket", "queue" } },
	soldout = { 0.45, { "ticket" } },
	fanproject = { 0.6, { "sign", "phones" } },
	announce = { 0.25, { "poster" } },
}

-- what fans call the special stage items in their posts
Social.ITEM_NAMES = {
	lift = "rising lift", pyro = "pyro", fireworks = "fireworks", ledcube = "LED cube", moon = "giant moon", portal = "portal ring",
	balls = "giant balloons", wristbands = "glowing wristbands", confetti = "confetti", kinetic = "flying light bars", statue = "giant statue",
	robotarm = "robot arm", skyline = "city skyline", curtain = "curtain drop", laser = "laser show", scissor = "lift in the finale",
	ferris = "Ferris wheel", rocket = "rocket launch", hand = "giant hand", swing = "swing moment", fountain = "fountain", lighthouse = "lighthouse beam",
	vintagecar = "vintage car", throne = "throne", rainbow = "rainbow", strings = "string section", harp = "harp solo", choir = "choir", acoustic = "acoustic set",
	poplift = "pop-up lift", towerlift = "tower lift", stadiumroof = "giant stage", sparks = "spark fountains", co2 = "CO2 blasts",
	piano = "piano part", lowfog = "cloud floor", streamers = "streamer rain", house = "little house set",
	bubbles = "bubbles", snow = "snow", candles = "candle-light part", sofa = "living-room set", stringlights = "fairy lights", tvstack = "TV wall",
}

-- more posts from Data/SocialMore.lua
do
	local more = require(script:FindFirstAncestor("Headliner").Data.SocialMore)
	for kind, list in pairs(more) do
		Social.POSTS[kind] = Social.POSTS[kind] or {}
		for _, p in ipairs(list) do
			table.insert(Social.POSTS[kind], p)
		end
	end
end

return Social
