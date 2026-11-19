-- SnackFactory: builds every snack character as a Model of Parts, no assets.
-- Each model is anchored (the server moves it with PivotTo), has a ClickDetector
-- on its root part for click-to-claim / click-to-steal, and a BillboardGui label
-- showing its name, rarity, mutation and cash per second.

local SnackFactory = {}

local function newPart(model, name, shape, size, color, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.CFrame = CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function eye(model, x, y, z)
	return newPart(model, "Eye", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(25, 25, 25), Vector3.new(x, y, z))
end

-- Builders: each assembles one character around the model origin (0,0,0).
-- The first part created becomes the model's root part.
local Builders = {}

function Builders.Toast(model)
	newPart(model, "Body", Enum.PartType.Block, Vector3.new(3, 3, 1), Color3.fromRGB(222, 184, 120), Vector3.new(0, 1.5, 0))
	newPart(model, "Crust", Enum.PartType.Block, Vector3.new(3.2, 0.5, 1.1), Color3.fromRGB(160, 105, 45), Vector3.new(0, 0.2, 0))
	newPart(model, "Face", Enum.PartType.Block, Vector3.new(2.2, 2.2, 0.2), Color3.fromRGB(245, 220, 170), Vector3.new(0, 1.6, 0.55))
	eye(model, -0.6, 1.9, 0.7)
	eye(model, 0.6, 1.9, 0.7)
end

function Builders.Pickle(model)
	local body = newPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(3.4, 1.4, 1.4), Color3.fromRGB(90, 160, 60), Vector3.new(0, 1, 0))
	body.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Bump1", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(70, 130, 45), Vector3.new(-1, 1.8, 0))
	newPart(model, "Bump2", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(70, 130, 45), Vector3.new(0, 1.9, 0))
	newPart(model, "Bump3", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(70, 130, 45), Vector3.new(1, 1.8, 0))
	eye(model, -0.5, 1.2, 0.75)
	eye(model, 0.5, 1.2, 0.75)
end

function Builders.Noodle(model)
	local bowl = newPart(model, "Bowl", Enum.PartType.Cylinder, Vector3.new(1.4, 3.2, 3.2), Color3.fromRGB(220, 60, 60), Vector3.new(0, 0.7, 0))
	bowl.CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Noodles1", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(245, 220, 150), Vector3.new(-0.7, 1.8, 0))
	newPart(model, "Noodles2", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(245, 220, 150), Vector3.new(0.7, 1.8, 0))
	newPart(model, "Noodles3", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(250, 235, 180), Vector3.new(0, 2.4, 0))
	local stick = newPart(model, "Chopstick", Enum.PartType.Block, Vector3.new(0.25, 3.5, 0.25), Color3.fromRGB(150, 100, 50), Vector3.new(1.2, 2.8, 0))
	stick.CFrame = CFrame.new(1.2, 2.8, 0) * CFrame.Angles(0, 0, -0.4)
	eye(model, -0.5, 2.2, 0.75)
	eye(model, 0.5, 2.2, 0.75)
end

function Builders.Ketchup(model)
	local bottle = newPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(2.6, 1.8, 1.8), Color3.fromRGB(200, 30, 30), Vector3.new(0, 1.3, 0))
	bottle.CFrame = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local neck = newPart(model, "Neck", Enum.PartType.Cylinder, Vector3.new(1, 0.9, 0.9), Color3.fromRGB(200, 30, 30), Vector3.new(0, 3, 0))
	neck.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Cap", Enum.PartType.Block, Vector3.new(1, 0.6, 1), Color3.fromRGB(255, 255, 255), Vector3.new(0, 3.7, 0))
	newPart(model, "Label", Enum.PartType.Block, Vector3.new(1.2, 1.2, 0.2), Color3.fromRGB(255, 255, 255), Vector3.new(0, 1.3, 0.95))
	eye(model, -0.45, 1.6, 1.05)
	eye(model, 0.45, 1.6, 1.05)
end

function Builders.Bubblegum(model)
	newPart(model, "Body", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(255, 130, 200), Vector3.new(0, 1.6, 0))
	newPart(model, "Bubble", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(255, 170, 220), Vector3.new(1.2, 2.4, 0.4))
	newPart(model, "Stick", Enum.PartType.Block, Vector3.new(0.4, 1.6, 0.4), Color3.fromRGB(255, 255, 255), Vector3.new(-1.1, 0.6, 0))
	eye(model, -0.5, 1.9, 1.25)
	eye(model, 0.5, 1.9, 1.25)
