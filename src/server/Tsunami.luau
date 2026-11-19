-- Tsunami: every ~90 seconds a wave sweeps the island.
-- A 10-second warning banner goes out first, then a big translucent blue
-- wall crosses the map. Players caught outside their own base are knocked
-- back to spawn and drop any brainrot they carry; inside your base you
-- are safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Tsunami = {}

local warningEvent: RemoteEvent? = nil
local waveEvent: RemoteEvent? = nil
local isInsideOwnBase: ((player: Player) -> boolean)? = nil
local onPlayerWashedAway: ((player: Player) -> ())? = nil

local waveActive = false
local nextWaveAt = os.clock() + GameConfig.TSUNAMI_INTERVAL

function Tsunami.setEvents(warning: RemoteEvent, wave: RemoteEvent)
	warningEvent = warning
	waveEvent = wave
end

function Tsunami.setInsideBaseCheck(check: (player: Player) -> boolean)
	isInsideOwnBase = check
end

function Tsunami.setOnPlayerWashedAway(callback: (player: Player) -> ())
	onPlayerWashedAway = callback
end

function Tsunami.isWaveActive(): boolean
	return waveActive
end

function Tsunami.getSecondsUntilWave(): number
	return math.max(0, nextWaveAt - os.clock())
end

-- Builds the wave wall once: a tall translucent blue part that sweeps
-- from one side of the island to the other.
local function getWaveWall(): Part
	local wall = Workspace:FindFirstChild("TsunamiWall")
	if wall and wall:IsA("Part") then
		return wall
	end
	wall = Instance.new("Part")
	wall.Name = "TsunamiWall"
	wall.Size = Vector3.new(4, 40, 220)
	wall.Color = Color3.fromRGB(40, 140, 255)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.4
	wall.Anchored = true
	wall.CanCollide = false
	wall.Position = Vector3.new(-110, 20, 0)
	wall.Parent = Workspace
	return wall
end

-- Washes one player: back to spawn, and whatever they carried is dropped.
local function washPlayerAway(player: Player)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(GameConfig.SPAWN_POSITION)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end
	if onPlayerWashedAway then
		onPlayerWashedAway(player)
	end
end

-- Runs one wave: warns, sweeps the wall across the island, washes away
-- everyone caught outside their own base, then schedules the next wave.
function Tsunami.runWave()
	waveActive = true
	if warningEvent then
		warningEvent:FireAllClients(GameConfig.TSUNAMI_WARNING_TIME)
	end
	task.wait(GameConfig.TSUNAMI_WARNING_TIME)

	local wall = getWaveWall()
	if waveEvent then
		waveEvent:FireAllClients()
	end
	local startX = -110
	local endX = 110
	local steps = 40
	for step = 0, steps do
		local x = startX + (endX - startX) * (step / steps)
		wall.Position = Vector3.new(x, 20, 0)
		task.wait(GameConfig.TSUNAMI_WAVE_SPEED / steps * 0.01 + 0.05)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local safe = false
		if isInsideOwnBase then
			safe = isInsideOwnBase(player)
		end
		if not safe then
			washPlayerAway(player)
		end
	end

	wall.Position = Vector3.new(-110, 20, 0)
	waveActive = false
	nextWaveAt = os.clock() + GameConfig.TSUNAMI_INTERVAL
end

-- The wave timer: waits for the interval, then runs a wave, forever.
function Tsunami.startLoop()
	task.spawn(function()
		while true do
			task.wait(math.max(1, Tsunami.getSecondsUntilWave()))
			Tsunami.runWave()
		end
	end)
end

return Tsunami
