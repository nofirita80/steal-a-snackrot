-- Steal a Snackrot: GameServer
-- Owns all game state: players, snacks and the Midnight Hunger Wave.
-- The client only asks; every rule is validated here, server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local SnackFactory = require(script.Parent.SnackFactory)

local GameServer = {}

local REMOTE_NAMES = { "ClaimSnack", "StealSnack", "LockBase", "BuySlot", "Rebirth", "StateUpdate", "Notify" }

local world
local plots = {}
local chevrons = {}
local waveWall: Part
local snacksFolder: Folder
local remotes = {}

local nextSnackId = 1
local snacks = {} -- [id] = snack record
local playerData = {} -- [Player] = record
local takenPlots = {} -- [plotIndex] = Player

local waveState = "idle" -- idle | warning | active
local waveEndsAt = 0
local waveForce = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player?, kind: string, text: string)
	if player then
		remotes.Notify:FireClient(player, kind, text)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			remotes.Notify:FireClient(p, kind, text)
		end
	end
end

local function freeSlotIndex(data): number?
	for i = 1, data.slotsMax do
		if data.slots[i] == nil then
			return i
		end
	end
	return nil
end

local function countSlotted(data): number
	local n = 0
	for _, id in pairs(data.slots) do
		if id ~= nil then
			n += 1
		end
	end
	return n
end

local function incomePerSecond(data): number
	local total = 0
	for _, id in pairs(data.slots) do
		local snack = snacks[id]
		if snack then
			total += Config.snackIncome(snack.character, snack.mutation)
		end
	end
	return total * Config.rebirthMultiplier(data.rebirths)
end

local function isInsideBase(player: Player, position: Vector3): boolean
	local data = playerData[player]
	if not data or not data.plotIndex then
		return false
	end
	local centre = plots[data.plotIndex].centre
	return math.abs(position.X - centre.X) < 13 and math.abs(position.Z - centre.Z) < 13
end

local function rootPartOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function distanceTo(player: Player, position: Vector3): number
	local root = rootPartOf(player)
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- Snacks ---------------------------------------------------------------------

local function returnSnackToBelt(snack)
	snack.state = "conveyor"
	snack.owner = nil
	snack.slotIndex = nil
	snack.protectUntil = 0
	snack.model:SetAttribute("state", "conveyor")
	snack.model:SetAttribute("ownerUserId", 0)
	snack.model:PivotTo(CFrame.new(Config.CONVEYOR_START_X, Config.CONVEYOR_RIDE_HEIGHT, Config.CONVEYOR_Z))
end

local function spawnSnack()
	local beltCount = 0
	for _, snack in pairs(snacks) do
		if snack.state == "conveyor" then
			beltCount += 1
		end
	end
	if beltCount >= Config.CONVEYOR_MAX_SNACKS then
		return
	end
	local character = Config.rollCharacter()
	local mutation = Config.rollMutation()
	local id = nextSnackId
	nextSnackId += 1
	local model = SnackFactory.build(character, mutation, id, Vector3.new(Config.CONVEYOR_START_X, Config.CONVEYOR_RIDE_HEIGHT, Config.CONVEYOR_Z))
	model.Parent = snacksFolder
	local snack = {
		id = id,
		model = model,
		character = character,
		mutation = mutation,
		state = "conveyor",
		owner = nil,
		slotIndex = nil,
		protectUntil = 0,
		walking = false,
	}
	snacks[id] = snack

	local root = model.PrimaryPart :: BasePart
	local detector = root:FindFirstChildOfClass("ClickDetector")
	if detector then
		detector.MouseClick:Connect(function(player: Player)
			GameServer.handleClick(player, id)
		end)
	end
end

