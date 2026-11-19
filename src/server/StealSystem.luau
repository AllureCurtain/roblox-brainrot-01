-- StealSystem: stealing a brainrot from another player's base.
-- A thief can only take from a base whose lock is off. The stolen brainrot
-- follows the thief home; if the owner touches the thief while it is
-- carried, it walks back to the owner's base.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local StealSystem = {}

export type CarryState = {
	Thief: Player,
	Owner: Player,
	BrainrotId: string,
	Name: string,
	Mutation: string,
	Rate: number,
	Slot: number,
}

local activeCarries: { [Player]: CarryState } = {}
local onCarryResolved: ((carry: CarryState, recovered: boolean) -> ())? = nil

function StealSystem.setOnCarryResolved(callback: (carry: CarryState, recovered: boolean) -> ())
	onCarryResolved = callback
end

function StealSystem.isCarrying(player: Player): boolean
	return activeCarries[player] ~= nil
end

function StealSystem.getCarry(player: Player): CarryState?
	return activeCarries[player]
end

-- Starts a steal: the brainrot leaves the owner's base and follows the thief.
-- Returns false when the base is locked, the thief already carries one, or
-- the brainrot is not on that base.
function StealSystem.startSteal(
	thief: Player,
	owner: Player,
	brainrotId: string,
	name: string,
	mutation: string,
	rate: number,
	slot: number,
	isBaseLocked: boolean
): boolean
	if activeCarries[thief] ~= nil then
		return false
	end
	if isBaseLocked then
		return false
	end
	if thief == owner then
		return false
	end
	activeCarries[thief] = {
		Thief = thief,
		Owner = owner,
		BrainrotId = brainrotId,
		Name = name,
		Mutation = mutation,
		Rate = rate,
		Slot = slot,
	}
	return true
end

-- The steal succeeds: the thief reaches home with the brainrot.
function StealSystem.completeSteal(thief: Player): CarryState?
	local carry = activeCarries[thief]
	if not carry then
		return nil
	end
	activeCarries[thief] = nil
	if onCarryResolved then
		onCarryResolved(carry, false)
	end
	return carry
end

-- The owner caught the thief: the brainrot goes back to its owner's base.
function StealSystem.recoverSteal(thief: Player): CarryState?
	local carry = activeCarries[thief]
	if not carry then
		return nil
	end
	activeCarries[thief] = nil
	if onCarryResolved then
		onCarryResolved(carry, true)
	end
	return carry
end

function StealSystem.dropCarry(thief: Player)
	activeCarries[thief] = nil
end

-- Every frame: carried brainrots hover above the thief, and an owner who
-- touches the thief within STEAL_TOUCH_DISTANCE takes the brainrot back.
function StealSystem.stepCarries(getModel: (brainrotId: string) -> Model?, isInsideOwnBase: (player: Player) -> boolean)
	for thief, carry in pairs(activeCarries) do
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local model = getModel(carry.BrainrotId)
			if model and model.Parent ~= nil and model.PrimaryPart then
				model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 4, 0)))
			end
			-- The thief made it home: the steal succeeds.
			if isInsideOwnBase(thief) then
				StealSystem.completeSteal(thief)
			else
				-- The owner catches the thief by touch.
				local ownerCharacter = carry.Owner.Character
				local ownerRoot = ownerCharacter and ownerCharacter:FindFirstChild("HumanoidRootPart")
				if ownerRoot and (ownerRoot.Position - root.Position).Magnitude <= GameConfig.STEAL_TOUCH_DISTANCE then
					StealSystem.recoverSteal(thief)
				end
			end
		end
	end
end

function StealSystem.onPlayerRemoving(player: Player)
	-- A thief who leaves drops the brainrot back to its owner.
	local carry = activeCarries[player]
	if carry then
		activeCarries[player] = nil
		if onCarryResolved then
			onCarryResolved(carry, true)
		end
	end
	-- An owner who leaves lets the thief keep what they carry.
	for thief, otherCarry in pairs(activeCarries) do
		if otherCarry.Owner == player then
			activeCarries[thief] = nil
			if onCarryResolved then
				onCarryResolved(otherCarry, false)
			end
		end
	end
end

Players.PlayerRemoving:Connect(StealSystem.onPlayerRemoving)

return StealSystem
