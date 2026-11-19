-- GameConfig: every tuning number for Meme Tide Tycoon lives here,
-- so the server modules never hard-code a price, a timer or a limit.

local GameConfig = {}

-- Money
GameConfig.STARTING_CASH = 100
GameConfig.REBIRTH_CASH_REQUIREMENT = 10000
GameConfig.REBIRTH_MULTIPLIER_PER_REBIRTH = 2
GameConfig.MAX_REBIRTHS = 5
GameConfig.REBIRTH_REQUIRES_MYTHIC = true -- owning a Mythic also qualifies

-- Bases
GameConfig.MAX_PLAYERS = 8
GameConfig.BASE_SLOTS_START = 3
GameConfig.BASE_SLOTS_MAX = 8
GameConfig.EXTRA_SLOT_COST = 500
GameConfig.BASE_LOCK_DURATION = 60 -- seconds a base stays locked
GameConfig.BASE_LOCK_COOLDOWN = 120 -- seconds before it can lock again

-- Conveyor
GameConfig.CONVEYOR_SPAWN_INTERVAL = 4 -- seconds between brainrots
GameConfig.CONVEYOR_MAX_ACTIVE = 8
GameConfig.CONVEYOR_SPEED = 6 -- studs per second along the lane
GameConfig.CONVEYOR_START = Vector3.new(-70, 3, 0)
GameConfig.CONVEYOR_END = Vector3.new(70, 3, 0)
GameConfig.CONVEYOR_DESPAWN_TIME = 45 -- seconds before an unbought brainrot leaves

-- Buying
GameConfig.BUY_PRICE_MULTIPLIER = 10 -- a brainrot costs rate * 10 cash

-- Shop upgrades
GameConfig.WALK_SPEED_COST = 250
GameConfig.WALK_SPEED_BONUS = 2 -- studs per second per purchase
GameConfig.WALK_SPEED_MAX = 5 -- purchases
GameConfig.MUTATION_ROLL_COST = 300
GameConfig.MUTATION_ROLL_MAX = 10 -- rolls per brainrot per life

-- Stealing
GameConfig.STEAL_CARRY_SPEED = 14 -- studs per second while carrying
GameConfig.STEAL_TOUCH_DISTANCE = 6 -- studs: owner touching thief recovers it

-- Tsunami
GameConfig.TSUNAMI_INTERVAL = 90 -- seconds between waves
GameConfig.TSUNAMI_WARNING_TIME = 10 -- seconds of warning before the wave
GameConfig.TSUNAMI_WAVE_SPEED = 40 -- studs per second across the map

-- World layout (must match default.project.json)
GameConfig.SPAWN_POSITION = Vector3.new(0, 5, 40)
GameConfig.SHOP_POSITION = Vector3.new(0, 3, 55)
GameConfig.BASE_POSITIONS = {
	Vector3.new(-60, 1, -55),
	Vector3.new(-20, 1, -70),
	Vector3.new(20, 1, -70),
	Vector3.new(60, 1, -55),
	Vector3.new(-60, 1, 55),
	Vector3.new(-20, 1, 70),
	Vector3.new(20, 1, 70),
	Vector3.new(60, 1, 55),
}
GameConfig.BASE_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 255, 150),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(200, 130, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(100, 230, 230),
	Color3.fromRGB(255, 130, 200),
}

return GameConfig
