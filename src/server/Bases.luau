-- Bases: hands out the 8 island base plots, builds each player's brainrot
-- models on their base, and runs the base lock (60s locked, 120s cooldown).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))

local Bases = {}

export type BaseState = {
	Index: number,
	Owner: Player?,
	Position: Vector3,
	LockedUntil: number,
	LockCooldownUntil: number,
	Folder: Folder,
}

local baseStates: { BaseState } = {}
local playerBase: { [Player]: BaseState } = {}
local brainrotModels: { [string]: Model } = {}

-- Builds one brainrot Model from Parts: a round body, a belly, two eyes,
-- a mouth and a little hat that hints at the character. No uploaded assets.
function Bases.buildBrainrotModel(name: string, mutation: string): Model
	local def = BrainrotCatalog.getByName(name)
	local size = 1
	local bodyColor = Color3.fromRGB(200, 200, 200)
	local bellyColor = Color3.fromRGB(240, 240, 240)
	if def then
		size = def.Size
		bodyColor = def.BodyColor
		bellyColor = def.BellyColor
	end
	local mutationColor = BrainrotCatalog.getMutationColor(mutation)
	if mutationColor then
		bodyColor = mutationColor
	end

	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3 * size, 3 * size, 3 * size)
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Shape = Enum.PartType.Ball
	belly.Size = Vector3.new(2 * size, 2 * size, 1.2 * size)
	belly.Color = bellyColor
	belly.Material = Enum.Material.SmoothPlastic
	belly.Anchored = true
	belly.CanCollide = false
	belly.CFrame = body.CFrame * CFrame.new(0, -0.4 * size, 1 * size)
	belly.Parent = model

	local eyeLeft = Instance.new("Part")
	eyeLeft.Name = "EyeLeft"
	eyeLeft.Shape = Enum.PartType.Ball
	eyeLeft.Size = Vector3.new(0.6 * size, 0.6 * size, 0.6 * size)
	eyeLeft.Color = Color3.fromRGB(255, 255, 255)
	eyeLeft.Material = Enum.Material.SmoothPlastic
	eyeLeft.Anchored = true
	eyeLeft.CanCollide = false
	eyeLeft.CFrame = body.CFrame * CFrame.new(-0.6 * size, 0.5 * size, 1.2 * size)
	eyeLeft.Parent = model

	local eyeRight = Instance.new("Part")
	eyeRight.Name = "EyeRight"
	eyeRight.Shape = Enum.PartType.Ball
	eyeRight.Size = Vector3.new(0.6 * size, 0.6 * size, 0.6 * size)
	eyeRight.Color = Color3.fromRGB(255, 255, 255)
	eyeRight.Material = Enum.Material.SmoothPlastic
	eyeRight.Anchored = true
	eyeRight.CanCollide = false
	eyeRight.CFrame = body.CFrame * CFrame.new(0.6 * size, 0.5 * size, 1.2 * size)
	eyeRight.Parent = model

	local pupilLeft = Instance.new("Part")
	pupilLeft.Name = "PupilLeft"
	pupilLeft.Shape = Enum.PartType.Ball
	pupilLeft.Size = Vector3.new(0.3 * size, 0.3 * size, 0.3 * size)
	pupilLeft.Color = Color3.fromRGB(20, 20, 20)
	pupilLeft.Material = Enum.Material.SmoothPlastic
	pupilLeft.Anchored = true
	pupilLeft.CanCollide = false
	pupilLeft.CFrame = body.CFrame * CFrame.new(-0.6 * size, 0.5 * size, 1.5 * size)
	pupilLeft.Parent = model

	local pupilRight = Instance.new("Part")
	pupilRight.Name = "PupilRight"
	pupilRight.Shape = Enum.PartType.Ball
	pupilRight.Size = Vector3.new(0.3 * size, 0.3 * size, 0.3 * size)
	pupilRight.Color = Color3.fromRGB(20, 20, 20)
	pupilRight.Material = Enum.Material.SmoothPlastic
	pupilRight.Anchored = true
	pupilRight.CanCollide = false
	pupilRight.CFrame = body.CFrame * CFrame.new(0.6 * size, 0.5 * size, 1.5 * size)
	pupilRight.Parent = model

	local hat = Instance.new("Part")
	hat.Name = "Hat"
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = Vector3.new(0.4 * size, 2.2 * size, 2.2 * size)
	hat.Color = Color3.fromRGB(60, 60, 60)
	hat.Material = Enum.Material.SmoothPlastic
	hat.Anchored = true
	hat.CanCollide = false
	hat.CFrame = body.CFrame * CFrame.new(0, 1.7 * size, 0) * CFrame.Angles(0, 0, math.rad(90))
	hat.Parent = model

	model.PrimaryPart = body
	return model
end

-- The floating label above a brainrot: name, rarity color, $/sec, mutation.
function Bases.attachBrainrotLabel(model: Model, name: string, mutation: string, ratePerSecond: number)
	local def = BrainrotCatalog.getByName(name)
	local rarity = "Common"
	local rarityColor = BrainrotCatalog.getRarityColor("Common")
	if def then
		rarity = def.Rarity
		rarityColor = BrainrotCatalog.getRarityColor(def.Rarity)
	end
	local labelText = name
	if mutation ~= "Normal" then
		labelText = mutation .. " " .. name
	end
	labelText ..= "\n" .. rarity .. "  $" .. tostring(ratePerSecond) .. "/s"

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotLabel"
	billboard.Size = UDim2.fromOffset(140, 48)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	text.Text = labelText
	text.TextColor3 = rarityColor
	text.TextSize = 14
	text.Font = Enum.Font.SourceSansBold
	text.TextScaled = false
	text.Parent = billboard
