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
	},
	price_high = {
		{ -1, "{price} for {artist}?? My wallet is crying" },
		{ -1, "Love {artist} but {price} a ticket is a lot. Hope it's worth it" },
		{ -1, "Ticket prices for {tour} are wild. Students can't afford this" },
	},
	price_low = {
		{ 1, "Only {price} for {artist}? That's actually fair. Buying two!" },
		{ 1, "Respect to {label} for keeping tickets affordable" },
	},
	soldout = {
		{ 1, "{venue} SOLD OUT for {artist}! We did that {tag}" },
		{ 1, "Got my tickets for {city} before it sold out. Still shaking" },
		{ -1, "Sold out in minutes and I got nothing. Please add a second night in {city}!" },
		{ -1, "Resale prices for {artist} in {city} are criminal" },
		{ 0, "{artist} sold out {venue}. Next stop: stadiums?" },
	},
	lowsales = {
		{ -1, "Lots of tickets still left for {artist} at {venue}... come on {city}!" },
		{ 0, "Is anyone else going to {artist} in {city}? Want to meet up!" },
		{ -1, "Maybe {venue} was a bit too big for {artist} right now" },
		{ 0, "Tickets for {artist} in {city} still available. Last chance!" },
	},
	show_great = {
		{ 1, "{artist} at {venue} was LIFE CHANGING {tag}" },
		{ 1, "I screamed so much at {artist} tonight that I have no voice left" },
		{ 1, "Best concert of my life. {city} was so loud tonight" },
		{ 1, "{song} live hit different. I cried. Twice." },
		{ 1, "The production for {tour} is insane. Every song had a moment" },
		{ 1, "Still not over last night. {artist} in {city} 10/10" },
		{ 1, "{artist} said {city} was the loudest crowd of the tour and I believe it" },
	},
	show_ok = {
		{ 0, "{artist} in {city} was good! Sound was a bit quiet where I stood" },
		{ 0, "Fun night at {venue}. Wish the show was a bit longer" },
		{ 1, "{song} was the highlight for me. Crowd was a bit sleepy though" },
		{ 0, "Solid show from {artist}. Not the best, not the worst" },
		{ -1, "The stage looked kind of empty for a venue that big" },
	},
	show_bad = {
		{ -1, "{artist} in {city}... honestly disappointing" },
		{ -1, "Paid {price} for that? The stage was so bare" },
		{ -1, "Couldn't see anything from my seat and the show felt rushed" },
		{ -1, "Love {artist} but tonight wasn't it. Hope the next shows are better" },
		{ -1, "Half the songs I wanted weren't even played" },
	},
	photo = {
		{ 1, "me and the girls at {venue} last night!!" },
		{ 1, "front row for {artist}. Worth every hour in the queue" },
		{ 1, "Matching outfits for {tour} with my best friend" },
		{ 1, "View from my seat in {city}. Unreal" },
		{ 1, "We made it to {artist}! {tag}" },
		{ 1, "Group photo before the show, the queue was already huge" },
	},
	fanproject = {
		{ 1, "FAN PROJECT for {city}: everyone hold up a light during {song}! Spread the word {tag}" },
		{ 1, "Fan project: we're printing signs that say 'THANK YOU {artist}' for the {city} show" },
		{ 1, "Making friendship bracelets for {tour}. 200 done, 300 to go" },
		{ 1, "Fan project for {venue}: confetti hearts in the encore. Who's in?" },
		{ 0, "Fan chat for {artist} in {city} is open. Let's meet before doors" },
	},
	setlist = {
		{ 1, "{song} live is unreal" },
		{ -1, "Why didn't they play my favourite song?? Put it back in the setlist {artist}" },
		{ 1, "The {song} transition in the setlist is genius" },
		{ 0, "Setlist for {tour} leaked. Mixed feelings about the encore" },
	},
	outfit = {
		{ 1, "{artist}'s outfit tonight!! Iconic" },
		{ 1, "The second outfit change in {city} was everything" },
		{ 0, "Hot take: the {tour} outfits are better than the last tour" },
	},
	stage = {
		{ 1, "The {item} moment had the whole arena screaming" },
		{ 1, "Nobody talks enough about the {item} on this tour" },
		{ 1, "When the {item} started I lost it" },
	},
	merch = {
		{ 1, "Got the {tour} hoodie. Never taking it off" },
		{ -1, "Merch line at {venue} took 2 hours. Worth it? Maybe" },
		{ 0, "Which {tour} shirt should I get? Help" },
	},
	sign = {
		{ 1, "{artist} signed with {label}! Big things coming" },
		{ 0, "{label} just signed {artist}. Curious what they'll do" },
		{ 1, "{artist} x {label} is the collab we needed" },
	},
	cancel = {
		{ -1, "{tour} CANCELLED?? I already booked my train" },
		{ -1, "Refunds are fine but I wanted to see {artist}. So sad" },
		{ -1, "What is {label} doing?? First announce, then cancel" },
	},
	countdown = {
		{ 1, "{artist} in {city} is in a few days. Not sleeping until then" },
		{ 0, "Packing list for {artist}: tickets, charger, earplugs, snacks" },
		{ 1, "Learning every lyric of {song} before {city}" },
	},
}

-- what fans call the special stage items in their posts
Social.ITEM_NAMES = {
	lift = "rising lift", pyro = "pyro", fireworks = "fireworks", ledcube = "LED cube", moon = "giant moon", portal = "portal ring",
	balls = "giant balloons", wristbands = "glowing wristbands", confetti = "confetti", kinetic = "flying light bars", statue = "giant statue",
	robotarm = "robot arm", skyline = "city skyline", curtain = "curtain drop", laser = "laser show", scissor = "lift in the finale",
	piano = "piano part", lowfog = "cloud floor", streamers = "streamer rain", house = "little house set",
}

return Social
