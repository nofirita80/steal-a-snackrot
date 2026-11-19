-- Steal a Snackrot: client HUD (LocalScript).
-- A ScreenGui over the 3D kitchen: cash and income top-right, leaderboard under
-- it, the wave banner top-centre, action buttons bottom-centre, and a context
-- prompt bottom-left. Everything is kept clear of the top-left corner, where
-- Roblox's own menu buttons sit. The server owns every rule; this script only
-- shows state and asks (E to claim/steal, buttons) through RemoteEvents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("SnackrotRemotes")
local claimRemote = remotes:WaitForChild("ClaimSnack")
local stealRemote = remotes:WaitForChild("StealSnack")
local lockRemote = remotes:WaitForChild("LockBase")
local buySlotRemote = remotes:WaitForChild("BuySlot")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local stateRemote = remotes:WaitForChild("StateUpdate")
local notifyRemote = remotes:WaitForChild("Notify")

local function formatCash(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

local gui = Instance.new("ScreenGui")
gui.Name = "SnackrotGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent, name, pos, size, text, textSize, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = pos
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makePanel(parent, name, pos, size)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Position = pos
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	panel.Parent = parent
	return panel
end

local function makeButton(parent, name, pos, size, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = pos
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.TextSize = 18
	button.Font = Enum.Font.SourceSansBold
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- Top-right: cash, income, rebirths, slots.
local statsPanel = makePanel(gui, "StatsPanel", UDim2.new(1, -12, 0, 12), UDim2.fromOffset(300, 158))
statsPanel.AnchorPoint = Vector2.new(1, 0)
makeLabel(statsPanel, "Title", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 26), "STEAL A SNACKROT", 22, Color3.fromRGB(255, 220, 90), true)
local cashLabel = makeLabel(statsPanel, "Cash", UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 30), "Cash: $0", 26, Color3.fromRGB(120, 255, 120), true)
local incomeLabel = makeLabel(statsPanel, "Income", UDim2.fromOffset(14, 70), UDim2.new(1, -28, 0, 24), "$0 / second", 20)
local rebirthLabel = makeLabel(statsPanel, "Rebirths", UDim2.fromOffset(14, 96), UDim2.new(1, -28, 0, 24), "Rebirths: 0  (x1)", 20)
local slotsLabel = makeLabel(statsPanel, "Slots", UDim2.fromOffset(14, 122), UDim2.new(1, -28, 0, 24), "Base slots: 0 / 3", 20)

-- Right side, under the stats: leaderboard by cash.
local boardPanel = makePanel(gui, "Leaderboard", UDim2.new(1, -12, 0, 182), UDim2.fromOffset(300, 190))
boardPanel.AnchorPoint = Vector2.new(1, 0)
makeLabel(boardPanel, "Title", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 24), "TOP SNACK TYCOONS", 18, Color3.fromRGB(255, 220, 90), true)
local boardRows = {}
for i = 1, 6 do
	boardRows[i] = makeLabel(boardPanel, "Row" .. i, UDim2.fromOffset(14, 34 + (i - 1) * 24), UDim2.new(1, -28, 0, 22), "", 18)
end

-- Top-centre: the Midnight Hunger Wave banner (hidden until a wave nears).
local waveBanner = makePanel(gui, "WaveBanner", UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(540, 56))
waveBanner.AnchorPoint = Vector2.new(0.5, 0)
waveBanner.BackgroundColor3 = Color3.fromRGB(140, 20, 45)
waveBanner.Visible = false
local waveLabel = makeLabel(waveBanner, "WaveText", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -12), "", 24, Color3.fromRGB(255, 255, 255), true)
waveLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Toast notifications, top-centre under the banner.
local toastLabel = makeLabel(gui, "Toast", UDim2.new(0.5, 0, 0, 78), UDim2.fromOffset(540, 34), "", 20, Color3.fromRGB(255, 255, 255), true)
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
toastLabel.BackgroundTransparency = 0.25
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
toastLabel.Visible = false
local toastUntil = 0
local function showToast(message, kind)
	toastLabel.Text = message
	if kind == "good" then
		toastLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	elseif kind == "bad" then
		toastLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	toastLabel.Visible = true
	toastUntil = os.clock() + 4
