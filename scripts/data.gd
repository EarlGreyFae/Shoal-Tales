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

# [name, emoji, bin]
const JUNK := [
	["Grocery bag", "🛍️", "plastic"],
	["Water bottle", "🥤", "plastic"],
	["Flip-flop", "🩴", "plastic"],
	["Beach bucket", "🪣", "plastic"],
	["Pool noodle", "🌭", "plastic"],
	["Six-pack rings", "⭕", "plastic"],
	["Soda can", "🥫", "metal"],
	["Bike wheel", "🛞", "metal"],
	["Shopping cart", "🛒", "metal"],
	["Rusty wrench", "🔧", "metal"],
	["Car hubcap", "⚙️", "metal"],
	["Boat anchor", "⚓", "metal"],
	["Driftwood", "🪵", "wood"],
	["Patio chair", "🪑", "wood"],
	["Pallet plank", "📏", "wood"],
	["Soggy couch", "🛋️", "wood"],
	["TV remote", "📱", "electronics"],
	["Bluetooth speaker", "🔊", "electronics"],
	["Old laptop", "💻", "electronics"],
	["Game controller", "🎮", "electronics"],
	["Earbuds", "🎧", "electronics"],
	["Flip phone", "📞", "electronics"],
	["Car battery", "🔋", "hazardous"],
	["Paint can", "🎨", "hazardous"],
	["Motor oil jug", "🛢️", "hazardous"],
	["Aerosol can", "🧯", "hazardous"],
	["Tangled fishing line", "🧶", "mixed"],
	["Hoodie", "👕", "mixed"],
	["Sneaker", "👟", "mixed"],
	["Backpack", "🎒", "mixed"],
]

# [name, emoji, base value]
const FISH := [
	["Sardine", "🐟", 6.0],
	["Snapper", "🐠", 10.0],
	["Squid", "🦑", 14.0],
	["Crab", "🦀", 16.0],
	["Kelp", "🌿", 5.0],
	["Octopus", "🐙", 24.0],
	["Lobster", "🦞", 30.0],
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

const UP_KEYS := ["speed", "basket", "clean", "luck"]
const UPS := {
	"speed": {"n": "Faster winch", "d": "Dredge time −12%", "base": 60, "g": 1.9, "max": 8},
	"basket": {"n": "Bigger basket", "d": "+1 item per haul", "base": 80, "g": 2.0, "max": 6},
	"clean": {"n": "Soft brush", "d": "Fewer clicks to clean", "base": 100, "g": 2.5, "max": 3},
	"luck": {"n": "Lucky charm", "d": "Better rarity & magic odds", "base": 120, "g": 2.2, "max": 5},
}

const STATIONS := {
	"oven": {"n": "Oven", "e": "🔥", "cost": 150, "d": "Cooks dressed fish into meals."},
	"crucible": {"n": "Crucible", "e": "🌋", "cost": 300, "d": "Melts the metal bin into ingots."},
	"carpentry":
	{"n": "Carpentry Bench", "e": "🪚", "cost": 250, "d": "Turns the wood bin into knick-knacks."},
	"recycler":
	{"n": "Recycling Machine", "e": "♻️", "cost": 500, "d": "Breaks the mixed bin into base materials."},
}

# Processed goods: [name, emoji]
const GOODS := {
	"fish_raw": ["Fish (raw)", "🐟"],
	"fish_dressed": ["Dressed fish", "🍣"],
	"meal": ["Meals", "🍲"],
	"ingot": ["Ingots", "🧱"],
	"knick": ["Carved knick-knacks", "🪆"],
	"material": ["Base materials", "📦"],
}

# st "cut" is the Cutting Board, which every player starts with.
const RECIPES := [
	{
		"st": "cut", "n": "Cutting Board", "e": "🔪", "inp": "fish_raw", "out": "fish_dressed",
		"f": 1.6, "d": "Dress fish for a better price.",
	},
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
