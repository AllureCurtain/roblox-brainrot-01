-- Game.client: the Meme Tide Tycoon HUD and prompts.
-- Renders cash, income, rebirths, slots, the shop, the base lock and
-- rebirth buttons, the tsunami banner, and the Buy / Steal prompts that
-- appear when the player walks up to a brainrot. The server owns all
-- state; this script only shows it and asks for actions.
-- All HUD text stays clear of the top-left corner, where Roblox puts
-- its menu buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyBrainrot = Remotes:WaitForChild("BuyBrainrot")
local BuyUpgrade = Remotes:WaitForChild("BuyUpgrade")
local LockBase = Remotes:WaitForChild("LockBase")
local Rebirth = Remotes:WaitForChild("Rebirth")
local Steal = Remotes:WaitForChild("Steal")
local StateUpdate = Remotes:WaitForChild("StateUpdate")
local WorldUpdate = Remotes:WaitForChild("WorldUpdate")
local TsunamiWarning = Remotes:WaitForChild("TsunamiWarning")
local TsunamiWave = Remotes:WaitForChild("TsunamiWave")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local latestState = nil
local latestConveyor = {}
local latestBaseBrainrots = {}

local function makeLabel(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(260, 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromOffset(150, 44)
	button.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.Font = Enum.Font.SourceSansBold
	button.Parent = parent
	return button
end

local gui = Instance.new("ScreenGui")
gui.Name = "MemeTideGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

-- Title, centered at the top (never in the top-left corner).
local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 8)
title.Size = UDim2.fromOffset(320, 32)
title.BackgroundTransparency = 1
title.Text = "MEME TIDE TYCOON"
title.TextColor3 = Color3.fromRGB(255, 220, 80)
title.TextSize = 26
title.Font = Enum.Font.SourceSansBold
title.Parent = gui

-- Cash panel, top right.
local cashPanel = Instance.new("Frame")
cashPanel.Name = "CashPanel"
cashPanel.AnchorPoint = Vector2.new(1, 0)
cashPanel.Position = UDim2.new(1, -12, 0, 8)
cashPanel.Size = UDim2.fromOffset(280, 150)
cashPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cashPanel.BackgroundTransparency = 0.4
cashPanel.BorderSizePixel = 0
cashPanel.Parent = gui

local cashLabel = makeLabel(cashPanel, "Cash", "Cash: $100", 22, Color3.fromRGB(120, 255, 120))
cashLabel.Position = UDim2.fromOffset(12, 8)
local incomeLabel = makeLabel(cashPanel, "Income", "+$0/s", 18, Color3.fromRGB(255, 255, 255))
incomeLabel.Position = UDim2.fromOffset(12, 40)
local rebirthLabel = makeLabel(cashPanel, "Rebirths", "Rebirths: 0 (x1)", 18, Color3.fromRGB(255, 200, 80))
rebirthLabel.Position = UDim2.fromOffset(12, 70)
local slotsLabel = makeLabel(cashPanel, "Slots", "Base slots: 0/3", 18, Color3.fromRGB(255, 255, 255))
slotsLabel.Position = UDim2.fromOffset(12, 100)
local waveLabel = makeLabel(cashPanel, "WaveTimer", "Next wave: 90s", 16, Color3.fromRGB(120, 200, 255))
waveLabel.Position = UDim2.fromOffset(12, 124)

-- Tsunami warning banner, centered under the title, hidden by default.
local banner = Instance.new("TextLabel")
banner.Name = "TsunamiBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 48)
banner.Size = UDim2.fromOffset(520, 44)
banner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
banner.BackgroundTransparency = 0.2
banner.Text = ""
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextSize = 22
banner.Font = Enum.Font.SourceSansBold
banner.Visible = false
banner.Parent = gui

-- Action buttons along the bottom.
local shopButton = makeButton(gui, "ShopButton", "Shop", UDim2.new(0.5, -240, 1, -60))
local lockButton = makeButton(gui, "LockButton", "Lock Base (60s)", UDim2.new(0.5, -75, 1, -60))
lockButton.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
local rebirthButton = makeButton(gui, "RebirthButton", "Rebirth ($10k)", UDim2.new(0.5, 90, 1, -60))
rebirthButton.BackgroundColor3 = Color3.fromRGB(160, 80, 200)

-- The Buy / Steal prompt, bottom center above the buttons.
local promptButton = Instance.new("TextButton")
promptButton.Name = "PromptButton"
promptButton.AnchorPoint = Vector2.new(0.5, 0)
promptButton.Position = UDim2.new(0.5, 0, 1, -120)
promptButton.Size = UDim2.fromOffset(340, 48)
promptButton.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
promptButton.BorderSizePixel = 0
promptButton.Text = ""
promptButton.TextColor3 = Color3.fromRGB(0, 0, 0)
promptButton.TextSize = 18
promptButton.Font = Enum.Font.SourceSansBold
promptButton.Visible = false
promptButton.Parent = gui

-- Shop panel, centered, hidden until the Shop button is pressed.
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.fromScale(0.5, 0.5)
shopPanel.Size = UDim2.fromOffset(360, 320)
shopPanel.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = gui

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "ShopTitle"
shopTitle.Position = UDim2.fromOffset(12, 8)
shopTitle.Size = UDim2.fromOffset(336, 32)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "SHOP"
shopTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
shopTitle.TextSize = 24
shopTitle.Font = Enum.Font.SourceSansBold
shopTitle.Parent = shopPanel

local walkSpeedButton = makeButton(shopPanel, "WalkSpeedButton", "Walk Speed +2 ($250)", UDim2.fromOffset(12, 48))
walkSpeedButton.Size = UDim2.fromOffset(336, 40)
local extraSlotButton = makeButton(shopPanel, "ExtraSlotButton", "Extra Base Slot ($500)", UDim2.fromOffset(12, 96))
extraSlotButton.Size = UDim2.fromOffset(336, 40)

local mutationTitle = Instance.new("TextLabel")
mutationTitle.Name = "MutationTitle"
mutationTitle.Position = UDim2.fromOffset(12, 148)
mutationTitle.Size = UDim2.fromOffset(336, 28)
mutationTitle.BackgroundTransparency = 1
mutationTitle.Text = "Mutation roll ($300 each):"
mutationTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
mutationTitle.TextSize = 18
mutationTitle.Font = Enum.Font.SourceSansBold
mutationTitle.TextXAlignment = Enum.TextXAlignment.Left
mutationTitle.Parent = shopPanel

local mutationList = Instance.new("Frame")
mutationList.Name = "MutationList"
mutationList.Position = UDim2.fromOffset(12, 180)
mutationList.Size = UDim2.fromOffset(336, 90)
mutationList.BackgroundTransparency = 1
mutationList.Parent = shopPanel

local closeShopButton = makeButton(shopPanel, "CloseShopButton", "Close", UDim2.fromOffset(12, 276))
closeShopButton.Size = UDim2.fromOffset(336, 32)
closeShopButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)