end

-- Bottom-centre: action buttons.
local buttonsPanel = makePanel(gui, "Buttons", UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(580, 54))
buttonsPanel.AnchorPoint = Vector2.new(0.5, 1)
buttonsPanel.BackgroundTransparency = 0.45
local lockButton = makeButton(buttonsPanel, "Lock", UDim2.fromOffset(10, 8), UDim2.fromOffset(130, 38), "Lock Base")
local slotButton = makeButton(buttonsPanel, "BuySlot", UDim2.fromOffset(150, 8), UDim2.fromOffset(130, 38), "Buy Slot")
local rebirthButton = makeButton(buttonsPanel, "Rebirth", UDim2.fromOffset(290, 8), UDim2.fromOffset(130, 38), "Rebirth")
local helpButton = makeButton(buttonsPanel, "Help", UDim2.fromOffset(430, 8), UDim2.fromOffset(140, 38), "How to Play")

-- Bottom-left: context prompt (claim / steal / carrying).
local promptLabel = makeLabel(gui, "Prompt", UDim2.new(0, 16, 1, -86), UDim2.fromOffset(460, 40), "", 22, Color3.fromRGB(255, 255, 255), true)
promptLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
promptLabel.BackgroundTransparency = 0.25
promptLabel.TextXAlignment = Enum.TextXAlignment.Center
promptLabel.Visible = false

-- Centre: help panel explaining the goal.
local helpPanel = makePanel(gui, "HelpPanel", UDim2.new(0.5, 0, 0.5, 0), UDim2.fromOffset(580, 400))
helpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
helpPanel.Visible = false
makeLabel(helpPanel, "HelpTitle", UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 30), "HOW TO PLAY", 26, Color3.fromRGB(255, 220, 90), true)
local helpText = makeLabel(helpPanel, "HelpText", UDim2.fromOffset(18, 50), UDim2.new(1, -36, 1, -100),
	"Living snacks ride the conveyor through the giant kitchen.\n\n"
		.. "1. Walk up to a snack on the belt and press E (or click it) to claim it. It waddles to your base and earns cash every second.\n\n"
		.. "2. Rarer snacks and mutations (Golden, Diamond, Rainbow, Void) earn far more. Fill your base, buy more slots, and rebirth for a permanent x2 earnings multiplier.\n\n"
		.. "3. Steal snacks from other players' bases: press E next to one, carry it home, and step inside your own base to keep it. A locked base cannot be stolen from, and a stolen snack is protected for 30 seconds.\n\n"
		.. "4. Every few minutes the Midnight Hunger Wave sweeps the map. Get inside your own base or it throws you back to spawn and you drop anything you are carrying.\n\n"
		.. "Goal: become the richest snack tycoon on the leaderboard!",
	18)
helpText.TextWrapped = true
helpText.TextYAlignment = Enum.TextYAlignment.Top
local helpClose = makeButton(helpPanel, "Close", UDim2.new(0.5, -70, 1, -52), UDim2.fromOffset(140, 38), "Got it!")

lockButton.MouseButton1Click:Connect(function()
	lockRemote:FireServer()
end)
slotButton.MouseButton1Click:Connect(function()
	buySlotRemote:FireServer()
end)
rebirthButton.MouseButton1Click:Connect(function()
	rebirthRemote:FireServer()
end)
helpButton.MouseButton1Click:Connect(function()
	helpPanel.Visible = not helpPanel.Visible
end)
helpClose.MouseButton1Click:Connect(function()
	helpPanel.Visible = false
end)

