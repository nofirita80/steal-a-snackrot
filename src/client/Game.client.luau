-- Steal a Snackrot — client
-- Builds the ScreenGui over the 3D world: stats, leaderboard, wave
-- banner, toasts, action buttons, context prompt and the help panel.
-- The client only asks through RemoteEvents; the server decides
-- everything. Everything stays clear of the top-left corner, where
-- Roblox's own menu buttons sit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SnackrotRemotes")
local claimRemote = remotes:WaitForChild("ClaimSnack")
local stealRemote = remotes:WaitForChild("StealSnack")
local lockRemote = remotes:WaitForChild("LockBase")
local buySlotRemote = remotes:WaitForChild("BuySlot")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local stateRemote = remotes:WaitForChild("StateUpdate")
local notifyRemote = remotes:WaitForChild("Notify")

local snacksFolder = Workspace:WaitForChild("Snacks")

local state = {
	cash = 0,
	incomePerSecond = 0,
	rebirths = 0,
	multiplier = 1,
	slotsUsed = 0,
	slotsMax = 3,
	nextSlotCost = 1000,
	nextRebirthCost = 10000,
	lockActive = false,
	lockSecondsLeft = 0,
	lockCooldownLeft = 0,
	carrying = nil,
	waveState = "idle",
	waveSeconds = 0,
	hasPlot = false,
	plotIndex = 0,
}

local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. out
end

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = false
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

-- ---------------------------------------------------------------- ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "SnackrotGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Top-right stats panel
local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Size = UDim2.new(0, 280, 0, 190)
statsPanel.Position = UDim2.new(1, -300, 0, 16)
statsPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
statsPanel.BackgroundTransparency = 0.15
statsPanel.BorderSizePixel = 0
statsPanel.Parent = gui
local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 12)
statsCorner.Parent = statsPanel

makeLabel(statsPanel, "Title", "STEAL A SNACKROT", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 6), 20, Color3.fromRGB(255, 210, 80))
local cashLabel = makeLabel(statsPanel, "Cash", "$0", UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 0, 38), 26, Color3.fromRGB(120, 255, 140))
local incomeLabel = makeLabel(statsPanel, "Income", "+$0/s", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 74), 18, Color3.fromRGB(140, 220, 255))
local rebirthLabel = makeLabel(statsPanel, "Rebirths", "Rebirths: 0  (x1)", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 102), 18, Color3.fromRGB(255, 255, 255))
local slotsLabel = makeLabel(statsPanel, "Slots", "Slots: 0/3", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 130), 18, Color3.fromRGB(255, 255, 255))
local plotLabel = makeLabel(statsPanel, "Plot", "No base yet", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 158), 16, Color3.fromRGB(200, 200, 200))