-- Walks a snack toward a target with small hops, then calls onArrive.
local function walkSnackTo(snack, target: Vector3, onArrive: () -> ())
	if snack.walking then
		return
	end
	snack.walking = true
	snack.state = "walking"
	snack.model:SetAttribute("state", "walking")
	task.spawn(function()
		local start = snack.model:GetPivot().Position
		local distance = (target - start).Magnitude
		local duration = math.clamp(distance / Config.WALK_SPEED, 0.5, 4)
		local elapsed = 0
		while elapsed < duration do
			if not snack.model.Parent then
				snack.walking = false
				return
			end
			elapsed += task.wait(0.05)
			local t = math.min(1, elapsed / duration)
			local pos = start:Lerp(target, t)
			local hop = math.abs(math.sin(t * math.pi * math.max(2, distance / 4))) * 0.8
			snack.model:PivotTo(CFrame.new(pos + Vector3.new(0, hop, 0)))
		end
		snack.walking = false
		onArrive()
	end)
end

local function slotSnack(snack, player: Player, slotIndex: number)
	local data = playerData[player]
	if not data then
		return
	end
	snack.state = "slotted"
	snack.owner = player
	snack.slotIndex = slotIndex
	data.slots[slotIndex] = snack.id
	snack.model:SetAttribute("state", "slotted")
	snack.model:SetAttribute("ownerUserId", player.UserId)
	snack.model:PivotTo(CFrame.new(plots[data.plotIndex].slots[slotIndex]))
end

-- Claiming ---------------------------------------------------------------------

function GameServer.claimSnack(player: Player, snackId: number): boolean
	local snack = snacks[snackId]
	local data = playerData[player]
	if not snack or not data or not data.plotIndex then
		return false
	end
	if snack.state ~= "conveyor" then
		return false
	end
	local slotIndex = freeSlotIndex(data)
	if not slotIndex then
		notify(player, "bad", "Your base is full! Buy a slot or rebirth.")
		return false
	end
	-- The claimer must be close to the belt snack: the click and the E
	-- key both reach the server, so range is re-checked here, not trusted
	-- from the client.
	local root = snack.model.PrimaryPart :: BasePart
	if distanceTo(player, root.Position) > Config.CLAIM_RANGE then
		return false
	end
	snack.state = "walking"
	snack.model:SetAttribute("state", "walking")
	local target = plots[data.plotIndex].slots[slotIndex]
	walkSnackTo(snack, target, function()
		if not player.Parent then
			returnSnackToBelt(snack)
			return
		end
		slotSnack(snack, player, slotIndex)
		notify(player, "good", "Claimed " .. snack.character.name .. "! It now earns $" .. tostring(Config.snackIncome(snack.character, snack.mutation)) .. "/s.")
	end)
	return true
end

-- Stealing ---------------------------------------------------------------------

function GameServer.stealSnack(player: Player, snackId: number): boolean
	local snack = snacks[snackId]
	local data = playerData[player]
	if not snack or not data or not data.plotIndex then
		return false
	end
	if snack.state ~= "slotted" or not snack.owner or snack.owner == player then
		return false
	end
	local victimData = playerData[snack.owner]
	if victimData and victimData.lockUntil > now() then
		notify(player, "bad", "That base is locked!")
		return false
	end
	if snack.protectUntil > now() then
		notify(player, "bad", "That snack is protected for a few more seconds.")
		return false
	end
	if data.carrying ~= nil then
		notify(player, "bad", "You are already carrying a snack!")
		return false
	end
	if not freeSlotIndex(data) then
		notify(player, "bad", "Your base is full! Buy a slot or rebirth.")
		return false
	end
	local root = snack.model.PrimaryPart :: BasePart
	if distanceTo(player, root.Position) > Config.CLAIM_RANGE then
		return false
	end
	-- Lift it off the victim's base onto the thief's head. Keep the victim
	-- in a local first: snack.owner is reassigned below, so notifying
	-- snack.owner afterwards would warn the thief instead of the victim.
	local victim = snack.owner
	if victimData and snack.slotIndex then
		victimData.slots[snack.slotIndex] = nil
	end
	snack.state = "carried"
	snack.owner = player
	snack.slotIndex = nil
	snack.model:SetAttribute("state", "carried")
	snack.model:SetAttribute("ownerUserId", player.UserId)
	data.carrying = snack.id
	notify(player, "good", "Stolen! Run it home to your base!")
	if victim and victim ~= player then
		notify(victim, "bad", player.Name .. " stole your " .. snack.character.name .. "!")
	end
	return true
end