-- Server state drives every label.
local latestState = nil
stateRemote.OnClientEvent:Connect(function(state)
	latestState = state
	cashLabel.Text = "Cash: " .. formatCash(state.cash)
	incomeLabel.Text = formatCash(state.income) .. " / second"
	rebirthLabel.Text = "Rebirths: " .. tostring(state.rebirths) .. "  (x" .. tostring(state.multiplier) .. ")"
	slotsLabel.Text = "Base slots: " .. tostring(state.slotsUsed) .. " / " .. tostring(state.slotsMax)
	slotButton.Text = "Buy Slot (" .. formatCash(state.slotCost) .. ")"
	rebirthButton.Text = "Rebirth (" .. formatCash(state.rebirthCost) .. ")"
	if state.lock == "locked" then
		lockButton.Text = "Locked (" .. tostring(state.lockSeconds) .. "s)"
	elseif state.lock == "cooldown" then
		lockButton.Text = "Lock (" .. tostring(state.lockSeconds) .. "s)"
	else
		lockButton.Text = "Lock Base"
	end
	if state.wave == "warning" then
		waveBanner.Visible = true
		waveLabel.Text = "MIDNIGHT HUNGER WAVE in " .. tostring(state.waveSeconds) .. "s — get to your base!"
	elseif state.wave == "active" then
		waveBanner.Visible = true
		waveLabel.Text = "THE HUNGER WAVE IS HERE — stay inside your base!"
	else
		waveBanner.Visible = false
	end
	-- Leaderboard from leaderstats, richest first.
	local rows = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local stats = other:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash")
		table.insert(rows, { name = other.Name, cash = cash and cash.Value or 0 })
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	for i = 1, 6 do
		if rows[i] then
			local mark = rows[i].name == player.Name and "  < YOU" or ""
			boardRows[i].Text = tostring(i) .. ". " .. rows[i].name .. " — " .. formatCash(rows[i].cash) .. mark
		else
			boardRows[i].Text = ""
		end
	end
end)

notifyRemote.OnClientEvent:Connect(showToast)

-- Proximity prompt: the nearest snack you can claim or steal.
local function nearestSnack()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local folder = workspace:FindFirstChild("Snacks")
	if not folder then
		return nil
	end
	local best = nil
	local bestDist = 9
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart then
			local dist = (model.PrimaryPart.Position - root.Position).Magnitude
			if dist < bestDist then
				best = model
				bestDist = dist
			end
		end
	end
	return best
end

local function snackDisplayName(model)
	local anchor = model:FindFirstChild("LabelAnchor")
	local labelGui = anchor and anchor:FindFirstChild("SnackLabel")
	local nameLabel = labelGui and labelGui:FindFirstChild("Name")
	return nameLabel and nameLabel.Text or model.Name
end

local function actOnSnack(model)
	if not model then
		return
	end
	local snackId = model:GetAttribute("SnackId")
	if not snackId then
		return
	end
	local state = model:GetAttribute("SnackState")
	if state == "conveyor" then
		claimRemote:FireServer(snackId)
	elseif state == "slotted" then
		local owner = model:GetAttribute("SnackOwner") or 0
		if owner ~= player.UserId then
			stealRemote:FireServer(snackId)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		actOnSnack(nearestSnack())
	end
end)

-- Refresh the prompt a few times a second; hide the toast when it expires.
RunService.RenderStepped:Connect(function()
	if toastLabel.Visible and os.clock() > toastUntil then
		toastLabel.Visible = false
	end
	if latestState and latestState.carrying ~= "" then
		promptLabel.Text = "Carrying " .. latestState.carrying .. " — run home to your base!"
		promptLabel.Visible = true
		return
	end
	local model = nearestSnack()
	if not model then
		promptLabel.Visible = false
		return
	end
	local state = model:GetAttribute("SnackState")
	if state == "conveyor" then
		promptLabel.Text = "Press E to claim " .. snackDisplayName(model)
		promptLabel.Visible = true
	elseif state == "slotted" then
		local owner = model:GetAttribute("SnackOwner") or 0
		if owner ~= player.UserId and owner ~= 0 then
			promptLabel.Text = "Press E to steal " .. snackDisplayName(model)
			promptLabel.Visible = true
		else
			promptLabel.Visible = false
		end
	else
		promptLabel.Visible = false
	end
end)

-- Show the goal once at the start so a new player knows what to do.
task.delay(1, function()
	showToast("Grab snacks off the conveyor — press E next to one! (How to Play has the full goal)", "info")
end)
