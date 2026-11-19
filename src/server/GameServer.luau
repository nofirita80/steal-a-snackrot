-- GameServer: all of Steal a Snackrot's server logic in one place.
-- Owns the game state (players, snacks, wave), the conveyor, claims, bases,
-- earnings, stealing, locks, rebirths and the Midnight Hunger Wave.
-- The client only ever asks; every rule is validated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local SnackFactory = require(script.Parent.SnackFactory)

local GameServer = {}

local layout
local remotes = {}
local playerData = {} -- [Player] = player record
local snacks = {} -- [id] = snack record
local nextSnackId = 1
local nextPlotIndex = 1
local snackFolder

-- Wave state machine: idle -> warning (30s) -> active (20s) -> idle ...
local wave = {
	state = "idle",
	nextWarningAt = 0,
	warningEndsAt = 0,
	activeEndsAt = 0,
	activeStartedAt = 0,
}

local function now()
	return workspace:GetServerTimeNow()
end

local function isInsideRect(pos, rect)
	return pos.X >= rect.minX and pos.X <= rect.maxX and pos.Z >= rect.minZ and pos.Z <= rect.maxZ
end

local function countSlots(pdata)
	local used = 0
	for i = 1, pdata.maxSlots do
		if pdata.slots[i] then
			used += 1
		end
	end
	return used
end

local function freeSlotIndex(pdata)
	for i = 1, pdata.maxSlots do
		if not pdata.slots[i] then
			return i
		end
	end
	return nil
end

local function incomePerSecond(pdata)
	local total = 0
	for i = 1, pdata.maxSlots do
		local snackId = pdata.slots[i]
		if snackId and snacks[snackId] then
			total += snacks[snackId].income
		end
	end
	return total * Config.rebirthMultiplier(pdata.rebirths)
end

local function lockStatus(pdata)
	local t = now()
	if t < pdata.lockedUntil then
		return "locked", math.ceil(pdata.lockedUntil - t)
	elseif t < pdata.lockCooldownUntil then
		return "cooldown", math.ceil(pdata.lockCooldownUntil - t)
	else
		return "ready", 0
	end
end

local function waveStatus()
	local t = now()
	if wave.state == "warning" then
		return "warning", math.max(0, math.ceil(wave.warningEndsAt - t))
	elseif wave.state == "active" then
		return "active", math.max(0, math.ceil(wave.activeEndsAt - t))
	else
		return "idle", math.max(0, math.ceil(wave.nextWarningAt - t))
	end
end

local function sendState(player)
	local pdata = playerData[player]
	if not pdata then
		return
	end
	local lockState, lockSeconds = lockStatus(pdata)
	local waveState, waveSeconds = waveStatus()
	local carryingName = ""
	if pdata.carryingId and snacks[pdata.carryingId] then
		carryingName = snacks[pdata.carryingId].def.name
	end
	remotes.StateUpdate:FireClient(player, {
		cash = math.floor(pdata.cash),
		income = incomePerSecond(pdata),
		rebirths = pdata.rebirths,
		multiplier = Config.rebirthMultiplier(pdata.rebirths),
		slotsUsed = countSlots(pdata),
		slotsMax = pdata.maxSlots,
		slotCost = Config.slotCost(pdata.maxSlots),
		rebirthCost = Config.rebirthCost(pdata.rebirths),
		lock = lockState,
		lockSeconds = lockSeconds,
		carrying = carryingName,
		wave = waveState,
		waveSeconds = waveSeconds,
		hasPlot = pdata.plotIndex ~= nil,
		plot = pdata.plotIndex or 0,
	})
end

local function broadcastState()
	for player, _ in pairs(playerData) do
		sendState(player)
	end
end

local function notify(player, message, kind)
	remotes.Notify:FireClient(player, message, kind or "info")
end

local function notifyAll(message, kind)
	remotes.Notify:FireAllClients(message, kind or "info")
end

-- The client reads these attributes to show its claim/steal prompt.
local function syncSnackAttributes(snack)
	if snack.model and snack.model.Parent then
		snack.model:SetAttribute("SnackState", snack.state)
		snack.model:SetAttribute("SnackOwner", snack.owner and snack.owner.UserId or 0)
		snack.model:SetAttribute("SnackId", snack.id)
	end
end

