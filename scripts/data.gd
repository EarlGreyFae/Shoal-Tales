extends Node
## Static game content. Emoji are placeholder art until real sprites exist.

const BIN_KEYS := ["plastic", "metal", "glass", "wood", "electronics", "hazardous", "mixed"]
const BINS := {
	"plastic": {"n": "Plastic", "e": "🧴", "p": 2.0},
	"metal": {"n": "Metal", "e": "🔩", "p": 4.0},
	"glass": {"n": "Glass", "e": "🫙", "p": 3.0},
	"wood": {"n": "Wood", "e": "🪵", "p": 3.0},
	"electronics": {"n": "Electronics", "e": "💾", "p": 8.0},
	"hazardous": {"n": "Hazardous", "e": "☣️", "p": 6.0},
	"mixed": {"n": "Mixed", "e": "🗑️", "p": 1.0},
}

# [name, emoji, default bin, weight 1 (earbuds) to 5 (couch)]
const JUNK := [
	["Grocery bag", "🛍️", "plastic", 1],
	["Water bottle", "🥤", "plastic", 1],
	["Flip-flop", "🩴", "plastic", 1],
	["Beach bucket", "🪣", "plastic", 2],
	["Pool noodle", "🌭", "plastic", 1],
	["Six-pack rings", "⭕", "plastic", 1],
	["Soda can", "🥫", "metal", 1],
	["Bike wheel", "🛞", "metal", 3],
	["Shopping cart", "🛒", "metal", 5],
	["Rusty wrench", "🔧", "metal", 2],
	["Car hubcap", "⚙️", "metal", 3],
	["Boat anchor", "⚓", "metal", 5],
	["Glass jar", "🫙", "glass", 1],
	["Beer bottle", "🍺", "glass", 1],
	["Mirror shard", "🪞", "glass", 1],
	["Empty bottle", "🍶", "glass", 1],
	["Driftwood", "🪵", "wood", 2],
	["Patio chair", "🪑", "wood", 3],
	["Pallet plank", "📏", "wood", 3],
	["Soggy couch", "🛋️", "wood", 5],
	["TV remote", "📱", "electronics", 1],
	["Bluetooth speaker", "🔊", "electronics", 2],
	["Old laptop", "💻", "electronics", 3],
	["Game controller", "🎮", "electronics", 1],
	["Earbuds", "🎧", "electronics", 1],
	["Flip phone", "📞", "electronics", 1],
	["Car battery", "🔋", "hazardous", 4],
	["Paint can", "🎨", "hazardous", 2],
	["Motor oil jug", "🛢️", "hazardous", 3],
	["Aerosol can", "🧯", "hazardous", 1],
	["Tangled fishing line", "🧶", "mixed", 1],
	["Hoodie", "👕", "mixed", 1],
	["Sneaker", "👟", "mixed", 1],
	["Backpack", "🎒", "mixed", 2],
	["Skateboard", "🛹", "mixed", 2],
	["Broken guitar", "🎸", "mixed", 3],
	["Umbrella", "☂️", "mixed", 1],
	["Toaster", "🍞", "electronics", 3],
]

