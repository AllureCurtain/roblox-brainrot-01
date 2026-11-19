-- Economy: the server's single source of truth for every player's money.
-- Cash, income per second, rebirths and shop purchases all live here.
-- No other module writes a player's cash.

local Players = game:GetService("Players")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))

local Economy = {}

export type PlayerState = {
	Cash: number,
	Rebirths: number,
	WalkSpeedBonus: number,
	ExtraSlots: number,
	OwnedBrainrots: { [string]: BrainrotRecord },
}

export type BrainrotRecord = {
	Id: string,
	Name: string,
	Mutation: string,
	Rate: number,
	Slot: number,
	MutationsRolled: number,
}

local playerStates: { [Player]: PlayerState } = {}
local brainrotIdCounter = 0

function Economy.getRebirthMultiplier(rebirths: number): number
	return GameConfig.REBIRTH_MULTIPLIER_PER_REBIRTH ^ rebirths
end

function Economy.getState(player: Player): PlayerState?
	return playerStates[player]
end

function Economy.getCash(player: Player): number
	local state = playerStates[player]
	if state then
		return state.Cash
	end
	return 0
end

function Economy.getRebirths(player: Player): number
	local state = playerStates[player]
	if state then
		return state.Rebirths
	end
	return 0
end

function Economy.getSlotCount(player: Player): number
	local state = playerStates[player]
	if not state then
		return GameConfig.BASE_SLOTS_START
	end
	return math.min(GameConfig.BASE_SLOTS_START + state.ExtraSlots, GameConfig.BASE_SLOTS_MAX)
end

function Economy.getIncomePerSecond(player: Player): number
	local state = playerStates[player]
	if not state then
		return 0
	end
	local multiplier = Economy.getRebirthMultiplier(state.Rebirths)
	local total = 0
	for _, record in pairs(state.OwnedBrainrots) do
		local def = BrainrotCatalog.getByName(record.Name)
		if def then
			total += BrainrotCatalog.getRatePerSecond(def, record.Mutation, multiplier)
		end
	end
	return total
end

function Economy.addCash(player: Player, amount: number)
	local state = playerStates[player]
	if state then
		state.Cash = math.max(0, state.Cash + amount)
	end
end

function Economy.spendCash(player: Player, amount: number): boolean
	local state = playerStates[player]
	if not state or state.Cash < amount then
		return false
	end
	state.Cash -= amount
	return true
end

function Economy.newBrainrotId(): string
	brainrotIdCounter += 1
	return "br_" .. tostring(brainrotIdCounter) .. "_" .. tostring(math.random(1000, 9999))
end

function Economy.addBrainrot(player: Player, name: string, mutation: string, slot: number): BrainrotRecord?
	local state = playerStates[player]
	local def = BrainrotCatalog.getByName(name)
	if not state or not def then
		return nil
	end
	local record: BrainrotRecord = {
		Id = Economy.newBrainrotId(),
		Name = name,
		Mutation = mutation,
		Rate = def.Rate,
		Slot = slot,
		MutationsRolled = 0,
	}
	state.OwnedBrainrots[record.Id] = record
	return record
end

function Economy.removeBrainrot(player: Player, brainrotId: string): BrainrotRecord?
	local state = playerStates[player]
	if not state then
		return nil
	end
	local record = state.OwnedBrainrots[brainrotId]
	if record then
		state.OwnedBrainrots[brainrotId] = nil
	end
	return record
end

function Economy.findFreeSlot(player: Player): number?
	local state = playerStates[player]
	if not state then
		return nil
	end
	local taken: { [number]: boolean } = {}
	for _, record in pairs(state.OwnedBrainrots) do
		taken[record.Slot] = true
	end
	for slot = 1, Economy.getSlotCount(player) do
		if not taken[slot] then
			return slot
		end
	end
	return nil
end

function Economy.ownsMythicOrBetter(player: Player): boolean
	local state = playerStates[player]
	if not state then
		return false
	end
	for _, record in pairs(state.OwnedBrainrots) do
		local def = BrainrotCatalog.getByName(record.Name)
		if def and (def.Rarity == "Mythic" or def.Rarity == "Godly") then
			return true
		end
	end
	return false
end

function Economy.canRebirth(player: Player): boolean
	local state = playerStates[player]
	if not state then
		return false
	end
	if state.Rebirths >= GameConfig.MAX_REBIRTHS then
		return false
	end
	return state.Cash >= GameConfig.REBIRTH_CASH_REQUIREMENT or Economy.ownsMythicOrBetter(player)
end

-- Resets cash and brainrots, keeps a permanent x2 income multiplier per rebirth.
function Economy.doRebirth(player: Player): boolean
	local state = playerStates[player]
	if not state or not Economy.canRebirth(player) then
		return false
	end
	state.Rebirths += 1
	state.Cash = GameConfig.STARTING_CASH
	state.OwnedBrainrots = {}
	return true
end

function Economy.buyWalkSpeed(player: Player): boolean
	local state = playerStates[player]
	if not state or state.WalkSpeedBonus >= GameConfig.WALK_SPEED_MAX then
		return false
	end
	if not Economy.spendCash(player, GameConfig.WALK_SPEED_COST) then
		return false
	end
	state.WalkSpeedBonus += 1
	return true
end

function Economy.buyExtraSlot(player: Player): boolean
	local state = playerStates[player]
	if not state then
		return false
	end
	if Economy.getSlotCount(player) >= GameConfig.BASE_SLOTS_MAX then
		return false
	end
	if not Economy.spendCash(player, GameConfig.EXTRA_SLOT_COST) then
		return false
	end
	state.ExtraSlots += 1
	return true
end

function Economy.rollMutation(player: Player, brainrotId: string): string?
	local state = playerStates[player]
	if not state then
		return nil
	end
	local record = state.OwnedBrainrots[brainrotId]
	if not record or record.MutationsRolled >= GameConfig.MUTATION_ROLL_MAX then
		return nil
	end
	if not Economy.spendCash(player, GameConfig.MUTATION_ROLL_COST) then
		return nil
	end
	record.MutationsRolled += 1
	record.Mutation = BrainrotCatalog.rollMutation()
	return record.Mutation
end

-- One cash tick per second for every player, from their owned brainrots.
function Economy.tickIncome()
	for player, _ in pairs(playerStates) do
		local income = Economy.getIncomePerSecond(player)
		if income > 0 then
			Economy.addCash(player, income)
		end
	end
end

function Economy.onPlayerAdded(player: Player)
	playerStates[player] = {
		Cash = GameConfig.STARTING_CASH,
		Rebirths = 0,
		WalkSpeedBonus = 0,
		ExtraSlots = 0,
		OwnedBrainrots = {},
	}
end

function Economy.onPlayerRemoving(player: Player)
	playerStates[player] = nil
end

Players.PlayerAdded:Connect(Economy.onPlayerAdded)
Players.PlayerRemoving:Connect(Economy.onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	Economy.onPlayerAdded(player)
end

return Economy
