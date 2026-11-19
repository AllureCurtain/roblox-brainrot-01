-- BrainrotCatalog: the cast of Meme Tide Tycoon.
-- Every brainrot is an original meme sea creature. Each entry names its
-- rarity, its money per second, its body color and a one-line joke.
-- The server spawns these from the catalog; the client reads it for labels.

local BrainrotCatalog = {}

export type BrainrotDef = {
	Name: string,
	Rarity: string,
	Rate: number,
	Color: Color3,
	BodyColor: Color3,
	BellyColor: Color3,
	Size: number,
	Description: string,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
	Mythic = Color3.fromRGB(255, 80, 160),
	Godly = Color3.fromRGB(255, 240, 120),
}

local MUTATION_MULTIPLIERS = {
	Normal = 1,
	Golden = 2,
	Rainbow = 5,
	Frozen = 1.5,
}

local MUTATION_COLORS = {
	Normal = nil,
	Golden = Color3.fromRGB(255, 215, 0),
	Rainbow = Color3.fromRGB(255, 120, 220),
	Frozen = Color3.fromRGB(170, 230, 255),
}

-- The rarity ladder, cheapest first. Rates are dollars per second.
local BRAINROTS = {
	{
		Name = "Soggy Sockfish",
		Rarity = "Common",
		Rate = 1,
		Color = Color3.fromRGB(120, 160, 255),
		BodyColor = Color3.fromRGB(120, 160, 255),
		BellyColor = Color3.fromRGB(220, 235, 255),
		Size = 1.0,
		Description = "A fish wearing a lost sock. It smells of low tide.",
	},
	{
		Name = "Grumpy Toaster",
		Rarity = "Common",
		Rate = 2,
		Color = Color3.fromRGB(200, 200, 200),
		BodyColor = Color3.fromRGB(200, 200, 200),
		BellyColor = Color3.fromRGB(90, 90, 90),
		Size = 1.0,
		Description = "It only pops up to complain about the bread.",
	},
	{
		Name = "Captain Pickle",
		Rarity = "Rare",
		Rate = 6,
		Color = Color3.fromRGB(110, 200, 80),
		BodyColor = Color3.fromRGB(110, 200, 80),
		BellyColor = Color3.fromRGB(200, 240, 160),
		Size = 1.15,
		Description = "Sailed seven seas in a jar. Never once brined.",
	},
	{
		Name = "DJ Llama",
		Rarity = "Rare",
		Rate = 10,
		Color = Color3.fromRGB(255, 150, 200),
		BodyColor = Color3.fromRGB(255, 150, 200),
		BellyColor = Color3.fromRGB(255, 230, 240),
		Size = 1.2,
		Description = "Drops beats, spits on hecklers, never misses a set.",
	},
	{
		Name = "Sir Barksalot",
		Rarity = "Epic",
		Rate = 25,
		Color = Color3.fromRGB(190, 130, 70),
		BodyColor = Color3.fromRGB(190, 130, 70),
		BellyColor = Color3.fromRGB(245, 220, 180),
		Size = 1.3,
		Description = "Knighted for barking at the mailman. Twice.",
	},
	{
		Name = "Noodle Ninja",
		Rarity = "Epic",
		Rate = 40,
		Color = Color3.fromRGB(255, 210, 90),
		BodyColor = Color3.fromRGB(255, 210, 90),
		BellyColor = Color3.fromRGB(255, 245, 200),
		Size = 1.3,
		Description = "Slurps silently. Strikes soggily.",
	},
	{
		Name = "Quantum Quokka",
		Rarity = "Legendary",
		Rate = 100,
		Color = Color3.fromRGB(140, 220, 160),
		BodyColor = Color3.fromRGB(140, 220, 160),
		BellyColor = Color3.fromRGB(230, 255, 235),
		Size = 1.45,
		Description = "Smiles in two places at once. Physics gave up.",
	},
	{
		Name = "Emperor Penguin CEO",
		Rarity = "Legendary",
		Rate = 150,
		Color = Color3.fromRGB(40, 40, 60),
		BodyColor = Color3.fromRGB(40, 40, 60),
		BellyColor = Color3.fromRGB(245, 245, 245),
		Size = 1.5,
		Description = "Runs the iceberg. Fired the iceberg.",
	},
	{
		Name = "Galactic Garbage Goblin",
		Rarity = "Mythic",
		Rate = 400,
		Color = Color3.fromRGB(120, 255, 120),
		BodyColor = Color3.fromRGB(120, 255, 120),
		BellyColor = Color3.fromRGB(200, 255, 200),
		Size = 1.7,
		Description = "Eats planets. Complains about the seasoning.",
	},
	{
		Name = "The Infinite Sandwich",
		Rarity = "Godly",
		Rate = 1000,
		Color = Color3.fromRGB(255, 240, 120),
		BodyColor = Color3.fromRGB(255, 240, 120),
		BellyColor = Color3.fromRGB(255, 255, 255),
		Size = 1.9,
		Description = "Every layer is another sandwich. It never ends.",
	},
}

-- Spawn weights: common brainrots ride the conveyor most often.
local SPAWN_WEIGHTS = {
	["Soggy Sockfish"] = 30,
	["Grumpy Toaster"] = 25,
	["Captain Pickle"] = 15,
	["DJ Llama"] = 12,
	["Sir Barksalot"] = 8,
	["Noodle Ninja"] = 5,
	["Quantum Quokka"] = 2.5,
	["Emperor Penguin CEO"] = 1.5,
	["Galactic Garbage Goblin"] = 0.7,
	["The Infinite Sandwich"] = 0.3,
}

function BrainrotCatalog.getAll(): { BrainrotDef }
	return BRAINROTS
end

function BrainrotCatalog.getByName(name: string): BrainrotDef?
	for _, def in ipairs(BRAINROTS) do
		if def.Name == name then
			return def
		end
	end
	return nil
end

function BrainrotCatalog.getRarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
end

function BrainrotCatalog.getMutationMultiplier(mutation: string): number
	return MUTATION_MULTIPLIERS[mutation] or 1
end

function BrainrotCatalog.getMutationColor(mutation: string): Color3?
	return MUTATION_COLORS[mutation]
end

-- Rolls one brainrot name from the weighted ladder.
function BrainrotCatalog.rollRandomName(): string
	local total = 0
	for _, def in ipairs(BRAINROTS) do
		total += SPAWN_WEIGHTS[def.Name] or 1
	end
	local roll = math.random() * total
	for _, def in ipairs(BRAINROTS) do
		roll -= SPAWN_WEIGHTS[def.Name] or 1
		if roll <= 0 then
			return def.Name
		end
	end
	return BRAINROTS[1].Name
end

-- Rolls a mutation: most brainrots are Normal, a few come Golden or Frozen,
-- and a rare one arrives Rainbow.
function BrainrotCatalog.rollMutation(): string
	local roll = math.random()
	if roll < 0.02 then
		return "Rainbow"
	elseif roll < 0.10 then
		return "Golden"
	elseif roll < 0.20 then
		return "Frozen"
	end
	return "Normal"
end

-- Money per second for one brainrot, after its mutation and the owner's
-- rebirth multiplier.
function BrainrotCatalog.getRatePerSecond(def: BrainrotDef, mutation: string, rebirthMultiplier: number): number
	return def.Rate * BrainrotCatalog.getMutationMultiplier(mutation) * rebirthMultiplier
end

return BrainrotCatalog