# What Inspect says about each piece of junk. Each line hints at its default bin.
const DESCS := {
	"Grocery bag": "Thin, crinkly, and weighs nothing. It's already trying to float away.",
	"Water bottle": "Clear and squeezable, stamped with a little triangle of arrows.",
	"Flip-flop": "One rubbery sandal, bendy and bright. Its partner is out there somewhere.",
	"Beach bucket": "A molded pail with a cracked handle. Someone's sandcastle never got finished.",
	"Pool noodle": "Squishy foam in faded neon. Bends in half without complaint.",
	"Six-pack rings": "Stretchy see-through loops that once held drinks. Gulls hate these.",
	"Soda can": "Crushed, cold, and light. It rings when you flick it.",
	"Bike wheel": "Bent spokes on a rusted rim. It clanks against everything.",
	"Shopping cart": "A heavy wire frame with one squeaky wheel. Rattles like a chain.",
	"Rusty wrench": "Solid, cold, and orange with rust. A tool that's seen better days.",
	"Car hubcap": "A dented steel disc. It rings like a gong when you knock on it.",
	"Boat anchor": "Cast iron, very heavy, and still very good at its old job.",
	"Glass jar": "A clear jar with a rusted lid. Rinse it out and it'd hold anything.",
	"Beer bottle": "Brown glass, label long gone. It clinks against everything.",
	"Mirror shard": "A jagged piece of silvered glass. Your reflection looks tired. Or is that you?",
	"Empty bottle": "Clear glass, cork long gone. Whatever message it carried is gone. You could write a new one.",
	"Driftwood": "Smooth, pale, and grainy. Smells like a campfire waiting to happen.",
	"Patio chair": "Slatted boards held together with pegs. Splinters included.",
	"Pallet plank": "Rough-cut lumber with a few nail holes.",
	"Soggy couch": "Waterlogged cushions on a sturdy timber frame. The cushions are a lost cause.",
	"TV remote": "Buttons, batteries, and a little infrared eye. Still tries to change the channel.",
	"Bluetooth speaker": "Rubber-wrapped around a circuit board. It crackles when you shake it.",
	"Old laptop": "A hinged screen, a keyboard, and a motherboard full of chips and wires.",
	"Game controller": "Two thumbsticks and a circuit board. Someone lost their high score.",
	"Earbuds": "Tiny, wired, and tangled. Still faintly playing something? No. Surely not.",
	"Flip phone": "Snaps shut satisfyingly. Antenna, battery, circuit board.",
	"Car battery": "Heavy, and it sloshes. There's acid inside. Handle with gloves.",
	"Paint can": "Half full of something that shouldn't be in the ocean. The lid says FLAMMABLE.",
	"Motor oil jug": "Slick, black, and leaking a rainbow sheen. Definitely toxic.",
	"Aerosol can": "Pressurized, with a warning label: DO NOT PUNCTURE. Still has some pressure left.",
	"Tangled fishing line": "A knot of nylon, hooks and seaweed. It's many things at once.",
	"Hoodie": "A soaked cotton-and-polyester blend. No single material to it.",
	"Sneaker": "Rubber sole, fabric upper, plastic eyelets and glue. A bit of everything.",
	"Backpack": "Zippers, straps, nylon and buckles. A jumble of materials.",
	"Skateboard": "Grip tape, metal trucks, urethane wheels. Too many parts to call it one thing.",
	"Broken guitar": "Strings, tuning pegs, a pickup, a cracked body. A bit of everything.",
	"Umbrella": "A nylon canopy, a plastic handle, and a folding frame. Hard to pin down.",
	"Toaster": "A plug, heating coils and a little circuit inside a chrome shell.",
}

# Owning a station opens up new uses for some items, which changes their correct bin.
# Later entries win. Sorting by a station rule pays STATION_RULE_BONUS extra.
# "hint" is added to Inspect once the station is on board.
const STATION_RULE_BONUS := 1.5
const SORT_RULES := [
	{"st": "carpentry", "item": "Skateboard", "bin": "wood", "hint": "The deck is solid maple. Your Carpentry Bench could use that."},
	{"st": "carpentry", "item": "Broken guitar", "bin": "wood", "hint": "That hollow body is good tonewood. Your Carpentry Bench could use it."},
	{"st": "crucible", "item": "Toaster", "bin": "metal", "hint": "That chrome shell would melt down nicely in your Crucible."},
	{"st": "crucible", "item": "Umbrella", "bin": "metal", "hint": "The folding frame is steel. Your Crucible could use it."},
	{"st": "crucible", "item": "Aerosol can", "bin": "metal", "hint": "Once it's emptied, the can is thin steel. Your Crucible could use it."},
	{"st": "recycler", "item": "Sneaker", "bin": "plastic", "hint": "The Recycling Machine can strip the rubber and plastic out of it."},
	{"st": "recycler", "item": "Tangled fishing line", "bin": "plastic", "hint": "The Recycling Machine can reclaim the nylon line."},
]

