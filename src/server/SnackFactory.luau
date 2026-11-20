-- Steal a Snackrot — SnackFactory
-- Builds every snack character entirely from Parts, no external
-- assets. Each model is anchored, carries a ClickDetector on its root
-- part, a floating label above it, and a coloured aura orb when it
-- has a mutation.

local Config = require(script.Parent.Config)

local SnackFactory = {}

local EYE_COLOR = Color3.fromRGB(30, 30, 30)

-- One part of a character, at a model-local offset.
local function addPart(model: Model, name: string, size: Vector3, color: Color3, offset: Vector3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Position = offset
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

-- Two small dark ball eyes on the front (+Z) face. Callers pass the
-- front-face point in `centre` — its Z is already the face — so the
-- eyes sit just proud of it and are not pushed any further out.
local function addEyes(model: Model, centre: Vector3, spread: number, height: number, size: number?)
	local s = size or 0.28
	addPart(model, "EyeLeft", Vector3.new(s, s, s), EYE_COLOR, centre + Vector3.new(-spread, height, 0.05), Enum.PartType.Ball)
	addPart(model, "EyeRight", Vector3.new(s, s, s), EYE_COLOR, centre + Vector3.new(spread, height, 0.05), Enum.PartType.Ball)
end

local BUILDERS = {}

BUILDERS.toast = function(model: Model)
	addPart(model, "Body", Vector3.new(2.4, 2.8, 0.7), Color3.fromRGB(222, 178, 110), Vector3.new(0, 1.4, 0))
	addPart(model, "Crust", Vector3.new(2.5, 0.5, 0.75), Color3.fromRGB(150, 95, 40), Vector3.new(0, 0.25, 0))
	addPart(model, "Face", Vector3.new(1.8, 1.9, 0.1), Color3.fromRGB(245, 220, 170), Vector3.new(0, 1.6, 0.36))
	addEyes(model, Vector3.new(0, 0, 0.42), 0.4, 1.8)
end

BUILDERS.pickle = function(model: Model)
	local body = addPart(model, "Body", Vector3.new(3.2, 1.1, 1.1), Color3.fromRGB(90, 170, 70), Vector3.new(0, 1.0, 0), Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90))
	for i = -1, 1 do
		addPart(model, "Bump" .. tostring(i + 2), Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(70, 140, 55), Vector3.new(i * 1.0, 1.6, 0), Enum.PartType.Ball)
	end
	addEyes(model, Vector3.new(0, 0, 0.6), 0.45, 1.15)
end

BUILDERS.noodle = function(model: Model)
	addPart(model, "Bowl", Vector3.new(2.6, 1.2, 2.6), Color3.fromRGB(200, 50, 50), Vector3.new(0, 0.7, 0), Enum.PartType.Cylinder)
	addPart(model, "Rim", Vector3.new(2.8, 0.3, 2.8), Color3.fromRGB(220, 70, 70), Vector3.new(0, 1.3, 0), Enum.PartType.Cylinder)
	for i = -1, 1 do
		addPart(model, "Noodle" .. tostring(i + 2), Vector3.new(0.8, 0.5, 0.8), Color3.fromRGB(245, 225, 170), Vector3.new(i * 0.7, 1.55, 0), Enum.PartType.Ball)
	end
	local stick = addPart(model, "Chopstick", Vector3.new(0.18, 3.0, 0.18), Color3.fromRGB(180, 130, 60), Vector3.new(0.9, 2.4, 0))
	stick.CFrame = CFrame.new(0.9, 2.4, 0) * CFrame.Angles(0, 0, math.rad(-30))
	addEyes(model, Vector3.new(0, 0, 1.35), 0.5, 0.9)
end

BUILDERS.ketchup = function(model: Model)
	addPart(model, "Body", Vector3.new(1.8, 2.4, 1.8), Color3.fromRGB(210, 30, 30), Vector3.new(0, 1.2, 0), Enum.PartType.Cylinder)
	addPart(model, "Neck", Vector3.new(0.9, 0.8, 0.9), Color3.fromRGB(200, 25, 25), Vector3.new(0, 2.8, 0), Enum.PartType.Cylinder)
	addPart(model, "Cap", Vector3.new(1.0, 0.5, 1.0), Color3.fromRGB(245, 245, 245), Vector3.new(0, 3.4, 0), Enum.PartType.Cylinder)
	addPart(model, "Label", Vector3.new(1.2, 1.0, 0.1), Color3.fromRGB(250, 250, 250), Vector3.new(0, 1.2, 0.92))
	addEyes(model, Vector3.new(0, 0, 0.95), 0.35, 1.5)
end

