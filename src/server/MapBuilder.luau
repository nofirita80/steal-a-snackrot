-- MapBuilder: builds the whole kitchen world in Luau at runtime.
-- A giant kitchen floor, a central conveyor belt carrying snacks, six base
-- plots ringing the plaza, kitchen decorations (table, fridge, shelves,
-- shakers, lamps) and the Midnight Hunger Wave wall. Returns the layout
-- GameServer needs: plot rects, slot positions, spawn pads and belt bounds.

local RunService = game:GetService("RunService")

local MapBuilder = {}

local PLOT_COLORS = {
	Color3.fromRGB(220, 70, 70),
	Color3.fromRGB(70, 130, 230),
	Color3.fromRGB(70, 200, 90),
	Color3.fromRGB(235, 200, 50),
	Color3.fromRGB(170, 90, 220),
	Color3.fromRGB(240, 130, 40),
}

local function box(parent, name, size, color, pos, angleY)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	if angleY then
		part.CFrame = CFrame.new(pos) * CFrame.Angles(0, angleY, 0)
	else
		part.CFrame = CFrame.new(pos)
	end
	part.Parent = parent
	return part
end

local function angleFor(axis)
	-- Y rotation that turns a part's long X axis onto the given XZ axis.
	return math.atan2(-axis.Z, axis.X)
end