# Fish by depth: each depth draws fish from a different part of the world.
# [name, emoji, base value, weight]
const FISH_BY_DEPTH := [
	[  # Shallows: the local catch
		["Sardine", "🐟", 6.0, 1],
		["Mackerel", "🐟", 8.0, 1],
		["Flounder", "🐟", 10.0, 2],
		["Rock crab", "🦀", 12.0, 2],
		["Sea bass", "🐟", 14.0, 2],
	],
	[  # Coral Reef: warm-water fish that have no business in this bay
		["Parrotfish", "🐠", 14.0, 2],
		["Clownfish", "🐠", 12.0, 1],
		["Lionfish", "🐡", 18.0, 2],
		["Spiny lobster", "🦞", 26.0, 3],
		["Reef octopus", "🐙", 22.0, 3],
	],
	[  # Deep Trench: cold, dark water from far away
		["Lanternfish", "🐟", 16.0, 1],
		["Hake", "🐟", 20.0, 2],
		["King crab", "🦀", 34.0, 4],
		["Giant squid (a small one)", "🦑", 30.0, 4],
		["Monkfish", "🐡", 26.0, 3],
	],
	[  # The Abyss: things nobody can identify
		["Anglerfish", "🐡", 40.0, 3],
		["Vampire squid", "🦑", 44.0, 3],
		["Gulper eel", "🐍", 38.0, 3],
		["Ghost shark", "🦈", 60.0, 5],
		["A fish with no name", "🐟", 80.0, 2],
	],
]

const CURIOS := [
	["Class ring", "💍"],
	["Snow globe", "🔮"],
	["Instant camera", "📷"],
	["Wristwatch", "⌚"],
	["Action figure", "🧸"],
	["Bowling trophy", "🏆"],
	["Locket", "📿"],
	["Cassette mixtape", "📼"],
	["Souvenir mug", "☕"],
	["Motel room key", "🔑"],
]

const ANIMALS := [["Sea turtle", "🐢"], ["Seal pup", "🦭"], ["Seagull", "🐦"], ["Otter", "🦦"]]

# [rarity, value multiplier, weight out of 100]
const RARITY := [["common", 1.0, 60], ["uncommon", 2.5, 25], ["rare", 6.0, 11], ["epic", 15.0, 4]]

const MAGIC := [
	{"id": "pearl", "n": "Warm Sea Glass", "e": "🫧", "d": "+5% payout"},
	{"id": "tooth", "n": "Stopped Pocket Watch", "e": "⏱️", "d": "−5% dredge time"},
	{"id": "lantern", "n": "Radio That Hums When Off", "e": "📻", "d": "+1 basket slot"},
	{"id": "crown", "n": "Photo of an Empty Room", "e": "🖼️", "d": "+15% curio value"},
	{"id": "compass", "n": "Compass That Points Inland", "e": "🧭", "d": "Better curio rarity"},
	{"id": "heart", "n": "Lighthouse Key", "e": "🗝️", "d": "+10% payout"},
]

# w = relative odds of each kind of catch at this depth
const DEPTHS := [
	{
		"n": "Shallows", "cost": 0, "m": 1.0,
		"w": {"junk": 56, "fish": 14, "curio": 7, "crate": 5, "bottle": 6, "animal": 6},
	},
	{
		"n": "Coral Reef", "cost": 200, "m": 1.5,
		"w": {"junk": 42, "fish": 26, "curio": 12, "crate": 6, "bottle": 7, "animal": 7},
	},
	{
		"n": "Deep Trench", "cost": 800, "m": 2.2,
		"w": {"junk": 46, "fish": 14, "curio": 18, "crate": 8, "bottle": 7, "animal": 7},
	},
	{
		"n": "The Abyss", "cost": 3000, "m": 3.5,
		"w": {"junk": 38, "fish": 14, "curio": 24, "crate": 10, "bottle": 8, "animal": 6},
	},
]

const MAX_BASKET := 32
const UP_KEYS := ["basket", "speed", "clean", "luck"]
# Basket size at which each extra upgrade shows up on the Work Table.
const UP_REVEAL := {"basket": 0, "speed": 6, "clean": 10, "luck": 16}
const UPS := {
	"speed": {"n": "Faster winch", "d": "Dredge time −12%", "base": 60, "g": 1.9, "max": 8},
	# Basket cost is base + sq * level², tuned so reaching 32 slots takes about a day of play.
	"basket": {"n": "Bigger basket", "d": "+1 item per haul", "base": 20, "sq": 70, "max": 29},
	"clean": {"n": "Soft brush", "d": "Fewer clicks to clean", "base": 100, "g": 2.5, "max": 3},
	"luck": {"n": "Lucky charm", "d": "Better rarity & magic odds", "base": 120, "g": 2.2, "max": 5},
}