end

function Bases.getSlotPosition(base: BaseState, slot: number, size: number?): Vector3
	-- Slots in two rows of four across the base platform. The Y sits the
	-- brainrot's round body on the platform top instead of floating.
	local bodySize = size or 1.3
	local col = (slot - 1) % 4
	local row = math.floor((slot - 1) / 4)
	local x = base.Position.X + (col - 1.5) * 5
	local z = base.Position.Z + (row - 0.5) * 5
	return Vector3.new(x, base.Position.Y + 1 + 1.5 * bodySize, z)
end

function Bases.placeBrainrotOnBase(brainrotId: string, name: string, mutation: string, ratePerSecond: number, base: BaseState, slot: number)
	Bases.removeBrainrotModel(brainrotId)
	local model = Bases.buildBrainrotModel(name, mutation)
	Bases.attachBrainrotLabel(model, name, mutation, ratePerSecond)
	local def = BrainrotCatalog.getByName(name)
	local size = def and def.Size or 1.3
	model:PivotTo(CFrame.new(Bases.getSlotPosition(base, slot, size)))
	model.Parent = base.Folder
	brainrotModels[brainrotId] = model
end

-- Builds a carried brainrot model that floats above the thief (parented
-- to Workspace, not to a base) and registers it by id.
function Bases.placeCarriedBrainrotModel(brainrotId: string, name: string, mutation: string, ratePerSecond: number)
	Bases.removeBrainrotModel(brainrotId)
	local model = Bases.buildBrainrotModel(name, mutation)
	Bases.attachBrainrotLabel(model, name, mutation, ratePerSecond)
	model.Parent = Workspace
	brainrotModels[brainrotId] = model
end

function Bases.removeBrainrotModel(brainrotId: string)
	local model = brainrotModels[brainrotId]
	if model then
		model:Destroy()
		brainrotModels[brainrotId] = nil
	end
end

function Bases.getBrainrotModel(brainrotId: string): Model?
	return brainrotModels[brainrotId]
end

function Bases.getBaseForPlayer(player: Player): BaseState?
	return playerBase[player]
end

function Bases.getBaseByIndex(index: number): BaseState?
	return baseStates[index]
end

function Bases.isBaseLocked(base: BaseState): boolean
	return os.clock() < base.LockedUntil
end

function Bases.getLockSecondsLeft(base: BaseState): number
	return math.max(0, base.LockedUntil - os.clock())
end

function Bases.canLockAgain(base: BaseState): boolean
	return os.clock() >= base.LockCooldownUntil
end

-- Locks a base for 60s, then starts the 120s cooldown before it can lock again.
function Bases.lockBase(player: Player): boolean
	local base = playerBase[player]
	if not base or not Bases.canLockAgain(base) then
		return false
	end
	base.LockedUntil = os.clock() + GameConfig.BASE_LOCK_DURATION
	base.LockCooldownUntil = base.LockedUntil + GameConfig.BASE_LOCK_COOLDOWN
	return true
end

function Bases.assignBase(player: Player): BaseState?
	for _, base in ipairs(baseStates) do
		if base.Owner == nil then
			base.Owner = player
			playerBase[player] = base
			local sign = Workspace:FindFirstChild("BaseSign" .. tostring(base.Index))
			if sign and sign:IsA("BasePart") then
				local gui = sign:FindFirstChildOfClass("BillboardGui")
				if gui then
					local textLabel = gui:FindFirstChildOfClass("TextLabel")
					if textLabel then
						textLabel.Text = player.Name .. "'s Base"
					end
				end
			end
			return base
		end
	end
	return nil
end

-- Destroys every brainrot model on a base and drops them from the
-- registry, so no stale model is ever moved again (rebirth, player
-- leaving). Carried models live under Workspace, so they are untouched.
function Bases.clearBaseModels(base: BaseState)
	for id, model in pairs(brainrotModels) do
		if model.Parent == base.Folder then
			model:Destroy()
			brainrotModels[id] = nil
		end
	end
end

function Bases.releaseBase(player: Player)
	local base = playerBase[player]
	if base then
		base.Owner = nil
		base.LockedUntil = 0
		base.LockCooldownUntil = 0
		playerBase[player] = nil
		Bases.clearBaseModels(base)
	end
end

function Bases.init()
	local brainrotsFolder = Instance.new("Folder")
	brainrotsFolder.Name = "Brainrots"
	brainrotsFolder.Parent = Workspace

	for i = 1, GameConfig.MAX_PLAYERS do
		local folder = Instance.new("Folder")
		folder.Name = "Base" .. tostring(i) .. "Brainrots"
		folder.Parent = brainrotsFolder
		baseStates[i] = {
			Index = i,
			Owner = nil,
			Position = GameConfig.BASE_POSITIONS[i],
			LockedUntil = 0,
			LockCooldownUntil = 0,
			Folder = folder,
		}
	end
end

Players.PlayerRemoving:Connect(Bases.releaseBase)

return Bases