function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "SnackrotMap"
	map.Parent = workspace

	-- Kitchen floor over the baseplate.
	box(map, "KitchenFloor", Vector3.new(240, 1, 200), Color3.fromRGB(208, 178, 138), Vector3.new(0, 0.5, 10))
	-- Centre rug.
	local rug = box(map, "Rug", Vector3.new(44, 0.2, 44), Color3.fromRGB(180, 60, 60), Vector3.new(0, 1.1, 20))
	rug.CanCollide = false

	-- Back wall with the game sign, plus shelves and jars.
	box(map, "BackWall", Vector3.new(200, 30, 2), Color3.fromRGB(235, 225, 200), Vector3.new(0, 15, 112))
	for _, shelfY in ipairs({ 8, 16, 24 }) do
		box(map, "Shelf", Vector3.new(120, 1, 6), Color3.fromRGB(150, 105, 60), Vector3.new(0, shelfY, 108))
		for i = 1, 6 do
			local jar = Instance.new("Part")
			jar.Name = "Jar"
			jar.Shape = Enum.PartType.Cylinder
			jar.Size = Vector3.new(3, 2, 2)
			jar.Color = Color3.fromRGB(120 + i * 18, 180, 140)
			jar.Anchored = true
			jar.CanCollide = false
			jar.CFrame = CFrame.new(-45 + (i - 1) * 18, shelfY + 2, 108) * CFrame.Angles(0, 0, math.pi / 2)
			jar.Parent = map
		end
	end
	-- Big sign on the back wall.
	local signPart = box(map, "SignBoard", Vector3.new(60, 10, 1), Color3.fromRGB(40, 40, 50), Vector3.new(0, 26, 110.5))
	signPart.CanCollide = false
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "TitleSign"
	signGui.Size = UDim2.fromOffset(600, 100)
	signGui.MaxDistance = 300
	signGui.LightInfluence = 0
	signGui.Parent = signPart
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.TextColor3 = Color3.fromRGB(255, 220, 90)
	signText.Text = "STEAL A SNACKROT"
	signText.TextScaled = true
	signText.Font = Enum.Font.SourceSansBold
	signText.Parent = signGui

	-- Conveyor belt across the north side of the plaza.
	local beltZ = -50
	box(map, "Belt", Vector3.new(200, 1, 10), Color3.fromRGB(50, 50, 55), Vector3.new(0, 1, beltZ))
	box(map, "BeltRailNear", Vector3.new(200, 1, 1), Color3.fromRGB(200, 200, 60), Vector3.new(0, 1.8, beltZ + 5))
	box(map, "BeltRailFar", Vector3.new(200, 1, 1), Color3.fromRGB(200, 200, 60), Vector3.new(0, 1.8, beltZ - 5))
	for x = -90, 90, 30 do
		box(map, "BeltLeg", Vector3.new(1, 1, 8), Color3.fromRGB(70, 70, 75), Vector3.new(x, 0.5, beltZ))
	end
	-- Moving chevrons on the belt.
	local stripes = {}
	for i = 1, 12 do
		local stripe = box(map, "BeltStripe", Vector3.new(1.5, 0.15, 8), Color3.fromRGB(240, 210, 60),
			Vector3.new(-95 + (i - 1) * 16, 1.55, beltZ))
		stripe.CanCollide = false
		table.insert(stripes, stripe)
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, stripe in ipairs(stripes) do
			local x = stripe.Position.X + 6 * dt
			if x > 95 then
				x -= 190
			end
			stripe.Position = Vector3.new(x, stripe.Position.Y, stripe.Position.Z)
		end
	end)

	-- Gate arches at both ends of the belt.
	local function gate(x, labelText)
		box(map, "GatePost1", Vector3.new(1, 8, 1), Color3.fromRGB(200, 200, 60), Vector3.new(x, 5, beltZ - 5))
		box(map, "GatePost2", Vector3.new(1, 8, 1), Color3.fromRGB(200, 200, 60), Vector3.new(x, 5, beltZ + 5))
		local beam = box(map, "GateBeam", Vector3.new(1, 1, 11), Color3.fromRGB(200, 200, 60), Vector3.new(x, 9, beltZ))
		local gui = Instance.new("BillboardGui")
		gui.Name = "GateSign"
		gui.Size = UDim2.fromOffset(260, 50)
		gui.MaxDistance = 200
		gui.LightInfluence = 0
		gui.Parent = beam
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.4
		text.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Text = labelText
		text.TextScaled = true
		text.Font = Enum.Font.SourceSansBold
		text.Parent = gui
	end
	gate(-95, "SNACK CONVEYOR")
	gate(95, "END OF BELT")

	-- Six base plots ringing the plaza, centred on (0, 20).
	local plots = {}
	local centre = Vector3.new(0, 0, 20)
	for i = 1, 6 do
		local angle = math.rad((i - 1) * 60)
		local plotCentre = Vector3.new(math.cos(angle) * 55, 0, 20 + math.sin(angle) * 55)
		local forward = (centre - plotCentre)
		forward = Vector3.new(forward.X, 0, forward.Z).Unit -- toward the plaza
		local right = Vector3.new(forward.Z, 0, -forward.X)
		local accent = PLOT_COLORS[i]

		local platform = box(map, "Plot" .. i, Vector3.new(26, 1, 26), Color3.fromRGB(225, 215, 195), plotCentre + Vector3.new(0, 0.5, 0))
		platform.Name = "PlotPlatform" .. i
		-- Accent trim strip on the entrance edge.
		box(map, "PlotTrim" .. i, Vector3.new(26, 0.4, 1), accent,
			plotCentre + forward * 13 + Vector3.new(0, 1.1, 0), angleFor(right)).CanCollide = false

		-- Low fences on three sides; the entrance side has a gap to walk in.
		local wallH = 2
		local function wall(name, pos, axis, length)
			box(map, name, Vector3.new(length, wallH, 0.5), accent, pos + Vector3.new(0, 1 + wallH / 2, 0), angleFor(axis))
		end
		wall("PlotFenceFar" .. i, plotCentre - forward * 13, right, 26)
		wall("PlotFenceLeft" .. i, plotCentre - right * 13, forward, 26)
		wall("PlotFenceRight" .. i, plotCentre + right * 13, forward, 26)
		wall("PlotFenceIn1" .. i, plotCentre + forward * 13 - right * 8, right, 10)
		wall("PlotFenceIn2" .. i, plotCentre + forward * 13 + right * 8, right, 10)

		-- Eight slot pads in a 4 x 2 grid.
		local slots = {}
		for row = 1, 2 do
			for col = 1, 4 do
				local colOff = (col - 2.5) * 5
				local rowOff = (row - 1.5) * 10
				local slotPos = plotCentre + right * colOff + forward * rowOff
				local pad = box(map, "SlotPad" .. i .. "_" .. #slots + 1, Vector3.new(4, 0.3, 4),
					Color3.fromRGB(245, 240, 225), slotPos + Vector3.new(0, 1.15, 0))
				pad.CanCollide = false
				table.insert(slots, Vector3.new(slotPos.X, 1.3, slotPos.Z))
			end
		end

		-- Spawn pad at the entrance.
		local spawnPos = plotCentre + forward * 10
		local spawnPad = box(map, "SpawnPad" .. i, Vector3.new(5, 0.3, 5), accent, spawnPos + Vector3.new(0, 1.15, 0))
		spawnPad.CanCollide = false

		table.insert(plots, {
			index = i,
			centre = plotCentre,
			accent = accent,
			slots = slots,
			spawn = Vector3.new(spawnPos.X, 1, spawnPos.Z),
			rect = {
				minX = plotCentre.X - 13,
				maxX = plotCentre.X + 13,
				minZ = plotCentre.Z - 13,
				maxZ = plotCentre.Z + 13,
			},
		})
	end

	-- Giant dining table at the south end.
	box(map, "TableTop", Vector3.new(60, 2, 30), Color3.fromRGB(170, 120, 70), Vector3.new(0, 7, 88))
	for _, dx in ipairs({ -27, 27 }) do
		for _, dz in ipairs({ -12, 12 }) do
			box(map, "TableLeg", Vector3.new(3, 6, 3), Color3.fromRGB(140, 95, 55), Vector3.new(dx, 3, 88 + dz))
		end
	end
	local plate = Instance.new("Part")
	plate.Name = "GiantPlate"
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(1, 14, 14)
	plate.Color = Color3.fromRGB(245, 245, 245)
	plate.Anchored = true
	plate.CanCollide = false
	plate.CFrame = CFrame.new(-15, 8.5, 88) * CFrame.Angles(0, 0, math.pi / 2)
	plate.Parent = map
	local mug = Instance.new("Part")
	mug.Name = "GiantMug"
	mug.Shape = Enum.PartType.Cylinder
	mug.Size = Vector3.new(6, 5, 5)
	mug.Color = Color3.fromRGB(70, 130, 220)
	mug.Anchored = true
	mug.CanCollide = false
	mug.CFrame = CFrame.new(15, 11, 88) * CFrame.Angles(0, 0, math.pi / 2)
	mug.Parent = map

	-- Giant fridge on the west side.
	box(map, "Fridge", Vector3.new(16, 30, 12), Color3.fromRGB(240, 240, 240), Vector3.new(-85, 15, 70))
	box(map, "FridgeHandle", Vector3.new(1, 10, 1), Color3.fromRGB(120, 120, 120), Vector3.new(-77.5, 20, 70))
	box(map, "FridgeDoorLine", Vector3.new(16, 0.5, 0.5), Color3.fromRGB(180, 180, 180), Vector3.new(-85, 18, 76.2))

	-- Salt and pepper shakers near the plaza.
	local salt = Instance.new("Part")
	salt.Name = "SaltShaker"
	salt.Shape = Enum.PartType.Cylinder
	salt.Size = Vector3.new(7, 3, 3)
	salt.Color = Color3.fromRGB(255, 255, 255)
	salt.Anchored = true
	salt.CFrame = CFrame.new(35, 4.5, -12) * CFrame.Angles(0, 0, math.pi / 2)
	salt.Parent = map
	local pepper = Instance.new("Part")
	pepper.Name = "PepperShaker"
	pepper.Shape = Enum.PartType.Cylinder
	pepper.Size = Vector3.new(7, 3, 3)
	pepper.Color = Color3.fromRGB(40, 40, 40)
	pepper.Anchored = true
	pepper.CFrame = CFrame.new(42, 4.5, -12) * CFrame.Angles(0, 0, math.pi / 2)
	pepper.Parent = map

	-- A giant spoon lying on the floor.
	local spoonBowl = Instance.new("Part")
	spoonBowl.Name = "SpoonBowl"
	spoonBowl.Shape = Enum.PartType.Ball
	spoonBowl.Size = Vector3.new(6, 1.5, 8)
	spoonBowl.Color = Color3.fromRGB(200, 200, 205)
	spoonBowl.Anchored = true
	spoonBowl.CFrame = CFrame.new(-40, 1.8, 30)
	spoonBowl.Parent = map
	box(map, "SpoonHandle", Vector3.new(1.5, 0.6, 14), Color3.fromRGB(200, 200, 205), Vector3.new(-40, 1.3, 40))

	-- Hanging lamps over the plaza.
	for _, lampPos in ipairs({ Vector3.new(0, 25, 20), Vector3.new(-40, 25, 60), Vector3.new(40, 25, 60) }) do
		local cord = Instance.new("Part")
		cord.Name = "LampCord"
		cord.Shape = Enum.PartType.Cylinder
		cord.Size = Vector3.new(15, 0.4, 0.4)
		cord.Color = Color3.fromRGB(30, 30, 30)
		cord.Anchored = true
		cord.CanCollide = false
		cord.CFrame = CFrame.new(lampPos.X, 32.5, lampPos.Z) * CFrame.Angles(0, 0, math.pi / 2)
		cord.Parent = map
		local shade = Instance.new("Part")
		shade.Name = "LampShade"
		shade.Shape = Enum.PartType.Cylinder
		shade.Size = Vector3.new(3, 5, 5)
		shade.Color = Color3.fromRGB(60, 60, 70)
		shade.Anchored = true
		shade.CanCollide = false
		shade.CFrame = CFrame.new(lampPos.X, 25, lampPos.Z) * CFrame.Angles(0, 0, math.pi / 2)
		shade.Parent = map
		local light = Instance.new("PointLight")
		light.Range = 45
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 220, 150)
		light.Parent = shade
	end

	-- The Midnight Hunger Wave wall: parked far away, GameServer sweeps it.
	local waveWall = Instance.new("Part")
	waveWall.Name = "HungerWaveWall"
	waveWall.Shape = Enum.PartType.Block
	waveWall.Size = Vector3.new(4, 42, 240)
	waveWall.Color = Color3.fromRGB(160, 30, 60)
	waveWall.Transparency = 0.55
	waveWall.Anchored = true
	waveWall.CanCollide = false
	waveWall.CanTouch = false
	waveWall.Material = Enum.Material.Neon
	waveWall.CFrame = CFrame.new(-300, 22, 10)
	waveWall.Parent = map

	return {
		plots = plots,
		belt = { minX = -95, maxX = 95, z = -50 },
		waveWall = waveWall,
	}
end

return MapBuilder