local function refreshShopList()
	for _, child in ipairs(mutationList:GetChildren()) do
		child:Destroy()
	end
	if not latestState or not latestState.ownedBrainrots then
		return
	end
	local y = 0
	for _, owned in ipairs(latestState.ownedBrainrots) do
		local row = makeButton(mutationList, "Roll_" .. owned.id, "Roll " .. owned.name .. " (" .. owned.mutation .. ")", UDim2.fromOffset(0, y))
		row.Size = UDim2.fromOffset(336, 28)
		row.TextSize = 14
		row.BackgroundColor3 = Color3.fromRGB(140, 60, 180)
		row.MouseButton1Click:Connect(function()
			BuyUpgrade:FireServer("MutationRoll", owned.id)
		end)
		y += 32
	end
end

shopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	refreshShopList()
end)
closeShopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)
walkSpeedButton.MouseButton1Click:Connect(function()
	BuyUpgrade:FireServer("WalkSpeed")
end)
extraSlotButton.MouseButton1Click:Connect(function()
	BuyUpgrade:FireServer("ExtraSlot")
end)
lockButton.MouseButton1Click:Connect(function()
	LockBase:FireServer()
end)
rebirthButton.MouseButton1Click:Connect(function()
	Rebirth:FireServer()
end)

-- Applies a StateUpdate from the server to the HUD.
local function onStateUpdate(state)
	latestState = state
	cashLabel.Text = "Cash: $" .. tostring(math.floor(state.cash))
	incomeLabel.Text = "+$" .. tostring(math.floor(state.incomePerSecond)) .. "/s"
	rebirthLabel.Text = "Rebirths: " .. tostring(state.rebirths) .. " (x" .. tostring(state.rebirthMultiplier) .. ")"
	slotsLabel.Text = "Base slots: " .. tostring(state.usedSlots) .. "/" .. tostring(state.slots)
	waveLabel.Text = "Next wave: " .. tostring(math.floor(state.secondsUntilWave)) .. "s"
	if state.lockSecondsLeft and state.lockSecondsLeft > 0 then
		lockButton.Text = "Locked (" .. tostring(math.floor(state.lockSecondsLeft)) .. "s)"
	else
		lockButton.Text = "Lock Base (60s)"
	end
	if state.carrying then
		promptButton.Text = "Carrying a brainrot! Run home!"
		promptButton.Visible = true
	end
	refreshShopList()
