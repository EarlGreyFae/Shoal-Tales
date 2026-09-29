extends Node
## Static game content. Emoji are placeholder art until real sprites exist.

const BIN_KEYS := ["plastic", "metal", "wood", "electronics", "hazardous", "mixed"]
const BINS := {
	"plastic": {"n": "Plastic", "e": "🧴", "p": 2.0},
	"metal": {"n": "Metal", "e": "🔩", "p": 4.0},
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

# [name, emoji, base value, weight]
const FISH := [
	["Sardine", "🐟", 6.0, 1],
	["Snapper", "🐠", 10.0, 2],
	["Squid", "🦑", 14.0, 2],
	["Crab", "🦀", 16.0, 2],
	["Kelp", "🌿", 5.0, 1],
	["Octopus", "🐙", 24.0, 3],
	["Lobster", "🦞", 30.0, 3],
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
const STORY_LETTERS := {
	"crow1": {
		"id": "crow1", "dev": true, "crow": true, "from": "a crow",
		"t": "A crow lands on the railing, drops a folded diner receipt at your feet, and stares at you until you pick it up. On the back, in pencil:\n\n\"Nice knife work. Come ashore sometime. The diner's open till six, and people here have been expecting you.\"\n\nWhen you look up, the crow is gone. You never heard it leave.",
	},
}

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