# Stations beyond the Cutting Board open up once the basket is full size, one at a time.
const STATIONS_UNLOCK_BASKET := 32
const STATION_ORDER := ["oven", "carpentry", "crucible", "recycler"]
# "needs" is a hidden requirement: how many of something you've handled since the last
# station was installed. The player only sees "tease" until it's met.
const STATIONS := {
	"oven": {
		"n": "Oven", "e": "🔥", "cost": 30000, "d": "Cooks dressed fish into meals.",
		"needs": {"stat": "dressed", "count": 40},
		"tease": "You catch yourself wondering what all this fish would taste like cooked.",
	},
	"carpentry": {
		"n": "Carpentry Bench", "e": "🪚", "cost": 60000,
		"d": "Turns the wood bin into knick-knacks.",
		"needs": {"stat": "wood", "count": 150},
		"tease": "The wood bin is filling up. It seems a shame to just sell good lumber.",
	},
	"crucible": {
		"n": "Crucible", "e": "🌋", "cost": 100000, "d": "Melts the metal bin into ingots.",
		"needs": {"stat": "metal", "count": 200},
		"tease": "All that scrap metal. If only you had a way to melt it down.",
	},
	"recycler": {
		"n": "Recycling Machine", "e": "♻️", "cost": 160000,
		"d": "Breaks the mixed bin into base materials.",
		"needs": {"stat": "mixed", "count": 200},
		"tease": "The mixed bin is the one nobody wants. There must be something useful in there.",
	},
}

# Processed goods: [name, emoji]
const GOODS := {
	"fish_dressed": ["Dressed fish", "🍣"],
	"meal": ["Meals", "🍲"],
	"ingot": ["Ingots", "🧱"],
	"knick": ["Carved knick-knacks", "🪆"],
	"material": ["Base materials", "📦"],
}

# Dressing a fish on the Cutting Board multiplies its value by this.
const DRESS_MULT := 1.6

# Stations that process a whole stock at once. (The Cutting Board is hands-on and separate.)
const RECIPES := [
	{
		"st": "oven", "n": "Oven", "e": "🔥", "inp": "fish_dressed", "out": "meal",
		"f": 2.2, "d": "Cook dressed fish into meals.",
	},
	{
		"st": "crucible", "n": "Crucible", "e": "🌋", "inp": "bin_metal", "out": "ingot",
		"f": 2.5, "d": "Melt metal into ingots.",
	},
	{
		"st": "carpentry", "n": "Carpentry Bench", "e": "🪚", "inp": "bin_wood", "out": "knick",
		"f": 2.2, "d": "Build knick-knacks from wood.",
	},
	{
		"st": "recycler", "n": "Recycling Machine", "e": "♻️", "inp": "bin_mixed", "out": "material",
		"f": 3.0, "d": "Reduce mixed trash to materials.",
	},
]

# PLACEHOLDER lore - replace with your own Lore Letters.
# Tone: sleepy modern town where something is quietly wrong.
const LETTERS := [
	{
		"id": "d1", "dev": true, "from": "Unsigned",
		"t": "Welcome to town. The diner opens at six, the ferry doesn't run on Sundays, and nobody talks about the lighthouse. You'll fit right in.",
	},
	{
		"id": "d2", "dev": true, "from": "Unsigned",
		"t": "Funny thing about this bay. The tide goes out twice a day, like anywhere. Some nights it comes back in three times.",
	},
	{
		"id": "d3", "dev": true, "from": "Unsigned",
		"t": "If you dredge up anything with my name on it, throw it back. I'm serious. I haven't lost anything yet.",
	},
	{
		"id": "d4", "dev": true, "from": "Unsigned",
		"t": "Six things came out of the water the year the lighthouse went dark. Everyone in town knows. Nobody in town will tell you.",
	},
	{
		"id": "d5", "dev": true, "from": "Unsigned",
		"t": "You've been here before. Don't worry. It's always a little easier the second time.",
	},
]