-- Leaderboard under the stats panel
local boardPanel = Instance.new("Frame")
boardPanel.Name = "Leaderboard"
boardPanel.Size = UDim2.new(0, 280, 0, 190)
boardPanel.Position = UDim2.new(1, -300, 0, 216)
boardPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
boardPanel.BackgroundTransparency = 0.15
boardPanel.BorderSizePixel = 0
boardPanel.Parent = gui
local boardCorner = Instance.new("UICorner")
boardCorner.CornerRadius = UDim.new(0, 12)
boardCorner.Parent = boardPanel
makeLabel(boardPanel, "BoardTitle", "RICHEST SNACK LORDS", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 6), 16, Color3.fromRGB(255, 210, 80))
local boardRows = {}
for i = 1, 6 do
	boardRows[i] = makeLabel(boardPanel, "Row" .. tostring(i), "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 34 + (i - 1) * 24), 16, Color3.fromRGB(255, 255, 255))
end

local function refreshLeaderboard()
	local entries = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local stats = other:FindFirstChild("leaderstats")
		local cash = stats and stats:FindFirstChild("Cash")
		table.insert(entries, { name = other.Name, cash = cash and cash.Value or 0, isLocal = other == player })
	end
	table.sort(entries, function(a, b)
		return a.cash > b.cash
	end)
	for i = 1, 6 do
		local entry = entries[i]
		if entry then
			local mark = entry.isLocal and "  <-- YOU" or ""
			boardRows[i].Text = tostring(i) .. ". " .. entry.name .. "  " .. formatMoney(entry.cash) .. mark
			boardRows[i].TextColor3 = entry.isLocal and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(255, 255, 255)
		else
			boardRows[i].Text = ""
		end
	end
end

-- Top-centre wave banner and toasts
local waveBanner = Instance.new("TextLabel")
waveBanner.Name = "WaveBanner"
waveBanner.Size = UDim2.new(0, 520, 0, 48)
waveBanner.Position = UDim2.new(0.5, -260, 0, 16)
waveBanner.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
waveBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
waveBanner.TextSize = 22
waveBanner.Font = Enum.Font.GothamBlack
waveBanner.Visible = false
waveBanner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = waveBanner

local toastFrame = Instance.new("Frame")
toastFrame.Name = "Toasts"
toastFrame.Size = UDim2.new(0, 520, 0, 130)
toastFrame.Position = UDim2.new(0.5, -260, 0, 72)
toastFrame.BackgroundTransparency = 1
toastFrame.Parent = gui
local toastLabels = {}
for i = 1, 3 do
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast" .. tostring(i)
	toast.Size = UDim2.new(1, 0, 0, 36)
	toast.Position = UDim2.new(0, 0, 0, (i - 1) * 42)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextSize = 16
	toast.Font = Enum.Font.GothamBold
	toast.Visible = false
	toast.Parent = toastFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = toast
	toastLabels[i] = toast
end
local toastIndex = 0

local function showToast(kind: string, text: string)
	toastIndex = (toastIndex % 3) + 1
	local toast = toastLabels[toastIndex]
	toast.Text = text
	if kind == "good" then
		toast.TextColor3 = Color3.fromRGB(120, 255, 140)
	elseif kind == "bad" then
		toast.TextColor3 = Color3.fromRGB(255, 110, 110)
	else
		toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	toast.Visible = true
	task.delay(4, function()
		toast.Visible = false
	end)
end

notifyRemote.OnClientEvent:Connect(function(kind: string, text: string)
	showToast(kind, text)
end)

-- Bottom-centre action buttons
local buttonBar = Instance.new("Frame")
buttonBar.Name = "ActionButtons"
buttonBar.Size = UDim2.new(0, 620, 0, 54)
buttonBar.Position = UDim2.new(0.5, -310, 1, -70)
buttonBar.BackgroundTransparency = 1
buttonBar.Parent = gui

local lockButton = makeButton(buttonBar, "LockBase", "Lock Base", UDim2.new(0, 140, 1, 0), UDim2.new(0, 0, 0, 0))
local buySlotButton = makeButton(buttonBar, "BuySlot", "Buy Slot ($1,000)", UDim2.new(0, 170, 1, 0), UDim2.new(0, 150, 0, 0))
local rebirthButton = makeButton(buttonBar, "Rebirth", "Rebirth ($10,000)", UDim2.new(0, 180, 1, 0), UDim2.new(0, 330, 0, 0))
local helpButton = makeButton(buttonBar, "HowToPlay", "How to Play", UDim2.new(0, 120, 1, 0), UDim2.new(0, 520, 0, 0))
lockButton.MouseButton1Click:Connect(function()
	lockRemote:FireServer()
end)
buySlotButton.MouseButton1Click:Connect(function()
	buySlotRemote:FireServer()
end)
rebirthButton.MouseButton1Click:Connect(function()
	rebirthRemote:FireServer()
end)

-- Bottom-left context prompt
local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "ContextPrompt"
promptLabel.Size = UDim2.new(0, 420, 0, 44)
promptLabel.Position = UDim2.new(0, 16, 1, -70)
promptLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
promptLabel.BackgroundTransparency = 0.15
promptLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
promptLabel.TextSize = 17
promptLabel.Font = Enum.Font.GothamBold
promptLabel.Text = ""
promptLabel.Parent = gui
local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 10)
promptCorner.Parent = promptLabel

-- Centre help panel
local helpPanel = Instance.new("Frame")
helpPanel.Name = "HelpPanel"
helpPanel.Size = UDim2.new(0, 480, 0, 320)
helpPanel.Position = UDim2.new(0.5, -240, 0.5, -160)
helpPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
helpPanel.Visible = false
helpPanel.Parent = gui
local helpCorner = Instance.new("UICorner")
helpCorner.CornerRadius = UDim.new(0, 12)
helpCorner.Parent = helpPanel
makeLabel(helpPanel, "HelpTitle", "HOW TO PLAY", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 10), 22, Color3.fromRGB(255, 210, 80))
local helpText = Instance.new("TextLabel")
helpText.Size = UDim2.new(1, -24, 0, 220)
helpText.Position = UDim2.new(0, 12, 0, 52)
helpText.BackgroundTransparency = 1
helpText.TextColor3 = Color3.fromRGB(255, 255, 255)
helpText.TextSize = 17
helpText.Font = Enum.Font.Gotham
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.TextWrapped = true
helpText.Text = "1. CLAIM snacks off the red conveyor: click one or press E near it. It walks to your base and earns cash every second.\n\n2. GROW your base: buy more slots, chase rarer snacks and mutations for bigger income.\n\n3. STEAL from other players' bases when their lock is down, then run the snack home before they catch you!\n\n4. LOCK your base to protect it, REBIRTH to double your earnings forever, and get inside your base when the Midnight Hunger Wave sweeps the kitchen!"
helpText.Parent = helpPanel
local closeButton = makeButton(helpPanel, "CloseHelp", "Close", UDim2.new(0, 120, 0, 40), UDim2.new(0.5, -60, 1, -52))
closeButton.MouseButton1Click:Connect(function()
	helpPanel.Visible = false
end)
helpButton.MouseButton1Click:Connect(function()
	helpPanel.Visible = not helpPanel.Visible
end)