BUILDERS.bubblegum = function(model: Model)
	addPart(model, "Body", Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(255, 130, 200), Vector3.new(0, 1.4, 0), Enum.PartType.Ball)
	addPart(model, "Bubble", Vector3.new(1.1, 1.1, 1.1), Color3.fromRGB(255, 190, 225), Vector3.new(1.2, 1.2, 0.3), Enum.PartType.Ball)
	addPart(model, "Stick", Vector3.new(0.35, 1.4, 0.35), Color3.fromRGB(250, 250, 250), Vector3.new(0, 0.3, 0), Enum.PartType.Cylinder)
	addEyes(model, Vector3.new(0, 0, 1.1), 0.4, 1.6)
end

BUILDERS.popcorn = function(model: Model)
	local bucket = addPart(model, "Bucket", Vector3.new(2.4, 2.0, 2.4), Color3.fromRGB(220, 40, 40), Vector3.new(0, 1.0, 0), Enum.PartType.Cylinder)
	bucket.TopSurface = Enum.SurfaceType.Smooth
	addPart(model, "Stripe", Vector3.new(2.45, 0.5, 2.45), Color3.fromRGB(250, 250, 250), Vector3.new(0, 1.0, 0), Enum.PartType.Cylinder)
	for i = -1, 1 do
		addPart(model, "Kernel" .. tostring(i + 2), Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(250, 240, 200), Vector3.new(i * 0.7, 2.3, 0), Enum.PartType.Ball)
	end
	addEyes(model, Vector3.new(0, 0, 1.25), 0.45, 1.1)
end

BUILDERS.croissant = function(model: Model)
	addPart(model, "Body", Vector3.new(2.0, 1.6, 1.4), Color3.fromRGB(215, 150, 60), Vector3.new(0, 1.2, 0), Enum.PartType.Ball)
	local tipL = addPart(model, "TipLeft", Vector3.new(1.2, 1.0, 1.0), Color3.fromRGB(200, 135, 50), Vector3.new(-1.3, 0.9, 0), Enum.PartType.Ball)
	tipL.CFrame = CFrame.new(-1.3, 0.9, 0) * CFrame.Angles(0, 0, math.rad(35))
	local tipR = addPart(model, "TipRight", Vector3.new(1.2, 1.0, 1.0), Color3.fromRGB(200, 135, 50), Vector3.new(1.3, 0.9, 0), Enum.PartType.Ball)
	tipR.CFrame = CFrame.new(1.3, 0.9, 0) * CFrame.Angles(0, 0, math.rad(-35))
	addPart(model, "Shine", Vector3.new(0.9, 0.4, 0.2), Color3.fromRGB(255, 220, 140), Vector3.new(-0.3, 1.7, 0.7))
	addEyes(model, Vector3.new(0, 0, 0.75), 0.4, 1.35)
end

BUILDERS.bacon = function(model: Model)
	for i = 1, 3 do
		local strip = addPart(model, "Strip" .. tostring(i), Vector3.new(2.8, 0.35, 1.0), Color3.fromRGB(190, 50, 45), Vector3.new(0, 0.5 + i * 0.6, 0))
		strip.CFrame = CFrame.new(0, 0.5 + i * 0.6, 0) * CFrame.Angles(0, math.rad((i - 2) * 12), 0)
		addPart(model, "Fat" .. tostring(i), Vector3.new(2.85, 0.12, 0.4), Color3.fromRGB(250, 220, 200), Vector3.new(0, 0.55 + i * 0.6, 0.3))
	end
	addEyes(model, Vector3.new(0, 0, 0.55), 0.45, 1.7)
end

BUILDERS.cupcake = function(model: Model)
	addPart(model, "Cup", Vector3.new(2.0, 1.4, 2.0), Color3.fromRGB(255, 120, 170), Vector3.new(0, 0.7, 0), Enum.PartType.Cylinder)
	addPart(model, "Frosting", Vector3.new(2.1, 1.4, 2.1), Color3.fromRGB(250, 250, 250), Vector3.new(0, 1.9, 0), Enum.PartType.Ball)
	addPart(model, "Cherry", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(220, 30, 40), Vector3.new(0, 2.8, 0), Enum.PartType.Ball)
	addEyes(model, Vector3.new(0, 0, 1.05), 0.4, 0.9)
end

BUILDERS.taco = function(model: Model)
	local shell = addPart(model, "Shell", Vector3.new(0.7, 2.6, 2.6), Color3.fromRGB(230, 180, 80), Vector3.new(0, 1.3, 0), Enum.PartType.Wedge)
	shell.CFrame = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(90), 0)
	addPart(model, "Lettuce", Vector3.new(0.9, 0.6, 2.2), Color3.fromRGB(90, 200, 80), Vector3.new(0, 2.6, 0))
	addPart(model, "Tomato", Vector3.new(0.7, 0.5, 0.7), Color3.fromRGB(220, 50, 50), Vector3.new(0.5, 2.9, 0.4), Enum.PartType.Ball)
	addEyes(model, Vector3.new(0, 0, 1.35), 0.45, 1.4)