-- Moves a snack model along a straight path over `duration` seconds, with a
-- small hop, then calls onArrive. Runs in its own thread; the snack's state
-- is "walking" while it travels so the belt loop leaves it alone.
local function walkSnackTo(snack, targetPos, onArrive)
	task.spawn(function()
		local model = snack.model
		if not model or not model.Parent then
			return
		end
		local from = model:GetPivot().Position
		local distance = (targetPos - from).Magnitude
		local duration = math.clamp(distance / 14, 0.5, 4)
		local startedAt = os.clock()
		while true do
			local elapsed = os.clock() - startedAt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local pos = from:Lerp(targetPos, alpha)
			pos += Vector3.new(0, math.abs(math.sin(alpha * math.pi)) * 1.2, 0)
			if not model.Parent then
				return
			end
			model:PivotTo(CFrame.new(pos))
			if alpha >= 1 then
				break
			end
			task.wait(0.03)
		end
		if onArrive then
			onArrive()
		end
	end)
end

local function despawnSnack(snack)
	snacks[snack.id] = nil
	if snack.model and snack.model.Parent then
		snack.model:Destroy()
	end
end

local function dropCarried(player)
	local pdata = playerData[player]
	if not pdata or not pdata.carryingId then
		return
	end
	local snack = snacks[pdata.carryingId]
	pdata.carryingId = nil
	if not snack then
		return
	end
	-- The dropped snack hops back onto the conveyor at the start of the belt.
	snack.state = "conveyor"
	snack.owner = nil
	snack.slotIndex = nil
	snack.beltX = Config.BELT_MIN_X
	syncSnackAttributes(snack)
	if snack.model and snack.model.Parent then
		snack.model:PivotTo(CFrame.new(Config.BELT_MIN_X, Config.BELT_Y, Config.BELT_Z))
	end
end

local function spawnSnack(beltX)
	local def = Config.rollCharacter()
	local mutation = Config.rollMutation()
	local model = SnackFactory.buildSnackModel(def, mutation)
	model.Name = "Snack_" .. tostring(nextSnackId)
	model.Parent = snackFolder

	local snack = {
		id = nextSnackId,
		def = def,
		mutation = mutation,
		income = def.income * mutation.multiplier,
		model = model,
		state = "conveyor",
		owner = nil,
		slotIndex = nil,
		protectUntil = 0,
		beltX = beltX or Config.BELT_MIN_X,
	}
	nextSnackId += 1
	snacks[snack.id] = snack
	syncSnackAttributes(snack)

	model:PivotTo(CFrame.new(snack.beltX, Config.BELT_Y, Config.BELT_Z))
	local click = model.PrimaryPart:FindFirstChild("SnackClick")
	if click then
		click.MouseClick:Connect(function(player)
			GameServer.onSnackClicked(player, snack)
		end)
	end
	return snack
end

local function claimSnack(player, snack)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		notify(player, "You need a base first!", "bad")
		return
	end
	if snack.state ~= "conveyor" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - snack.model:GetPivot().Position).Magnitude > 14 then
		notify(player, "Get closer to the snack first!", "bad")
		return
	end
	local slotIndex = freeSlotIndex(pdata)
	if not slotIndex then
		notify(player, "Your base is full! Buy a slot or rebirth.", "bad")
		return
	end
	snack.state = "walking"
	snack.owner = player
	snack.slotIndex = slotIndex
	syncSnackAttributes(snack)
	pdata.slots[slotIndex] = snack.id
	local plot = layout.plots[pdata.plotIndex]
	local target = plot.slots[slotIndex]
	notify(player, "Claimed " .. snack.def.name .. "! It is waddling to your base.", "good")
	walkSnackTo(snack, target, function()
		if snacks[snack.id] then
			if not playerData[player] then
				-- The claimer left mid-walk: the snack hops back on the belt.
				snack.state = "conveyor"
				snack.owner = nil
				snack.slotIndex = nil
				snack.beltX = Config.BELT_MIN_X
				syncSnackAttributes(snack)
				snack.model:PivotTo(CFrame.new(Config.BELT_MIN_X, Config.BELT_Y, Config.BELT_Z))
			else
				snack.state = "slotted"
				syncSnackAttributes(snack)
				sendState(player)
			end
		end
	end)
	sendState(player)
end