function GameServer.completeSteal(player: Player)
	local data = playerData[player]
	if not data or not data.carrying then
		return
	end
	local snack = snacks[data.carrying]
	if not snack then
		data.carrying = nil
		return
	end
	local slotIndex = freeSlotIndex(data)
	if not slotIndex then
		returnSnackToBelt(snack)
		data.carrying = nil
		return
	end
	data.carrying = nil
	snack.protectUntil = now() + Config.STEAL_PROTECTION_SECONDS
	local target = plots[data.plotIndex].slots[slotIndex]
	walkSnackTo(snack, target, function()
		slotSnack(snack, player, slotIndex)
		notify(player, "good", "Steal complete! " .. snack.character.name .. " is yours now.")
	end)
end

function GameServer.dropCarried(player: Player)
	local data = playerData[player]
	if not data or not data.carrying then
		return
	end
	local snack = snacks[data.carrying]
	data.carrying = nil
	if snack then
		returnSnackToBelt(snack)
	end
end

-- Clicks (claim from the belt, steal from another base) -------------------------
function GameServer.handleClick(player: Player, snackId: number)
	local snack = snacks[snackId]
	if not snack then
		return
	end
	if snack.state == "conveyor" then
		GameServer.claimSnack(player, snackId)
	elseif snack.state == "slotted" then
		GameServer.stealSnack(player, snackId)
	end
end

-- Lock, slots, rebirth -----------------------------------------------------------

function GameServer.lockBase(player: Player): boolean
	local data = playerData[player]
	if not data or not data.plotIndex then
		return false
	end
	local t = now()
	if data.lockUntil > t then
		return false
	end
	if data.lockCooldownUntil > t then
		notify(player, "bad", "Lock is cooling down for " .. tostring(math.floor(data.lockCooldownUntil - t)) .. "s.")
		return false
	end
	data.lockUntil = t + Config.LOCK_DURATION
	data.lockCooldownUntil = data.lockUntil + Config.LOCK_COOLDOWN
	notify(player, "good", "Base locked for 60 seconds!")
	return true
end

function GameServer.buySlot(player: Player): boolean
	local data = playerData[player]
	if not data then
		return false
	end
	if data.slotsMax >= Config.MAX_SLOTS then
		notify(player, "bad", "You already have the maximum 10 slots.")
		return false
	end
	local cost = Config.slotCost(data.slotsMax)
	if data.cash < cost then
		notify(player, "bad", "Need $" .. tostring(cost) .. " for a new slot.")
		return false
	end
	data.cash -= cost
	data.slotsMax += 1
	notify(player, "good", "New slot unlocked! You now have " .. tostring(data.slotsMax) .. " slots.")
	return true
end

function GameServer.rebirth(player: Player): boolean
	local data = playerData[player]
	if not data then
		return false
	end
	local cost = Config.rebirthCost(data.rebirths)
	if data.cash < cost then
		notify(player, "bad", "Rebirth needs $" .. tostring(cost) .. ".")
		return false
	end
	data.cash = 0
	data.rebirths += 1
	data.slotsMax = math.min(Config.MAX_SLOTS, data.slotsMax + 1)
	notify(nil, "info", player.Name .. " rebirthed! Earnings x" .. tostring(Config.rebirthMultiplier(data.rebirths)) .. " forever.")
	return true
end

-- Wave -----------------------------------------------------------------------------
function GameServer.startWaveNow(): boolean
	if waveState ~= "idle" then
		return false
	end
	waveForce = true
	return true
end

local function waveLoop()
	task.wait(Config.WAVE_FIRST_WARNING_DELAY)
	while true do
		-- Idle until the next warning (or a forced start from the tour).
		local idleLeft = Config.WAVE_CYCLE_SECONDS - Config.WAVE_WARNING_SECONDS - Config.WAVE_ACTIVE_SECONDS
		local waited = 0
		while waited < idleLeft and not waveForce do
			task.wait(1)
			waited += 1
		end
		waveForce = false
		waveState = "warning"
		waveEndsAt = now() + Config.WAVE_WARNING_SECONDS
		notify(nil, "bad", "MIDNIGHT HUNGER WAVE IN 30 SECONDS! Get inside your base!")
		task.wait(Config.WAVE_WARNING_SECONDS)
		-- Sweep.
		waveState = "active"
		waveEndsAt = now() + Config.WAVE_ACTIVE_SECONDS
		notify(nil, "bad", "THE WAVE IS SWEEPING! Run home!")
		task.wait(Config.WAVE_ACTIVE_SECONDS)
		waveState = "idle"
		waveEndsAt = 0
		if waveWall then
			waveWall.Position = Vector3.new(Config.WAVE_PARK_X, 21, 0)
		end
	end