end

function Builders.Popcorn(model)
	local bucket = newPart(model, "Bucket", Enum.PartType.Cylinder, Vector3.new(2, 2.4, 2.4), Color3.fromRGB(220, 50, 50), Vector3.new(0, 1, 0))
	bucket.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Stripe", Enum.PartType.Block, Vector3.new(0.3, 1.8, 2.5), Color3.fromRGB(255, 255, 255), Vector3.new(0, 1, 0))
	newPart(model, "Kernel1", Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.fromRGB(250, 240, 200), Vector3.new(-0.8, 2.3, 0))
	newPart(model, "Kernel2", Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.fromRGB(250, 240, 200), Vector3.new(0.8, 2.3, 0))
	newPart(model, "Kernel3", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), Color3.fromRGB(255, 250, 220), Vector3.new(0, 2.8, 0))
	eye(model, -0.5, 1.2, 1.25)
	eye(model, 0.5, 1.2, 1.25)
end

function Builders.Croissant(model)
	newPart(model, "Body", Enum.PartType.Ball, Vector3.new(2.2, 1.6, 1.6), Color3.fromRGB(210, 140, 60), Vector3.new(0, 1.2, 0))
	local left = newPart(model, "LeftTip", Enum.PartType.Ball, Vector3.new(1.4, 1.1, 1.1), Color3.fromRGB(190, 120, 45), Vector3.new(-1.5, 1, 0.5))
	left.CFrame = CFrame.new(-1.5, 1, 0.5) * CFrame.Angles(0, 0.5, 0)
	local right = newPart(model, "RightTip", Enum.PartType.Ball, Vector3.new(1.4, 1.1, 1.1), Color3.fromRGB(190, 120, 45), Vector3.new(1.5, 1, 0.5))
	right.CFrame = CFrame.new(1.5, 1, 0.5) * CFrame.Angles(0, -0.5, 0)
	newPart(model, "Shine", Enum.PartType.Ball, Vector3.new(1, 0.7, 1), Color3.fromRGB(235, 175, 90), Vector3.new(0, 1.9, 0))
	eye(model, -0.5, 1.4, 0.85)
	eye(model, 0.5, 1.4, 0.85)
end

function Builders.Bacon(model)
	for i = 1, 3 do
		local y = 0.6 + (i - 1) * 0.9
		local x = (i - 2) * 0.5
		newPart(model, "Strip" .. i, Enum.PartType.Block, Vector3.new(3.2, 0.35, 1.1), Color3.fromRGB(190, 60, 50), Vector3.new(x, y, 0))
		newPart(model, "Fat" .. i, Enum.PartType.Block, Vector3.new(3.2, 0.15, 1.15), Color3.fromRGB(245, 200, 170), Vector3.new(x, y + 0.2, 0))
	end
	eye(model, -0.6, 2.4, 0.6)
	eye(model, 0.6, 2.4, 0.6)
end

function Builders.Cupcake(model)
	local cup = newPart(model, "Cup", Enum.PartType.Cylinder, Vector3.new(1.8, 2.2, 2.2), Color3.fromRGB(255, 150, 200), Vector3.new(0, 0.9, 0))
	cup.CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Frosting", Enum.PartType.Ball, Vector3.new(2.4, 1.6, 2.4), Color3.fromRGB(255, 255, 255), Vector3.new(0, 2.2, 0))
	newPart(model, "Cherry", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(220, 30, 50), Vector3.new(0, 3.1, 0))
	eye(model, -0.5, 2.3, 1.2)
	eye(model, 0.5, 2.3, 1.2)
end

function Builders.Taco(model)
	local shell = Instance.new("WedgePart")
	shell.Name = "Shell"
	shell.Size = Vector3.new(3, 2.4, 1.2)
	shell.Color = Color3.fromRGB(240, 190, 80)
	shell.CFrame = CFrame.new(0, 1.2, 0)
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanTouch = true
	shell.Material = Enum.Material.SmoothPlastic
	shell.Parent = model
	newPart(model, "Lettuce1", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(90, 200, 90), Vector3.new(-0.9, 2.5, 0))
	newPart(model, "Lettuce2", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(90, 200, 90), Vector3.new(0.9, 2.5, 0))
	newPart(model, "Tomato", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(220, 60, 60), Vector3.new(0, 2.7, 0))
	eye(model, -0.5, 1.4, 0.65)
	eye(model, 0.5, 1.4, 0.65)