# Story letters arrive at set moments, never in bottles.
# Crow (Walt's old supplier) writes these; Zephyr, his crow, carries them to the Desk when
# something new opens up. Keys double as story beats. Told once: never delivered in sandbox.
const STORY_LETTERS := {
	"crow1": {
		"id": "crow1", "dev": true, "crow": true, "from": "a crow",
		"t": "A crow lands on the railing, drops a folded diner receipt at your feet, and stares at you until you pick it up. On the back, in pencil:\n\n\"Nice knife work. Walt at the Low Tide Diner needs fish, and you have fish. Go ashore.\n— C.\"\n\nWhen you look up, the crow is gone. You never heard it leave.",
	},
	"crow_oven": {
		"id": "crow_oven", "dev": true, "crow": true, "from": "a crow",
		"t": "The crow is back, with a recipe card in its beak. Most of it is smudged. The legible part:\n\n\"Walt's cooking again. Good. Cook it low and slow, and it'll tell you where it came from.\n— C.\"",
	},
	"crow_carpentry": {
		"id": "crow_carpentry", "dev": true, "crow": true, "from": "Zephyr",
		"t": "A wood shaving, curled like a ribbon, tied to the crow's leg. Written along it:\n\n\"Her name is Zephyr. She's been flying for me longer than I've been writing to you. Don't give her french fries, no matter what she tells you.\n— C.\"",
	},
	"crow_crucible": {
		"id": "crow_crucible", "dev": true, "crow": true, "from": "Zephyr",
		"t": "Zephyr drops a hardware store receipt for one (1) padlock, paid in cash, dated forty years ago. On the back:\n\n\"I dredged this bay for eleven years. It took everything I had and kept asking for more. I wasn't unlucky. I was looking for the wrong thing.\n— C.\"",
	},
	"crow_recycler": {
		"id": "crow_recycler", "dev": true, "crow": true, "from": "Zephyr",
		"t": "A torn page from a tide table. Someone has circled a date that hasn't happened yet.\n\n\"There's an empty storefront on Main Street. It was going to be mine. You'll need more than money to open it; ask around town. They'll help you. They always would have helped me, if I'd asked.\n— C.\"",
	},
	"crow_emporium": {
		"id": "crow_emporium", "dev": true, "crow": true, "from": "Crow",
		"t": "Zephyr is waiting on the Emporium's counter the morning you open, with a brass key and a long letter.\n\n\"You did it the way I never could. I kept pulling things out of the water, hoping one of them would be the answer. You made something out of what the bay gave you, and you gave it back to the town.\n\nWalt was my friend. Tell him I'm sorry I left without a word. Tell him I'm all right.\n\nZephyr's decided she likes you better. Keep her. Keep the lights on at night.\n— Crow\"",
	},
}

# Rare materials: can't be dredged, only earned from townsfolk. The Emporium needs them.
const RARES := {
	"stained_glass": {"n": "Stained glass panes", "e": "🪟"},
	"old_timber": {"n": "Old-growth timber", "e": "🌲"},
	"brass": {"n": "Brass fittings", "e": "🔔"},
	"neon": {"n": "Vintage neon sign", "e": "💡"},
	"ledger": {"n": "Crow's ledger", "e": "📒"},
}
const EMPORIUM_RARES := {"stained_glass": 2, "old_timber": 3, "brass": 3, "neon": 1}

# Goods that only exist once a station is installed (so standing orders don't ask for them early).
const GOOD_STATION := {"meal": "oven", "knick": "carpentry", "ingot": "crucible", "material": "recycler"}