local function stealSnack(player, snack)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		return
	end
	if snack.state ~= "slotted" or snack.owner == player then
		return
	end
	local victim = snack.owner
	local victimData = playerData[victim]
	if not victimData then
		return
	end
	local victimLock = lockStatus(victimData)
	if victimLock == "locked" then
		notify(player, victim.Name .. "'s base is locked!", "bad")
		return
	end
	if now() < snack.protectUntil then
		notify(player, snack.def.name .. " is protected from stealing right now.", "bad")
		return
	end
	if pdata.carryingId then
		notify(player, "You are already carrying a snack!", "bad")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - snack.model:GetPivot().Position).Magnitude > 14 then
		notify(player, "Get closer to the snack first!", "bad")
		return
	end
	if not freeSlotIndex(pdata) then
		notify(player, "Your base is full! Buy a slot or rebirth.", "bad")
		return
	end
	-- Lift it off the victim's base and onto the thief's head.
	victimData.slots[snack.slotIndex] = nil
	snack.state = "carried"
	snack.owner = nil
	snack.slotIndex = nil
	syncSnackAttributes(snack)
	pdata.carryingId = snack.id
	notify(player, "You stole " .. snack.def.name .. "! Run it home to your base!", "good")
	notify(victim, player.Name .. " stole your " .. snack.def.name .. "! Chase them!", "bad")
	sendState(player)
	sendState(victim)
end

local function completeSteal(player, snack)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		return
	end
	local slotIndex = freeSlotIndex(pdata)
	if not slotIndex then
		-- No room after all: send it back to the conveyor.
		dropCarried(player)
		return
	end
	pdata.carryingId = nil
	snack.state = "walking"
	snack.owner = player
	snack.slotIndex = slotIndex
	syncSnackAttributes(snack)
	snack.protectUntil = now() + Config.STEAL_PROTECT_SECONDS
	pdata.slots[slotIndex] = snack.id
	local plot = layout.plots[pdata.plotIndex]
	walkSnackTo(snack, plot.slots[slotIndex], function()
		if snacks[snack.id] then
			if not playerData[player] then
				snack.state = "conveyor"
				snack.owner = nil
				snack.slotIndex = nil
				snack.beltX = Config.BELT_MIN_X
				syncSnackAttributes(snack)
				snack.model:PivotTo(CFrame.new(Config.BELT_MIN_X, Config.BELT_Y, Config.BELT_Z))
			else
				snack.state = "slotted"
				syncSnackAttributes(snack)
				sendState(player)
			end
		end
	end)
	notify(player, snack.def.name .. " is yours now! Protected from stealing for 30s.", "good")
	sendState(player)
end

local function lockBase(player)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		return
	end
	local state, seconds = lockStatus(pdata)
	if state == "locked" then
		notify(player, "Your base is already locked for " .. tostring(seconds) .. "s.", "info")
		return
	elseif state == "cooldown" then
		notify(player, "Lock is cooling down: " .. tostring(seconds) .. "s left.", "info")
		return
	end
	pdata.lockedUntil = now() + Config.LOCK_SECONDS
	pdata.lockCooldownUntil = now() + Config.LOCK_SECONDS + Config.LOCK_COOLDOWN_SECONDS
	notify(player, "Base locked for 60s! Nobody can steal from you.", "good")
	sendState(player)
end

local function buySlot(player)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		return
	end
	if pdata.maxSlots >= Config.MAX_SLOTS then
		notify(player, "Your base already has the maximum slots.", "info")
		return
	end
	local cost = Config.slotCost(pdata.maxSlots)
	if pdata.cash < cost then
		notify(player, "A new slot costs $" .. tostring(cost) .. ". You have $" .. tostring(math.floor(pdata.cash)) .. ".", "bad")
		return
	end
	pdata.cash -= cost
	pdata.maxSlots += 1
	notify(player, "New base slot bought! You now have " .. tostring(pdata.maxSlots) .. " slots.", "good")
	sendState(player)
end

local function rebirth(player)
	local pdata = playerData[player]
	if not pdata or not pdata.plotIndex then
		return
	end
	local cost = Config.rebirthCost(pdata.rebirths)
	if pdata.cash < cost then
		notify(player, "Rebirth costs $" .. tostring(cost) .. ". You have $" .. tostring(math.floor(pdata.cash)) .. ".", "bad")
		return
	end
	pdata.cash = 0
	pdata.rebirths += 1
	if pdata.maxSlots < Config.MAX_SLOTS then
		pdata.maxSlots += 1
	end
	notify(player, "REBIRTH! Earnings are now x" .. tostring(Config.rebirthMultiplier(pdata.rebirths)) .. " and you gained a slot.", "good")
	sendState(player)
end

