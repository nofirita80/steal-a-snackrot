-- Steal a Snackrot — Config
-- Every number the game runs on lives here, in one place. The server
-- and the snack factory both read this module, so the price a player
-- is shown and the price the server charges can never drift apart.

local Config = {}

-- ---------------------------------------------------------------- bases
Config.PLOT_COUNT = 6
Config.START_SLOTS = 3
Config.MAX_SLOTS = 10
Config.PLOT_RADIUS = 55
Config.PLOT_CENTRE = Vector3.new(0, 0, 20)
Config.PLOT_SIZE = 26

-- A new slot costs 500 * 2 ^ (slots owned - 3). The 4th slot is $1,000,
-- the 5th $2,000, doubling up to the 10-slot cap.
function Config.slotCost(slotsOwned: number): number
	local extra = math.max(0, slotsOwned - Config.START_SLOTS)
	return 500 * (2 ^ extra)
end

-- ---------------------------------------------------------------- rebirth
-- A rebirth costs 10,000 * 2 ^ rebirths so far, and doubles all
-- earnings from then on.
function Config.rebirthCost(rebirths: number): number
	return 10000 * (2 ^ rebirths)
end

function Config.rebirthMultiplier(rebirths: number): number
	return 2 ^ rebirths
end

-- ---------------------------------------------------------------- conveyor
Config.CONVEYOR_SPAWN_INTERVAL = 5
Config.CONVEYOR_MAX_SNACKS = 8
Config.CONVEYOR_SPEED = 6
Config.CONVEYOR_START_X = -95
Config.CONVEYOR_END_X = 95
Config.CONVEYOR_Z = -50
Config.CONVEYOR_RIDE_HEIGHT = 1.6
Config.CLAIM_RANGE = 14
Config.INTERACT_RANGE = 9
Config.STEAL_PROTECTION_SECONDS = 30
Config.CARRY_HEIGHT = 4.5
Config.WALK_SPEED = 14

-- ---------------------------------------------------------------- base lock
Config.LOCK_DURATION = 60
Config.LOCK_COOLDOWN = 120

-- ---------------------------------------------------------------- Midnight Hunger Wave
Config.WAVE_FIRST_WARNING_DELAY = 180
Config.WAVE_WARNING_SECONDS = 30
Config.WAVE_ACTIVE_SECONDS = 20
Config.WAVE_CYCLE_SECONDS = 240
Config.WAVE_START_X = -140
Config.WAVE_END_X = 140
Config.WAVE_PARK_X = -300

-- ---------------------------------------------------------------- rarities
Config.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.RARITY_WEIGHTS = {
	Common = 40,
	Rare = 25,
	Epic = 15,
	Legendary = 10,
	Mythic = 7,
	Secret = 3,
}

Config.RARITY_COLORS = {
	Common = Color3.fromRGB(170, 170, 170),
	Rare = Color3.fromRGB(80, 140, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
	Mythic = Color3.fromRGB(255, 90, 120),
	Secret = Color3.fromRGB(255, 230, 60),
}

-- ---------------------------------------------------------------- mutations
-- Each entry: its weight in the roll, its income multiplier, its aura colour.
Config.MUTATIONS = {
	{ name = "None", weight = 70, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", weight = 15, multiplier = 2, color = Color3.fromRGB(255, 200, 40) },
	{ name = "Diamond", weight = 8, multiplier = 5, color = Color3.fromRGB(140, 220, 255) },
	{ name = "Rainbow", weight = 5, multiplier = 10, color = Color3.fromRGB(255, 120, 220) },
	{ name = "Void", weight = 2, multiplier = 25, color = Color3.fromRGB(140, 60, 220) },
}

-- ---------------------------------------------------------------- weighted rolls
-- One shared picker: add up the weights, roll inside the total, walk
-- the list until the running sum passes the roll.
local function totalWeight(entries: { { name: string, weight: number } }): number
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	return total
end

local function pickWeighted(entries: { { name: string, weight: number } }): string
	local total = totalWeight(entries)
	local roll = math.random(1, total)
	local running = 0
	for _, entry in entries do
		running += entry.weight
		if roll <= running then
			return entry.name
		end
	end
	return entries[1].name
end

function Config.rollRarity(): string
	local entries = {}
	for _, name in Config.RARITY_ORDER do
		table.insert(entries, { name = name, weight = Config.RARITY_WEIGHTS[name] })
	end
	return pickWeighted(entries)
end

function Config.rollMutation(): { name: string, multiplier: number, color: Color3 }
	local roll = math.random(1, totalWeight(Config.MUTATIONS))
	local running = 0
	for _, entry in Config.MUTATIONS do
		running += entry.weight
		if roll <= running then
			return entry
		end
	end
	return Config.MUTATIONS[1]
end

-- ---------------------------------------------------------------- the cast
-- Twelve original snack characters. `shape` tells the factory which
-- silhouette builder to use; `income` is the base $/s before mutation.
Config.CHARACTERS = {
	{ name = "Sir Crunch Toast", rarity = "Common", income = 5, shape = "toast" },
	{ name = "Baron Pickle", rarity = "Common", income = 8, shape = "pickle" },
	{ name = "DJ Noodle", rarity = "Rare", income = 20, shape = "noodle" },
	{ name = "Captain Ketchup", rarity = "Rare", income = 30, shape = "ketchup" },
	{ name = "Professor Bubblegum", rarity = "Epic", income = 75, shape = "bubblegum" },
	{ name = "General Popcorn", rarity = "Epic", income = 120, shape = "popcorn" },
	{ name = "Countess Croissant", rarity = "Legendary", income = 300, shape = "croissant" },
	{ name = "Sir Sizzle Bacon", rarity = "Legendary", income = 500, shape = "bacon" },
	{ name = "Queen Cupcake", rarity = "Mythic", income = 1200, shape = "cupcake" },
	{ name = "King Taco", rarity = "Mythic", income = 2000, shape = "taco" },
	{ name = "Lord Truffle", rarity = "Secret", income = 6000, shape = "truffle" },
	{ name = "The Golden Donut", rarity = "Secret", income = 15000, shape = "donut" },
}

function Config.charactersOfRarity(rarity: string): { { name: string, rarity: string, income: number, shape: string } }
	local out = {}
	for _, char in Config.CHARACTERS do
		if char.rarity == rarity then
			table.insert(out, char)
		end
	end
	return out
end

function Config.rollCharacter(): { name: string, rarity: string, income: number, shape: string }
	local rarity = Config.rollRarity()
	local pool = Config.charactersOfRarity(rarity)
	return pool[math.random(1, #pool)]
end

-- One snack's income: character income times the mutation multiplier.
-- The floating label and the earnings loop both call this, so the
-- number a player sees is always the number they are paid.
function Config.snackIncome(character: { income: number }, mutation: { multiplier: number }): number
	return character.income * mutation.multiplier
end

function Config.mutationByName(name: string): { name: string, multiplier: number, color: Color3 }
	for _, entry in Config.MUTATIONS do
		if entry.name == name then
			return entry
		end
	end
	return Config.MUTATIONS[1]
end

return Config