end

function Builders.Truffle(model)
	newPart(model, "Body", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(60, 35, 25), Vector3.new(0, 1.5, 0))
	newPart(model, "Gold1", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 215, 0), Vector3.new(-0.8, 2.4, 0.8))
	newPart(model, "Gold2", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 215, 0), Vector3.new(0.7, 2.6, 0.5))
	newPart(model, "Gold3", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 215, 0), Vector3.new(0, 2.2, 1.1))
	newPart(model, "Gold4", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 215, 0), Vector3.new(1, 1.8, -0.6))
	eye(model, -0.5, 1.7, 1.25)
	eye(model, 0.5, 1.7, 1.25)
end

function Builders.Donut(model)
	local ring = newPart(model, "Ring", Enum.PartType.Cylinder, Vector3.new(1, 3.2, 3.2), Color3.fromRGB(255, 200, 60), Vector3.new(0, 1, 0))
	ring.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local frost = newPart(model, "Frosting", Enum.PartType.Cylinder, Vector3.new(0.5, 2.6, 2.6), Color3.fromRGB(255, 120, 200), Vector3.new(0, 1.6, 0))
	frost.CFrame = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	newPart(model, "Hole", Enum.PartType.Cylinder, Vector3.new(0.6, 0.9, 0.9), Color3.fromRGB(120, 70, 20), Vector3.new(0, 1.7, 0))
		.CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, 5 do
		local angle = (i - 1) * (math.pi * 2 / 5)
		newPart(model, "Sprinkle" .. i, Enum.PartType.Block, Vector3.new(0.5, 0.15, 0.15),
			Color3.fromRGB(255, 255, 255), Vector3.new(math.cos(angle) * 1, 1.9, math.sin(angle) * 1))
	end
	eye(model, -0.6, 1.1, 1.6)
	eye(model, 0.6, 1.1, 1.6)
end

-- Builds one snack model. def is a Config.CHARACTERS entry, mutation a
-- Config.MUTATIONS entry. Returns the Model, unparented, at the origin.
function SnackFactory.buildSnackModel(def, mutation)
	local model = Instance.new("Model")
	model.Name = "Snack"

	local builder = Builders[def.builder]
	if builder then
		builder(model)
	else
		Builders.Toast(model)
	end

	local root = model:FindFirstChild("Body")
		or model:FindFirstChild("Bowl")
		or model:FindFirstChild("Bucket")
		or model:FindFirstChild("Cup")
		or model:FindFirstChild("Shell")
		or model:FindFirstChild("Ring")
		or model:FindFirstChild("Strip1")
		or model:GetChildren()[1]
	model.PrimaryPart = root

	-- Mutation aura: a small coloured orb floating above mutated snacks.
	if mutation.name ~= "None" then
		newPart(model, "Aura", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), mutation.color, Vector3.new(0, 4.2, 0))
	end

	-- Label anchor above the character, carrying the BillboardGui.
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(0, 4.6, 0)
	anchor.Parent = model

	local income = def.income * mutation.multiplier

	local gui = Instance.new("BillboardGui")
	gui.Name = "SnackLabel"
	gui.Size = UDim2.fromOffset(220, 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = anchor

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 32)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 0.35
	nameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = def.name
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = gui

	local rarityText = def.rarity
	if mutation.name ~= "None" then
		rarityText = def.rarity .. "  •  " .. mutation.name .. " x" .. tostring(mutation.multiplier)
	end
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, 0, 0, 26)
	rarityLabel.Position = UDim2.new(0, 0, 0, 32)
	rarityLabel.BackgroundTransparency = 0.35
	rarityLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	rarityLabel.TextColor3 = mutation.color
	rarityLabel.Text = rarityText
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.SourceSansBold
	rarityLabel.Parent = gui

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.new(1, 0, 0, 30)
	incomeLabel.Position = UDim2.new(0, 0, 0, 58)
	incomeLabel.BackgroundTransparency = 0.35
	incomeLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	incomeLabel.Text = "$" .. tostring(income) .. "/s"
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.SourceSansBold
	incomeLabel.Parent = gui

	-- Clicking a snack claims it (on the belt) or steals it (on a base).
	local click = Instance.new("ClickDetector")
	click.Name = "SnackClick"
	click.MaxActivationDistance = 40
	click.Parent = root

	return model
end

return SnackFactory
