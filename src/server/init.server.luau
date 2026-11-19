-- init.server: boots Meme Tide Tycoon.
-- Creates the remotes, spawns brainrots on the conveyor, handles buys,
-- upgrades, locks, rebirths and steals, ticks income every second, and
-- runs the tsunami loop. The server owns all state; the client only
-- renders the HUD and asks for actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local Economy = require(script:WaitForChild("Economy"))
local Bases = require(script:WaitForChild("Bases"))
local StealSystem = require(script:WaitForChild("StealSystem"))
local Tsunami = require(script:WaitForChild("Tsunami"))

-- RemoteEvents the client uses to ask for actions, and the server uses
-- to push state and world updates back.
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function newRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

local BuyBrainrot = newRemote("BuyBrainrot")
local BuyUpgrade = newRemote("BuyUpgrade")
local LockBase = newRemote("LockBase")
local Rebirth = newRemote("Rebirth")
local Steal = newRemote("Steal")
local StateUpdate = newRemote("StateUpdate")
local WorldUpdate = newRemote("WorldUpdate")
local TsunamiWarning = newRemote("TsunamiWarning")
local TsunamiWave = newRemote("TsunamiWave")

Bases.init()
Tsunami.setEvents(TsunamiWarning, TsunamiWave)

-- A player is safe from the tsunami while standing on their own base.
local function isInsideOwnBase(player: Player): boolean
	local base = Bases.getBaseForPlayer(player)
	local character = player.Character
	if not base or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local pos = root.Position
	return math.abs(pos.X - base.Position.X) <= 13 and math.abs(pos.Z - base.Position.Z) <= 13
end

Tsunami.setInsideBaseCheck(isInsideOwnBase)

-- When a carried brainrot is dropped (owner caught the thief, or the
-- tsunami washed the thief away), it goes back to its owner's base.
local function resolveCarry(carry, recovered: boolean)
	if recovered then
		local ownerBase = Bases.getBaseForPlayer(carry.Owner)
		if ownerBase then
			local record = Economy.addBrainrot(carry.Owner, carry.Name, carry.Mutation, carry.Slot)
			if record then
				local rate = BrainrotCatalog.getRatePerSecond(
					BrainrotCatalog.getByName(carry.Name),
					carry.Mutation,
					Economy.getRebirthMultiplier(Economy.getRebirths(carry.Owner))
				)
				Bases.placeBrainrotOnBase(record.Id, carry.Name, carry.Mutation, rate, ownerBase, carry.Slot)
			end
		end
	else
		local thiefBase = Bases.getBaseForPlayer(carry.Thief)
		local slot = Economy.findFreeSlot(carry.Thief)
		if thiefBase and slot then
			local record = Economy.addBrainrot(carry.Thief, carry.Name, carry.Mutation, slot)
			if record then
				local rate = BrainrotCatalog.getRatePerSecond(
					BrainrotCatalog.getByName(carry.Name),
					carry.Mutation,
					Economy.getRebirthMultiplier(Economy.getRebirths(carry.Thief))
				)
				Bases.placeBrainrotOnBase(record.Id, carry.Name, carry.Mutation, rate, thiefBase, slot)
			end
		else
			-- The thief's base is full: the brainrot goes back to its owner.
			local ownerBase = Bases.getBaseForPlayer(carry.Owner)
			if ownerBase then
				local record = Economy.addBrainrot(carry.Owner, carry.Name, carry.Mutation, carry.Slot)
				if record then
					local rate = BrainrotCatalog.getRatePerSecond(
						BrainrotCatalog.getByName(carry.Name),
						carry.Mutation,
						Economy.getRebirthMultiplier(Economy.getRebirths(carry.Owner))
					)
					Bases.placeBrainrotOnBase(record.Id, carry.Name, carry.Mutation, rate, ownerBase, carry.Slot)
				end
			end
		end
	end
end

StealSystem.setOnCarryResolved(resolveCarry)

Tsunami.setOnPlayerWashedAway(function(player: Player)
	if StealSystem.isCarrying(player) then
		StealSystem.recoverSteal(player)
	end
end)

-- Pushes one player's money, income, rebirths, slots and lock to their HUD.
local function sendStateUpdate(player: Player)
	local state = Economy.getState(player)
	if not state then
		return
	end
	local base = Bases.getBaseForPlayer(player)
	local lockSecondsLeft = 0
	if base then
		lockSecondsLeft = Bases.getLockSecondsLeft(base)
	end
	local ownedCount = 0
	local ownedList = {}
	for _, record in pairs(state.OwnedBrainrots) do
		ownedCount += 1
		table.insert(ownedList, { id = record.Id, name = record.Name, mutation = record.Mutation })
	end
	StateUpdate:FireClient(player, {
		cash = state.Cash,
		incomePerSecond = Economy.getIncomePerSecond(player),
		rebirths = state.Rebirths,
		rebirthMultiplier = Economy.getRebirthMultiplier(state.Rebirths),
		slots = Economy.getSlotCount(player),
		usedSlots = ownedCount,
		ownedBrainrots = ownedList,
		lockSecondsLeft = lockSecondsLeft,
		walkSpeedLevel = state.WalkSpeedBonus,
		carrying = StealSystem.isCarrying(player),
		secondsUntilWave = Tsunami.getSecondsUntilWave(),
	})