end

local function waveHeartbeat(dt: number)
	if waveState == "active" and waveWall then
		local remaining = waveEndsAt - now()
		local progress = 1 - math.clamp(remaining / Config.WAVE_ACTIVE_SECONDS, 0, 1)
		local x = Config.WAVE_START_X + (Config.WAVE_END_X - Config.WAVE_START_X) * progress
		waveWall.Position = Vector3.new(x, 21, 0)
		-- Anyone caught outside their own base is sent home and drops the catch.
		for _, player in ipairs(Players:GetPlayers()) do
			local root = rootPartOf(player)
			if root and not isInsideBase(player, root.Position) then
				local data = playerData[player]
				if data and data.plotIndex then
					GameServer.dropCarried(player)
					root.CFrame = CFrame.new(plots[data.plotIndex].spawn + Vector3.new(0, 3, 0))
					notify(player, "bad", "The wave caught you! Back to your base.")
				end
			end
		end
	end
end

-- Players ---------------------------------------------------------------------------

local function givePlot(player: Player): number?
	for i = 1, Config.PLOT_COUNT do
		if not takenPlots[i] then
			takenPlots[i] = player
			return i
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local plotIndex = givePlot(player)
	local data = {
		plotIndex = plotIndex,
		cash = 0,
		rebirths = 0,
		slotsMax = Config.START_SLOTS,
		slots = {},
		lockUntil = 0,
		lockCooldownUntil = 0,
		carrying = nil,
	}
	playerData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = 0
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats
	data.cashValue = cashValue
	data.rebirthValue = rebirthValue

	if plotIndex then
		task.spawn(function()
			player:LoadCharacter()
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart") :: BasePart
			root.CFrame = CFrame.new(plots[plotIndex].spawn + Vector3.new(0, 3, 0))
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					GameServer.dropCarried(player)
				end)
			end
		end)
	else
		task.spawn(function()
			player:LoadCharacter()
			notify(player, "info", "All bases are taken - you are spectating this round.")
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local data = playerData[player]
	if data then
		GameServer.dropCarried(player)
		-- Slotted snacks return to the belt so they can be claimed again.
		for _, id in pairs(data.slots) do
			local snack = snacks[id]
			if snack then
				returnSnackToBelt(snack)
			end
		end
		if data.plotIndex then
			takenPlots[data.plotIndex] = nil
		end
		playerData[player] = nil
	end
end

-- Loops ----------------------------------------------------------------------------

local function broadcastState()
	for player, data in pairs(playerData) do
		local carryingName = nil
		if data.carrying then
			local snack = snacks[data.carrying]
			if snack then
				carryingName = snack.character.name
			end
		end
		local t = now()
		remotes.StateUpdate:FireClient(player, {
			cash = math.floor(data.cash),
			incomePerSecond = incomePerSecond(data),
			rebirths = data.rebirths,
			multiplier = Config.rebirthMultiplier(data.rebirths),
			slotsUsed = countSlotted(data),
			slotsMax = data.slotsMax,
			nextSlotCost = Config.slotCost(data.slotsMax),
			nextRebirthCost = Config.rebirthCost(data.rebirths),
			lockActive = data.lockUntil > t,
			lockSecondsLeft = math.max(0, math.floor(data.lockUntil - t)),
			lockCooldownLeft = math.max(0, math.floor(data.lockCooldownUntil - t)),
			carrying = carryingName,
			waveState = waveState,
			waveSeconds = math.max(0, math.floor(waveEndsAt - t)),
			hasPlot = data.plotIndex ~= nil,
			plotIndex = data.plotIndex or 0,
		})
	end
end

local function earningsLoop()
	while true do
		task.wait(1)
		for player, data in pairs(playerData) do
			local earned = incomePerSecond(data)
			data.cash += earned
			if data.cashValue then
				data.cashValue.Value = math.floor(data.cash)
			end
			if data.rebirthValue then
				data.rebirthValue.Value = data.rebirths
			end
		end
		broadcastState()
	end
end

local function spawnLoop()
	while true do
		task.wait(Config.CONVEYOR_SPAWN_INTERVAL)
		spawnSnack()
	end
end

local function heartbeat(dt: number)
	-- Conveyor snacks ride east with a small bob.
	for _, snack in pairs(snacks) do
		if snack.state == "conveyor" then
			local pos = snack.model:GetPivot().Position
			local nextX = pos.X + Config.CONVEYOR_SPEED * dt
			if nextX > Config.CONVEYOR_END_X then
				snack.model:Destroy()
				snacks[snack.id] = nil
			else
				local bob = math.sin(now() * 3 + snack.id) * 0.15
				snack.model:PivotTo(CFrame.new(nextX, Config.CONVEYOR_RIDE_HEIGHT + bob, Config.CONVEYOR_Z))
			end
		elseif snack.state == "carried" and snack.owner then
			local root = rootPartOf(snack.owner)
			if root then
				snack.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, Config.CARRY_HEIGHT, 0)))
			end
		end
	end
	-- Chevrons slide along the belt.
	for i, chevron in ipairs(chevrons) do
		local pos = chevron.Position
		local nextX = pos.X + Config.CONVEYOR_SPEED * dt
		if nextX > Config.CONVEYOR_END_X then
			nextX = Config.CONVEYOR_START_X + (nextX - Config.CONVEYOR_END_X)
		end
		chevron.Position = Vector3.new(nextX, pos.Y, pos.Z)
	end
	-- Carrying players who reach their own base complete the steal.
	for player, data in pairs(playerData) do
		if data.carrying then
			local root = rootPartOf(player)
			if root and isInsideBase(player, root.Position) then
				GameServer.completeSteal(player)
			end
		end
	end
	waveHeartbeat(dt)