-- Clicking a snack claims it from the belt or steals it from a base.
function GameServer.onSnackClicked(player, snack)
	if not snacks[snack.id] then
		return
	end
	if snack.state == "conveyor" then
		claimSnack(player, snack)
	elseif snack.state == "slotted" then
		stealSnack(player, snack)
	end
end

local function teleportToSpawn(player)
	local pdata = playerData[player]
	local character = player.Character
	if not pdata or not pdata.plotIndex or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local plot = layout.plots[pdata.plotIndex]
	character:PivotTo(CFrame.new(plot.spawn + Vector3.new(0, 3, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function setupPlayer(player)
	local plotIndex = nil
	if nextPlotIndex <= #layout.plots then
		plotIndex = nextPlotIndex
		nextPlotIndex += 1
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = 0
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats
	leaderstats.Parent = player

	playerData[player] = {
		cash = 0,
		rebirths = 0,
		plotIndex = plotIndex,
		slots = {},
		maxSlots = Config.START_SLOTS,
		lockedUntil = 0,
		lockCooldownUntil = 0,
		carryingId = nil,
		cashValue = cashValue,
		rebirthValue = rebirthValue,
	}

	if plotIndex then
		notify(player, "Welcome to Steal a Snackrot! Grab snacks off the conveyor and fill your base.", "info")
	else
		notify(player, "All bases are taken — you are spectating this round.", "info")
	end

	player:LoadCharacter()
	teleportToSpawn(player)
	sendState(player)
end

local function removePlayer(player)
	dropCarried(player)
	-- A departed player's slotted snacks go back on the belt so they can be
	-- claimed again instead of sitting locked on an empty base forever.
	for _, snack in pairs(snacks) do
		if snack.owner == player and snack.state == "slotted" then
			local pdata = playerData[player]
			if pdata and snack.slotIndex then
				pdata.slots[snack.slotIndex] = nil
			end
			snack.state = "conveyor"
			snack.owner = nil
			snack.slotIndex = nil
			snack.beltX = Config.BELT_MIN_X
			syncSnackAttributes(snack)
			if snack.model and snack.model.Parent then
				snack.model:PivotTo(CFrame.new(Config.BELT_MIN_X, Config.BELT_Y, Config.BELT_Z))
			end
		end
	end
	playerData[player] = nil
end

-- Every character a player spawns with gets its death handler here, so a
-- respawned character is covered too (not just the first one).
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			dropCarried(player)
			task.wait(2)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end
	task.wait(0.2)
	teleportToSpawn(player)
end

-- Wave timing, driven from the one-second tick.
local function updateWave()
	local t = now()
	if wave.state == "idle" then
		if t >= wave.nextWarningAt then
			wave.state = "warning"
			wave.warningEndsAt = t + Config.WAVE_WARNING_SECONDS
			notifyAll("MIDNIGHT HUNGER WAVE in 30 seconds! Get inside your base!", "bad")
		end
	elseif wave.state == "warning" then
		if t >= wave.warningEndsAt then
			wave.state = "active"
			wave.activeStartedAt = t
			wave.activeEndsAt = t + Config.WAVE_ACTIVE_SECONDS
			notifyAll("THE HUNGER WAVE IS HERE! Stay inside your base!", "bad")
		end
	elseif wave.state == "active" then
		if t >= wave.activeEndsAt then
			wave.state = "idle"
			wave.nextWarningAt = t + Config.WAVE_CYCLE_SECONDS - Config.WAVE_WARNING_SECONDS - Config.WAVE_ACTIVE_SECONDS
			layout.waveWall.CFrame = CFrame.new(-300, 22, 10)
			notifyAll("The wave has passed. Back to snacking!", "good")
		end
	end
end

-- While the wave is active, anyone outside their own base is swept home.
local function waveKnockbackCheck()
	if wave.state ~= "active" then
		return
	end
	for player, pdata in pairs(playerData) do
		if pdata.plotIndex then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local plot = layout.plots[pdata.plotIndex]
				if not isInsideRect(root.Position, plot.rect) then
					dropCarried(player)
					teleportToSpawn(player)
					notify(player, "The Hunger Wave swept you back to your base!", "bad")
				end
			end
		end
	end
end

-- TOUR.json calls this to bring the game to the wave screen for a screenshot.
function GameServer.startWaveNow(_arg)
	if wave.state == "idle" then
		wave.nextWarningAt = now()
	end
	return true
end

function GameServer.start()
	layout = MapBuilder.build()

	snackFolder = Instance.new("Folder")
	snackFolder.Name = "Snacks"
	snackFolder.Parent = workspace

	-- RemoteEvents: created here so the client can WaitForChild them.
	local folder = Instance.new("Folder")
	folder.Name = "SnackrotRemotes"
	folder.Parent = ReplicatedStorage
	local function remote(name)
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		remotes[name] = event
		return event
	end
	remote("ClaimSnack")
	remote("StealSnack")
	remote("LockBase")
	remote("BuySlot")
	remote("Rebirth")
	remote("StateUpdate")
	remote("Notify")

	remotes.ClaimSnack.OnServerEvent:Connect(function(player, snackId)
		local snack = snacks[snackId]
		if snack then
			claimSnack(player, snack)
		end
	end)
	remotes.StealSnack.OnServerEvent:Connect(function(player, snackId)
		local snack = snacks[snackId]
		if snack then
			stealSnack(player, snack)
		end
	end)
	remotes.LockBase.OnServerEvent:Connect(lockBase)
	remotes.BuySlot.OnServerEvent:Connect(buySlot)
	remotes.Rebirth.OnServerEvent:Connect(rebirth)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		setupPlayer(player)
	end)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		setupPlayer(player)
	end

	wave.nextWarningAt = now() + Config.WAVE_FIRST_WARNING_AT

	-- Seed the belt so the game opens with snacks already riding it.
	spawnSnack(-80)
	spawnSnack(-50)
	spawnSnack(-20)

	-- Per-frame movement: belt snacks, carried snacks, the wave wall.
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		local toDespawn = {}
		for _, snack in pairs(snacks) do
			if snack.state == "conveyor" then
				snack.beltX += Config.BELT_SPEED * dt
				if snack.beltX > Config.BELT_MAX_X then
					table.insert(toDespawn, snack)
				elseif snack.model and snack.model.Parent then
					local bob = math.sin(t * 3 + snack.id) * 0.15
					snack.model:PivotTo(CFrame.new(snack.beltX, Config.BELT_Y + bob, Config.BELT_Z))
				end
			elseif snack.state == "carried" then
				local carrier = nil
				local carrierData = nil
				for player, data in pairs(playerData) do
					if data.carryingId == snack.id then
						carrier = player
						carrierData = data
						break
					end
				end
				if not carrier then
					-- The carrier left the game; the snack hops back on the belt.
					snack.state = "conveyor"
					snack.owner = nil
					snack.beltX = Config.BELT_MIN_X
					syncSnackAttributes(snack)
					if snack.model and snack.model.Parent then
						snack.model:PivotTo(CFrame.new(Config.BELT_MIN_X, Config.BELT_Y, Config.BELT_Z))
					end
				else
					local character = carrier.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root then
						snack.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, Config.CARRY_HEIGHT, 0)))
						-- Reaching your own base completes the steal.
						if carrierData and carrierData.plotIndex then
							local plot = layout.plots[carrierData.plotIndex]
							if isInsideRect(root.Position, plot.rect) then
								completeSteal(carrier, snack)
							end
						end
					else
						dropCarried(carrier)
					end
				end
			end
		end
		for _, snack in ipairs(toDespawn) do
			despawnSnack(snack)
		end
		if wave.state == "active" then
			local progress = math.clamp((t - wave.activeStartedAt) / Config.WAVE_ACTIVE_SECONDS, 0, 1)
			local wallX = -140 + progress * 280
			layout.waveWall.CFrame = CFrame.new(wallX, 22, 10)
		end
	end)

	-- One-second tick: earnings, wave timing, conveyor spawns, HUD refresh.
	task.spawn(function()
		local spawnTimer = 0
		while true do
			task.wait(1)
			local t = now()

			for player, pdata in pairs(playerData) do
				local income = incomePerSecond(pdata)
				if income > 0 then
					pdata.cash += income
				end
				pdata.cashValue.Value = math.floor(pdata.cash)
				pdata.rebirthValue.Value = pdata.rebirths
			end

			updateWave()

			spawnTimer += 1
			if spawnTimer >= Config.SPAWN_INTERVAL then
				spawnTimer = 0
				local onBelt = 0
				for _, snack in pairs(snacks) do
					if snack.state == "conveyor" then
						onBelt += 1
					end
				end
				if onBelt < Config.MAX_ON_BELT then
					spawnSnack()
				end
			end

			waveKnockbackCheck()
			broadcastState()
		end
	end)
end

return GameServer