# Townsfolk requests, offered in order per person. "needs" is {"good": key, "n": N} (goods
# key, "cooler" for raw fish) or {"fish": name, "n": N}. "requires" gates when it's offered.
# Once someone's list is done, they give repeatable standing orders instead (see game.gd).
const QUESTS := [
	{
		"id": "w1", "npc": "cook", "title": "Supper rush",
		"needs": {"good": "fish_dressed", "n": 5}, "reward": {"coins": 150},
		"ask": "\"Supper rush tonight and my walk-in's empty. Five dressed fish, and I'll pay extra for the trouble.\"",
		"done": "\"You dress 'em cleaner than Crow ever did.\" He catches your look. \"My old supplier. Everybody called him Crow, on account of the bird that followed him everywhere. Big black thing. Had a name, too. Zephyr, I think.\"",
	},
	{
		"id": "w2", "npc": "cook", "title": "A taste of the reef", "requires": {"depth": 1},
		"needs": {"fish": "Parrotfish", "n": 3}, "reward": {"coins": 600},
		"ask": "\"Folks keep asking about those reef fish turning up in the bay. Bring me three parrotfish and I'll put 'em on the specials board.\"",
		"done": "\"Crow brought me reef fish too, near the end. Said the deeper he went, the stranger the bay got. Said he was looking for something down there. Never did say what.\"",
	},
	{
		"id": "w3", "npc": "cook", "title": "Crow's tab", "requires": {"station": "oven"},
		"needs": {"good": "meal", "n": 10}, "reward": {"coins": 5000, "rares": {"ledger": 1}},
		"ask": "\"Found something of Crow's cleaning out the back. Cook me ten meals for the Friday crowd and it's yours. He'd want someone to have it.\"",
		"done": "He hands you a water-stained ledger. Every page lists catches, dates and depths in tidy pencil. The last page just says: \"Not money. Something to build.\"",
	},
	{
		"id": "d1", "npc": "salvage", "title": "Short on scrap",
		"needs": {"good": "bin_metal", "n": 20}, "reward": {"coins": 200},
		"ask": "\"I've got an order I can't fill. Twenty pieces of sorted metal.\"",
		"done": "\"Crow sold me scrap too, before he went under. Always said the bay gives back what you put into it. Never figured out what he meant.\"",
	},
	{
		"id": "d2", "npc": "salvage", "title": "Windows on the hill", "requires": {"quest": "d1"},
		"needs": {"good": "bin_glass", "n": 30}, "reward": {"coins": 1500, "rares": {"stained_glass": 2}},
		"ask": "\"The old church on the hill is fixing its windows. Thirty pieces of sorted glass and I'll split what they pay me.\"",
		"done": "\"They sent over some old panes they didn't need. Stained glass. Figured you'd find a use for it.\"",
	},
	{
		"id": "r1", "npc": "antiques", "title": "Something for the window",
		"needs": {"good": "knick", "n": 10}, "reward": {"coins": 20000, "rares": {"old_timber": 3}},
		"ask": "\"Ten of your carvings for the front window, dear. People stop and look now.\"",
		"done": "She pays you, then presses a bundle of timber into your arms. \"Old-growth. From the lighthouse keeper's cottage, when they pulled it down. It ought to go into something that lasts.\"",
	},
	{
		"id": "h1", "npc": "hardware", "title": "The marina order",
		"needs": {"good": "ingot", "n": 10}, "reward": {"coins": 40000, "rares": {"brass": 3}},
		"ask": "\"Ten ingots. Got a big order from the marina and nobody to cast for it.\"",
		"done": "\"Here. Brass fittings. Crow ordered these years back and never picked 'em up. Paid in full, though. Seems right they go to you.\"",
	},
	{
		"id": "p1", "npc": "coop", "title": "Summer workshop",
		"needs": {"good": "material", "n": 10}, "reward": {"coins": 60000, "rares": {"neon": 1}},
		"ask": "\"Ten loads of reclaimed material for the summer workshop? The kids are building a boat.\"",
		"done": "\"We rewired an old sign we found behind the co-op. It says EMPORIUM. Nobody knows where it came from. We think it's yours.\"",
	},
]

