-- Config: the single source of truth for Steal a Snackrot.
-- Characters, rarities, mutations, economy and wave tuning live here so
-- GameServer, SnackFactory and the client HUD all read the same numbers.

local Config = {}

-- How many base plots the map builds (one per player, first come first served).
Config.MAX_PLOTS = 6

-- Base slots a new player starts with, and the hard cap (rebirths add slots too).
Config.START_SLOTS = 3
Config.MAX_SLOTS = 10

-- A slot purchase costs 500 * 2 ^ (slots owned - START_SLOTS).
Config.SLOT_BASE_COST = 500

-- Rebirth cost: 10000 * 2 ^ rebirths. Each rebirth doubles earnings and adds a slot.
Config.REBIRTH_BASE_COST = 10000

-- Conveyor behaviour.
Config.SPAWN_INTERVAL = 5 -- seconds between spawn attempts
Config.MAX_ON_BELT = 8
Config.BELT_SPEED = 6 -- studs per second
Config.BELT_MIN_X = -95
Config.BELT_MAX_X = 95
Config.BELT_Z = -50
Config.BELT_Y = 1.6 -- ride height of a snack's root part above the belt (belt top is y=1.5)

-- Steal rules.
Config.STEAL_PROTECT_SECONDS = 30 -- a stolen snack cannot be stolen again for this long
Config.CARRY_HEIGHT = 4.5 -- how high above the carrier's head a stolen snack rides

-- Base lock: 60s locked, then a 120s cooldown before it can be locked again.
Config.LOCK_SECONDS = 60
Config.LOCK_COOLDOWN_SECONDS = 120

-- Midnight Hunger Wave: first warning 180s after the server starts, then a
-- 30s warning, a 20s sweep, and the cycle repeats every 240s.
Config.WAVE_FIRST_WARNING_AT = 180
Config.WAVE_CYCLE_SECONDS = 240
Config.WAVE_WARNING_SECONDS = 30
Config.WAVE_ACTIVE_SECONDS = 20

-- Rarity ladder. weight = spawn weight on the conveyor.
Config.RARITIES = {
	Common = { weight = 40, color = Color3.fromRGB(180, 180, 180) },
	Rare = { weight = 25, color = Color3.fromRGB(80, 170, 255) },
	Epic = { weight = 15, color = Color3.fromRGB(180, 90, 255) },
	Legendary = { weight = 10, color = Color3.fromRGB(255, 180, 40) },
	Mythic = { weight = 7, color = Color3.fromRGB(255, 80, 120) },
	Secret = { weight = 3, color = Color3.fromRGB(255, 220, 0) },
}

-- Mutation roll on spawn. multiplier applies to the character's $/sec.
Config.MUTATIONS = {
	{ name = "None", weight = 70, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", weight = 15, multiplier = 2, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Diamond", weight = 8, multiplier = 5, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Rainbow", weight = 5, multiplier = 10, color = Color3.fromRGB(255, 120, 220) },
	{ name = "Void", weight = 2, multiplier = 25, color = Color3.fromRGB(140, 80, 255) },
}

-- The cast: 12 original snack characters. builder names a function in
-- SnackFactory that assembles the character from Parts; income is base $/sec.
--
-- Economy tuning notes (keep these in step when retuning):
-- - Base incomes climb the ladder from $5/s (Common) to $15,000/s (Secret),
--   roughly x2.5–x4 per rarity step, so a rarer snack always beats a common
--   one even before mutations.
-- - Mutations multiply income (Golden x2, Diamond x5, Rainbow x10, Void x25),
--   so a mutated Common can rival a plain Rare — that is intentional, it keeps
--   the belt exciting at every rarity.
-- - Rebirths double ALL earnings per rebirth and cost 10,000 * 2^n, so the
--   first rebirth pays for itself in a few minutes of Secret-tier income but
--   takes much longer at Common tier — the intended progression gate.
Config.CHARACTERS = {
	{ name = "Sir Crunch Toast", rarity = "Common", income = 5, builder = "Toast" },
	{ name = "Baron Pickle", rarity = "Common", income = 8, builder = "Pickle" },
	{ name = "DJ Noodle", rarity = "Rare", income = 20, builder = "Noodle" },
	{ name = "Captain Ketchup", rarity = "Rare", income = 30, builder = "Ketchup" },
	{ name = "Professor Bubblegum", rarity = "Epic", income = 75, builder = "Bubblegum" },
	{ name = "General Popcorn", rarity = "Epic", income = 120, builder = "Popcorn" },
	{ name = "Countess Croissant", rarity = "Legendary", income = 300, builder = "Croissant" },
	{ name = "Sir Sizzle Bacon", rarity = "Legendary", income = 500, builder = "Bacon" },
	{ name = "Queen Cupcake", rarity = "Mythic", income = 1200, builder = "Cupcake" },
	{ name = "King Taco", rarity = "Mythic", income = 2000, builder = "Taco" },
	{ name = "Lord Truffle", rarity = "Secret", income = 6000, builder = "Truffle" },
	{ name = "The Golden Donut", rarity = "Secret", income = 15000, builder = "Donut" },
}

-- Weighted pick of a character definition from the rarity ladder.
function Config.rollCharacter()
	local total = 0
	for _, rarity in pairs(Config.RARITIES) do
		total += rarity.weight
	end
	local roll = math.random(1, total)
	local pickedRarity = "Common"
	for rarityName, rarity in pairs(Config.RARITIES) do
		roll -= rarity.weight
		if roll <= 0 then
			pickedRarity = rarityName
			break
		end
	end
	local pool = {}
	for _, def in ipairs(Config.CHARACTERS) do
		if def.rarity == pickedRarity then
			table.insert(pool, def)
		end
	end
	-- Defensive: every rarity has at least one character today, so this never
	-- triggers — it only guards a future table edit that empties a rarity.
	if #pool == 0 then
		return Config.CHARACTERS[1]
	end
	return pool[math.random(1, #pool)]
end

-- Weighted pick of a mutation.
function Config.rollMutation()
	local total = 0
	for _, mutation in ipairs(Config.MUTATIONS) do
		total += mutation.weight
	end
	local roll = math.random(1, total)
	for _, mutation in ipairs(Config.MUTATIONS) do
		roll -= mutation.weight
		if roll <= 0 then
			return mutation
		end
	end
	return Config.MUTATIONS[1]
end

-- Cost of the next base slot for a player who already owns `ownedSlots` slots.
function Config.slotCost(ownedSlots)
	return Config.SLOT_BASE_COST * (2 ^ math.max(0, ownedSlots - Config.START_SLOTS))
end

-- Cost of the next rebirth for a player who already has `rebirths` rebirths.
function Config.rebirthCost(rebirths)
	return Config.REBIRTH_BASE_COST * (2 ^ rebirths)
end

-- Earnings multiplier from rebirths: x2 per rebirth, stacking.
function Config.rebirthMultiplier(rebirths)
	return 2 ^ rebirths
end

-- Base $/sec of one snack: its character income times its mutation multiplier.
-- The single place this is computed — SnackFactory's label and GameServer's
-- earnings must agree, so both read it from here instead of multiplying inline.
function Config.incomeOf(def, mutation)
	return def.income * mutation.multiplier
end

return Config