end

-- Applies the player's bought walk-speed bonus to their character.
local function applyWalkSpeed(player: Player)
	local state = Economy.getState(player)
	local character = player.Character
	if not state or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16 + state.WalkSpeedBonus * GameConfig.WALK_SPEED_BONUS
	end
end

local function onPlayerAdded(player: Player)
	Bases.assignBase(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applyWalkSpeed(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player: Player)
	Bases.releaseBase(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- The conveyor: brainrots ride the lane from one end of the island to
-- the other, waiting to be bought. An unbought one leaves at the end.
type ConveyorBrainrot = {
	Id: string,
	Name: string,
	Mutation: string,
	Price: number,
	Model: Model,
	X: number,
	Y: number,
	DespawnAt: number,
}

local conveyorFolder = Instance.new("Folder")
conveyorFolder.Name = "ConveyorBrainrots"
conveyorFolder.Parent = Workspace

local conveyorBrainrots: { [string]: ConveyorBrainrot } = {}
local conveyorIdCounter = 0
local lastSpawnAt = 0

local function spawnConveyorBrainrot()
	local count = 0
	for _, _ in pairs(conveyorBrainrots) do
		count += 1
	end
	if count >= GameConfig.CONVEYOR_MAX_ACTIVE then
		return
	end
	conveyorIdCounter += 1
	local id = "cv_" .. tostring(conveyorIdCounter)
	local name = BrainrotCatalog.rollRandomName()
	local mutation = BrainrotCatalog.rollMutation()
	local def = BrainrotCatalog.getByName(name)
	local rate = def and def.Rate or 1
	local price = rate * GameConfig.BUY_PRICE_MULTIPLIER
	local bodySize = def and def.Size or 1
	local model = Bases.buildBrainrotModel(name, mutation)
	Bases.attachBrainrotLabel(model, name, mutation, rate)
	-- The body sits on the belt: belt top is y=2.5, body radius 1.5 * size.
	local rideY = 2.5 + 1.5 * bodySize
	model:PivotTo(CFrame.new(Vector3.new(GameConfig.CONVEYOR_START.X, rideY, GameConfig.CONVEYOR_START.Z)))
	model.Parent = conveyorFolder
	conveyorBrainrots[id] = {
		Id = id,
		Name = name,
		Mutation = mutation,
		Price = price,
		Model = model,
		X = GameConfig.CONVEYOR_START.X,
		Y = rideY,
		DespawnAt = os.clock() + GameConfig.CONVEYOR_DESPAWN_TIME,
	}
end

local function removeConveyorBrainrot(id: string)
	local entry = conveyorBrainrots[id]
	if entry then
		entry.Model:Destroy()
		conveyorBrainrots[id] = nil
	end
end

local function stepConveyor(dt: number)
	if os.clock() - lastSpawnAt >= GameConfig.CONVEYOR_SPAWN_INTERVAL then
		lastSpawnAt = os.clock()
		spawnConveyorBrainrot()
	end
	for id, entry in pairs(conveyorBrainrots) do
		entry.X += GameConfig.CONVEYOR_SPEED * dt
		if entry.X >= GameConfig.CONVEYOR_END.X or os.clock() >= entry.DespawnAt then
			removeConveyorBrainrot(id)
		else
			entry.Model:PivotTo(CFrame.new(Vector3.new(entry.X, entry.Y, GameConfig.CONVEYOR_START.Z)))
		end
	end
end

RunService.Heartbeat:Connect(stepConveyor)

-- Buys a brainrot off the conveyor: it walks to the buyer's base slot
-- and starts earning money every second.
BuyBrainrot.OnServerEvent:Connect(function(player: Player, conveyorId: string)
	local entry = conveyorBrainrots[conveyorId]
	if not entry then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - Vector3.new(entry.X, entry.Y, GameConfig.CONVEYOR_START.Z)).Magnitude > 14 then
		return
	end
	local slot = Economy.findFreeSlot(player)
	if not slot then
		return
	end
	if not Economy.spendCash(player, entry.Price) then
		return
	end
	local base = Bases.getBaseForPlayer(player)
	if not base then
		Economy.addCash(player, entry.Price)
		return
	end
	local record = Economy.addBrainrot(player, entry.Name, entry.Mutation, slot)
	if not record then
		Economy.addCash(player, entry.Price)
		return
	end
	removeConveyorBrainrot(conveyorId)
	local rate = BrainrotCatalog.getRatePerSecond(
		BrainrotCatalog.getByName(entry.Name),
		entry.Mutation,
		Economy.getRebirthMultiplier(Economy.getRebirths(player))
	)
	Bases.placeBrainrotOnBase(record.Id, entry.Name, entry.Mutation, rate, base, slot)
	sendStateUpdate(player)
end)

-- Shop upgrades: WalkSpeed, an extra base slot, or a mutation roll.
BuyUpgrade.OnServerEvent:Connect(function(player: Player, upgradeType: string, brainrotId: string?)
	local state = Economy.getState(player)
	if not state then
		return
	end
	if upgradeType == "WalkSpeed" then
		if Economy.buyWalkSpeed(player) then
			applyWalkSpeed(player)
		end
	elseif upgradeType == "ExtraSlot" then
		Economy.buyExtraSlot(player)
	elseif upgradeType == "MutationRoll" and brainrotId then
		local mutation = Economy.rollMutation(player, brainrotId)
		if mutation then
			local record = state.OwnedBrainrots[brainrotId]
			if record then
				local base = Bases.getBaseForPlayer(player)
				if base then
					local rate = BrainrotCatalog.getRatePerSecond(
						BrainrotCatalog.getByName(record.Name),
						mutation,
						Economy.getRebirthMultiplier(state.Rebirths)
					)
					Bases.placeBrainrotOnBase(record.Id, record.Name, mutation, rate, base, record.Slot)
				end
			end
		end
	end
	sendStateUpdate(player)
end)

LockBase.OnServerEvent:Connect(function(player: Player)
	Bases.lockBase(player)
	sendStateUpdate(player)
end)

-- Rebirth: resets cash and brainrots for a permanent x2 income multiplier.
-- The brainrot models on the base are cleared with it.
Rebirth.OnServerEvent:Connect(function(player: Player)
	local state = Economy.getState(player)
	if not state then
		return
	end
	local base = Bases.getBaseForPlayer(player)
	if Economy.doRebirth(player) and base then
		Bases.clearBaseModels(base)
	end
	sendStateUpdate(player)
end)

-- Steals a brainrot from another player's unlocked base.
Steal.OnServerEvent:Connect(function(player: Player, owner: Player, brainrotId: string)
	if not owner or owner == player then
		return
	end
	local ownerState = Economy.getState(owner)
	if not ownerState then
		return
	end
	local record = ownerState.OwnedBrainrots[brainrotId]
	if not record then
		return
	end
	local ownerBase = Bases.getBaseForPlayer(owner)
	if not ownerBase then
		return
	end
	if Bases.isBaseLocked(ownerBase) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local slotDef = BrainrotCatalog.getByName(record.Name)
	local slotPos = Bases.getSlotPosition(ownerBase, record.Slot, slotDef and slotDef.Size or 1.3)
	if (root.Position - slotPos).Magnitude > 12 then
		return
	end
	if StealSystem.isCarrying(player) then
		return
	end
	Economy.removeBrainrot(owner, brainrotId)
	Bases.removeBrainrotModel(brainrotId)
	local rate = BrainrotCatalog.getRatePerSecond(
		BrainrotCatalog.getByName(record.Name),
		record.Mutation,
		Economy.getRebirthMultiplier(Economy.getRebirths(owner))
	)
	if StealSystem.startSteal(player, owner, brainrotId, record.Name, record.Mutation, rate, record.Slot, false) then
		Bases.placeCarriedBrainrotModel(brainrotId, record.Name, record.Mutation, rate)
	end
	sendStateUpdate(player)
	sendStateUpdate(owner)
end)

-- Every frame: carried brainrots follow their thief, and an owner who
-- touches the thief takes the brainrot back.
RunService.Heartbeat:Connect(function()
	StealSystem.stepCarries(Bases.getBrainrotModel, isInsideOwnBase)
end)

-- Every second: pay income, then push every player's HUD state.
task.spawn(function()
	while true do
		task.wait(1)
		Economy.tickIncome()
		for _, player in ipairs(Players:GetPlayers()) do
			sendStateUpdate(player)
		end
	end
end)

-- Twice a second: tell every client what is on the conveyor and on each
-- base, so the client can show Buy and Steal prompts.
task.spawn(function()
	while true do
		task.wait(0.5)
		local conveyorList = {}
		for _, entry in pairs(conveyorBrainrots) do
			table.insert(conveyorList, {
				id = entry.Id,
				name = entry.Name,
				mutation = entry.Mutation,
				price = entry.Price,
				x = entry.X,
			})
		end
		local baseList = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Economy.getState(player)
			local base = Bases.getBaseForPlayer(player)
			if state and base then
				for _, record in pairs(state.OwnedBrainrots) do
					local recordDef = BrainrotCatalog.getByName(record.Name)
					local slotPos = Bases.getSlotPosition(base, record.Slot, recordDef and recordDef.Size or 1.3)
					table.insert(baseList, {
						id = record.Id,
						name = record.Name,
						owner = player,
						ownerName = player.Name,
						locked = Bases.isBaseLocked(base),
						x = slotPos.X,
						z = slotPos.Z,
					})
				end
			end
		end
		WorldUpdate:FireAllClients(conveyorList, baseList)
	end
end)

Tsunami.startLoop()

print("Meme Tide Tycoon is running: conveyor, bases, stealing and tsunami live.")