# People in town. Each one buys the goods from the stations they care about.
# "unlock" is a story beat (a crow letter that has been read) or a station on board.
const NPC_ORDER := ["cook", "salvage", "antiques", "hardware", "coop"]
const NPCS := {
	"cook": {
		"n": "Walt", "role": "Cook at the Low Tide Diner", "e": "👨‍🍳",
		"unlock": {"story": "crow1_read"},
		"buys": ["cooler", "fish_dressed", "meal"],
		"intro": "The diner is empty except for a tired man in an apron, scraping a grill that's already clean. He reads the crow's receipt twice.\n\n\"Don't know who sent this. Don't much care, either.\" He sets down the scraper. \"My fish supplier got foreclosed on last month. Shore dredger, like you. Went bankrupt trying to make a living off those waters. Maybe he just wasn't lucky.\"\n\nHe looks out the window at the bay. \"Strange shore, this. Fish turn up here that belong on the other side of the world. The deeper you drop, the stranger they get. You bring me what you catch, I'll pay you fair for it. Deal?\"",
		"lines": [
			"\"Morning. What'd the bay give you today?\"",
			"\"Had a guy in yesterday swear he saw a parrotfish off the pier. In October.\"",
			"\"Dressed fish sells better. My knife hand isn't what it was.\"",
			"\"Coffee's on the house for suppliers. Don't tell anybody.\"",
		],
	},
	"salvage": {
		"n": "Dot", "role": "Runs the salvage yard", "e": "🧰",
		"unlock": {"story": "crow1_read"},
		"buys": [
			"bin_plastic", "bin_metal", "bin_glass", "bin_wood", "bin_electronics", "bin_hazardous",
			"bin_mixed",
		],
		"intro": "Behind a chain-link fence, someone in coveralls is sorting a mountain of scrap by hand. They don't look up.\n\n\"Walt said you'd come by. I take anything that's sorted. Anything that isn't sorted, I don't want to hear about.\"",
		"lines": [
			"\"Sorted? Good. Put it on the scale.\"",
			"\"Found a wedding ring in a load of hubcaps once. Still don't know whose.\"",
			"\"Hazardous goes in the yellow drum. Always the yellow drum.\"",
		],
	},
	"antiques": {
		"n": "Rosalind", "role": "Albright Antiques & Oddities", "e": "🕰️",
		"unlock": {"station": "carpentry"},
		"buys": ["knick"],
		"intro": "A bell rings as you open the door. The shop is full of clocks, and every one of them is stopped at a different time.\n\n\"Handmade pieces? From driftwood?\" She turns one of your carvings over in her hands. \"People pay for things with a story. I'll take whatever you make.\"",
		"lines": [
			"\"Mind the clocks. They're sensitive.\"",
			"\"That one in the window? Not for sale. Never has been.\"",
		],
	},
	"hardware": {
		"n": "Hank", "role": "Hank's Hardware", "e": "🔨",
		"unlock": {"station": "crucible"},
		"buys": ["ingot"],
		"intro": "\"You're melting down scrap out there? On a boat?\" He whistles. \"Bring me clean ingots and I'll buy every one. Nobody around here does their own casting anymore.\"",
		"lines": [
			"\"Need a padlock? Everyone's been buying padlocks this week.\"",
			"\"Good weight on these. Real good.\"",
		],
	},
	"coop": {
		"n": "Priya", "role": "The Makers' Co-op", "e": "🧵",
		"unlock": {"station": "recycler"},
		"buys": ["material"],
		"intro": "The co-op smells like sawdust and solder. Priya waves you in with a glue gun.\n\n\"Reclaimed materials? From the bay? Oh, we'll use every scrap. People here make beautiful things out of what gets thrown away.\"",
		"lines": [
			"\"Somebody made a whole lamp out of your fishing line!\"",
			"\"Everything's useful to someone.\"",
		],
	},
}

# Opens once every station is installed: sell everything at once from Storage.
const EMPORIUM_COST := 500000

# Stand-ins for player letters until there is a server to share them.
const SEED_COMMUNITY := [
	{
		"id": "c1", "from": "Anonymous", "score": 2,
		"t": "To whoever finds this: the sunset from my porch is the best thing I own. Go watch one today.",
	},
	{
		"id": "c2", "from": "Anonymous", "score": 1,
		"t": "My OC Marlo wants you to know the kelp is NOT haunted. Ignore the humming.",
	},
	{
		"id": "c3", "from": "Anonymous", "score": 3,
		"t": "Drink some water and stretch. Yes, you. Right now.",
	},
]

const TITLES := [
	"New in Town", "Weekend Dredger", "Salvager", "Local Regular", "Shore Warden", "Town Legend"
]