end

BUILDERS.truffle = function(model: Model)
	addPart(model, "Body", Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(70, 45, 25), Vector3.new(0, 1.3, 0), Enum.PartType.Ball)
	for i = 1, 4 do
		local angle = (i - 1) * math.rad(90) + math.rad(45)
		addPart(model, "Fleck" .. tostring(i), Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(255, 210, 90), Vector3.new(math.cos(angle) * 0.6, 2.3, math.sin(angle) * 0.6), Enum.PartType.Ball)
	end
	addEyes(model, Vector3.new(0, 0, 1.1), 0.4, 1.4)
end

BUILDERS.donut = function(model: Model)
	local ring = addPart(model, "Ring", Vector3.new(2.8, 0.7, 2.8), Color3.fromRGB(220, 170, 80), Vector3.new(0, 0.6, 0), Enum.PartType.Cylinder)
	ring.TopSurface = Enum.SurfaceType.Smooth
	addPart(model, "Frosting", Vector3.new(2.85, 0.25, 2.85), Color3.fromRGB(255, 140, 190), Vector3.new(0, 0.95, 0), Enum.PartType.Cylinder)
	addPart(model, "Hole", Vector3.new(0.9, 0.8, 0.9), Color3.fromRGB(60, 40, 20), Vector3.new(0, 0.6, 0), Enum.PartType.Cylinder)
	for i = 1, 5 do
		local angle = (i - 1) * (math.pi * 2 / 5)
		addPart(model, "Sprinkle" .. tostring(i), Vector3.new(0.35, 0.12, 0.15), Color3.fromRGB(255, 255, 255), Vector3.new(math.cos(angle) * 1.0, 1.1, math.sin(angle) * 1.0))
	end
	addEyes(model, Vector3.new(0, 0, 1.45), 0.4, 0.75, 0.24)
end

-- ---------------------------------------------------------------- floating label
local function addLabel(model: Model, character, mutation: { name: string, multiplier: number, color: Color3 })
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Position = Vector3.new(0, 4.4, 0)
	anchor.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "SnackLabel"
	gui.Size = UDim2.new(0, 220, 0, 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local income = Config.snackIncome(character, mutation)
	local mutationText = ""
	if mutation.name ~= "None" then
		mutationText = "  " .. mutation.name .. " x" .. tostring(mutation.multiplier)
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.35, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = character.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Position = UDim2.new(0, 0, 0.35, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = character.rarity .. mutationText
	rarityLabel.TextColor3 = Config.RARITY_COLORS[character.rarity]
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = gui

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Position = UDim2.new(0, 0, 0.65, 0)
	incomeLabel.Size = UDim2.new(1, 0, 0.35, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "$" .. tostring(income) .. "/s"
	incomeLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.Parent = gui
end

-- A glowing orb floating above mutated snacks, coloured by the mutation.
local function addAura(model: Model, mutation: { name: string, multiplier: number, color: Color3 })
	if mutation.name == "None" then
		return
	end
	local orb = Instance.new("Part")
	orb.Name = "AuraOrb"
	orb.Size = Vector3.new(0.7, 0.7, 0.7)
	orb.Shape = Enum.PartType.Ball
	orb.Color = mutation.color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Position = Vector3.new(0, 5.4, 0)
	orb.Parent = model
end

-- ---------------------------------------------------------------- public API
-- Builds a snack model at the given world position. `id` is the server's
-- unique snack id; the state/owner attributes are what the client reads.
function SnackFactory.build(character, mutation, id: number, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = character.name .. "_" .. tostring(id)

	local builder = BUILDERS[character.shape]
	if builder then
		builder(model)
	else
		addPart(model, "Body", Vector3.new(2, 2, 2), Color3.fromRGB(200, 200, 200), Vector3.new(0, 1, 0), Enum.PartType.Ball)
	end

	local root = model:FindFirstChild("Body") or model:GetChildren()[1]
	-- Every builder adds a Body, and the fallback adds one too, so a
	-- model with no root part would mean a builder broke: fail loudly
	-- here instead of handing the server a model it cannot click.
	assert(root ~= nil, "SnackFactory: built " .. character.name .. " with no root part")
	model.PrimaryPart = root :: BasePart

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 40
	detector.Parent = root

	addLabel(model, character, mutation)
	addAura(model, mutation)

	model:SetAttribute("id", id)
	model:SetAttribute("state", "conveyor")
	model:SetAttribute("ownerUserId", 0)
	model:SetAttribute("characterName", character.name)
	model:SetAttribute("rarity", character.rarity)
	model:SetAttribute("mutation", mutation.name)
	model:SetAttribute("income", Config.snackIncome(character, mutation))

	model:PivotTo(CFrame.new(position))
	return model
end

return SnackFactory