-- ---------------------------------------------------------------- interaction
-- How close a snack must be for E to reach it (matches the server's
-- claim range check, so the prompt never offers what the server refuses).
local INTERACT_RANGE = 9

-- The nearest claimable or stealable snack within INTERACT_RANGE studs.
local function nearestSnack(): (Model?, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	local best: Model? = nil
	local bestDistance = INTERACT_RANGE
	local bestKind: string? = nil
	for _, model in ipairs(snacksFolder:GetChildren()) do
		if model:IsA("Model") then
			local snackState = model:GetAttribute("state")
			local ownerId = model:GetAttribute("ownerUserId")
			if snackState == "conveyor" or (snackState == "slotted" and ownerId ~= player.UserId) then
				local primary = model.PrimaryPart
				if primary then
					local d = (primary.Position - root.Position).Magnitude
					if d < bestDistance then
						bestDistance = d
						best = model
						bestKind = snackState
					end
				end
			end
		end
	end
	return best, bestKind
end

local function interactWithNearest()
	local model, kind = nearestSnack()
	if not model then
		return
	end
	local id = model:GetAttribute("id")
	if typeof(id) ~= "number" then
		return
	end
	if kind == "conveyor" then
		claimRemote:FireServer(id)
	elseif kind == "slotted" then
		stealRemote:FireServer(id)
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		interactWithNearest()
	end
end)

-- What is near me right now? Refreshes the bottom-left prompt.
local function refreshPrompt()
	if state.carrying then
		promptLabel.Text = "Carrying " .. state.carrying .. " - RUN HOME to your base!"
		return
	end
	local model, kind = nearestSnack()
	if not model then
		promptLabel.Text = "Walk to the conveyor and press E to claim a snack!"
		return
	end
	local snackName = model:GetAttribute("characterName") or "snack"
	if kind == "conveyor" then
		promptLabel.Text = "Press E to claim " .. tostring(snackName) .. "!"
	else
		promptLabel.Text = "Press E to STEAL " .. tostring(snackName) .. "!"
	end
end

-- ---------------------------------------------------------------- state updates
stateRemote.OnClientEvent:Connect(function(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	cashLabel.Text = formatMoney(state.cash)
	incomeLabel.Text = "+" .. formatMoney(state.incomePerSecond) .. "/s"
	rebirthLabel.Text = "Rebirths: " .. tostring(state.rebirths) .. "  (x" .. tostring(state.multiplier) .. ")"
	slotsLabel.Text = "Slots: " .. tostring(state.slotsUsed) .. "/" .. tostring(state.slotsMax)
	if state.hasPlot then
		plotLabel.Text = "Base #" .. tostring(state.plotIndex)
	else
		plotLabel.Text = "Spectating - no base free"
	end
	buySlotButton.Text = "Buy Slot (" .. formatMoney(state.nextSlotCost) .. ")"
	rebirthButton.Text = "Rebirth (" .. formatMoney(state.nextRebirthCost) .. ")"
	if state.lockActive then
		lockButton.Text = "Locked (" .. tostring(state.lockSecondsLeft) .. "s)"
	elseif state.lockCooldownLeft > 0 then
		lockButton.Text = "Lock (" .. tostring(state.lockCooldownLeft) .. "s)"
	else
		lockButton.Text = "Lock Base"
	end
	if state.waveState == "warning" then
		waveBanner.Visible = true
		waveBanner.Text = "MIDNIGHT HUNGER WAVE IN " .. tostring(state.waveSeconds) .. "s - GET INSIDE YOUR BASE!"
	elseif state.waveState == "active" then
		waveBanner.Visible = true
		waveBanner.Text = "THE WAVE IS SWEEPING! RUN HOME!"
	else
		waveBanner.Visible = false
	end
	refreshLeaderboard()
end)

-- Slow refresh for the prompt and leaderboard, even between state ticks.
task.spawn(function()
	while true do
		task.wait(0.5)
		refreshPrompt()
		refreshLeaderboard()
	end
end)

task.delay(1, function()
	showToast("info", "Grab snacks off the conveyor - click one or press E near it!")
end)