end

StateUpdate.OnClientEvent:Connect(onStateUpdate)

WorldUpdate.OnClientEvent:Connect(function(conveyorList, baseList)
	latestConveyor = conveyorList
	latestBaseBrainrots = baseList
end)

-- Shows the tsunami warning banner for the warning window.
TsunamiWarning.OnClientEvent:Connect(function(warningSeconds: number)
	banner.Text = "TSUNAMI INCOMING! Get back to your base!"
	banner.Visible = true
	task.delay(warningSeconds, function()
		banner.Visible = false
	end)
end)

TsunamiWave.OnClientEvent:Connect(function()
	banner.Text = "THE WAVE IS HERE!"
	banner.Visible = true
	task.delay(3, function()
		banner.Visible = false
	end)
end)

-- Each frame: find the nearest buyable conveyor brainrot or stealable
-- base brainrot and offer the prompt button for it.
local promptTarget = nil
local promptKind = nil

local function getRootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local rootPos = getRootPosition()
	if not rootPos then
		promptButton.Visible = false
		return
	end
	if latestState and latestState.carrying then
		promptButton.Text = "Carrying a brainrot! Run home!"
		promptButton.Visible = true
		return
	end
	local best = nil
	local bestKind = nil
	local bestDistance = 14
	for _, entry in ipairs(latestConveyor) do
		local distance = (rootPos - Vector3.new(entry.x, GameConfig.CONVEYOR_START.Y, GameConfig.CONVEYOR_START.Z)).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = entry
			bestKind = "buy"
		end
	end
	for _, entry in ipairs(latestBaseBrainrots) do
		if entry.owner ~= player and not entry.locked then
			local distance = (rootPos - Vector3.new(entry.x, 3, entry.z)).Magnitude
			if distance < 12 and distance < bestDistance then
				bestDistance = distance
				best = entry
				bestKind = "steal"
			end
		end
	end
	promptTarget = best
	promptKind = bestKind
	if best and bestKind == "buy" then
		local label = "Buy " .. best.name
		if best.mutation ~= "Normal" then
			label = "Buy " .. best.mutation .. " " .. best.name
		end
		promptButton.Text = label .. "  $" .. tostring(best.price)
		promptButton.Visible = true
	elseif best and bestKind == "steal" then
		promptButton.Text = "Steal " .. best.name .. " from " .. best.ownerName .. "!"
		promptButton.Visible = true
	else
		promptButton.Visible = false
	end
end)

promptButton.MouseButton1Click:Connect(function()
	if not promptTarget then
		return
	end
	if promptKind == "buy" then
		BuyBrainrot:FireServer(promptTarget.id)
	elseif promptKind == "steal" then
		Steal:FireServer(promptTarget.owner, promptTarget.id)
	end
end)

print("Meme Tide Tycoon HUD loaded.")