end

-- Startup --------------------------------------------------------------------------

function GameServer.start()
	local built = MapBuilder.build()
	plots = built.plots
	chevrons = built.chevrons
	waveWall = built.waveWall

	snacksFolder = Instance.new("Folder")
	snacksFolder.Name = "Snacks"
	snacksFolder.Parent = Workspace

	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "SnackrotRemotes"
	remotesFolder.Parent = ReplicatedStorage
	for _, name in ipairs(REMOTE_NAMES) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
		remotes[name] = remote
	end

	remotes.ClaimSnack.OnServerEvent:Connect(function(player: Player, snackId)
		if typeof(snackId) == "number" then
			GameServer.claimSnack(player, snackId)
		end
	end)
	remotes.StealSnack.OnServerEvent:Connect(function(player: Player, snackId)
		if typeof(snackId) == "number" then
			GameServer.stealSnack(player, snackId)
		end
	end)
	remotes.LockBase.OnServerEvent:Connect(function(player: Player)
		GameServer.lockBase(player)
	end)
	remotes.BuySlot.OnServerEvent:Connect(function(player: Player)
		GameServer.buySlot(player)
	end)
	remotes.Rebirth.OnServerEvent:Connect(function(player: Player)
		GameServer.rebirth(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Seed the belt with three snacks so the first players have something to grab.
	for _ = 1, 3 do
		spawnSnack()
	end
	-- Spread the seed snacks along the belt instead of stacking them.
	local i = 0
	for _, snack in pairs(snacks) do
		if snack.state == "conveyor" then
			i += 1
			snack.model:PivotTo(CFrame.new(Config.CONVEYOR_START_X + (i - 1) * 30, Config.CONVEYOR_RIDE_HEIGHT, Config.CONVEYOR_Z))
		end
	end

	RunService.Heartbeat:Connect(heartbeat)
	task.spawn(earningsLoop)
	task.spawn(spawnLoop)
	task.spawn(waveLoop)
end

return GameServer
