-- Steal a Snackrot — MapBuilder
-- Builds the giant kitchen: the floor and rug, the snack conveyor
-- with its sliding chevrons, gate arches, the back wall with shelves
-- and the big gold sign, six coloured base plots, kitchen props and
-- the wave wall.

local Config = require(script.Parent.Config)

local MapBuilder = {}

local PLOT_COLORS = {
	Color3.fromRGB(220, 60, 60),
	Color3.fromRGB(60, 120, 230),
	Color3.fromRGB(70, 190, 90),
	Color3.fromRGB(240, 200, 50),
	Color3.fromRGB(160, 80, 220),
	Color3.fromRGB(240, 130, 40),
}

-- One anchored, collidable part.
local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, pos: Vector3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.Position = pos
	p.Parent = parent
	return p
end

-- A text label painted on the front face of a part.
local function paintText(parent: Instance, text: string, size: UDim2, color: Color3, scaled: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = scaled ~= false
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	return label
end

local function buildFloor(world: Folder)
	makePart(world, "KitchenFloor", Vector3.new(240, 1, 200), Color3.fromRGB(210, 175, 120), Vector3.new(0, 0, 10), Enum.Material.WoodPlanks)
	makePart(world, "CentreRug", Vector3.new(60, 0.2, 44), Color3.fromRGB(190, 40, 40), Vector3.new(0, 0.6, 20), Enum.Material.Fabric)
	makePart(world, "RugTrim", Vector3.new(56, 0.22, 40), Color3.fromRGB(240, 200, 90), Vector3.new(0, 0.62, 20), Enum.Material.Fabric)
end

local function buildConveyor(world: Folder): { Part }
	makePart(world, "ConveyorBelt", Vector3.new(200, 1, 10), Color3.fromRGB(70, 70, 75), Vector3.new(0, 1, Config.CONVEYOR_Z))
	makePart(world, "ConveyorRailNorth", Vector3.new(200, 0.8, 0.6), Color3.fromRGB(240, 200, 50), Vector3.new(0, 1.8, Config.CONVEYOR_Z - 5))
	makePart(world, "ConveyorRailSouth", Vector3.new(200, 0.8, 0.6), Color3.fromRGB(240, 200, 50), Vector3.new(0, 1.8, Config.CONVEYOR_Z + 5))
	for x = -90, 90, 20 do
		makePart(world, "BeltLeg", Vector3.new(1.5, 1, 1.5), Color3.fromRGB(50, 50, 55), Vector3.new(x, 0.5, Config.CONVEYOR_Z))
	end
	-- Twelve yellow chevron stripes that slide along the belt.
	local chevrons = {}
	for i = 1, 12 do
		local chevron = makePart(world, "Chevron" .. tostring(i), Vector3.new(2.5, 0.15, 7), Color3.fromRGB(250, 210, 60), Vector3.new(-95 + (i - 1) * 16, 1.6, Config.CONVEYOR_Z))
		chevron.CanCollide = false
		chevron.Material = Enum.Material.Neon
		table.insert(chevrons, chevron)
	end

	-- Gate arches at both ends of the belt.
	for _, gate in ipairs({
		{ x = -100, label = "SNACK CONVEYOR" },
		{ x = 100, label = "END OF BELT" },
	}) do
		makePart(world, "GatePostLeft", Vector3.new(1.5, 12, 1.5), Color3.fromRGB(200, 50, 50), Vector3.new(gate.x, 6, Config.CONVEYOR_Z - 6))
		makePart(world, "GatePostRight", Vector3.new(1.5, 12, 1.5), Color3.fromRGB(200, 50, 50), Vector3.new(gate.x, 6, Config.CONVEYOR_Z + 6))
		local beam = makePart(world, "GateBeam", Vector3.new(1.5, 2, 14), Color3.fromRGB(220, 60, 60), Vector3.new(gate.x, 12.5, Config.CONVEYOR_Z))
		paintText(beam, gate.label, UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255))
	end
	return chevrons
end

local function buildBackWall(world: Folder)
	makePart(world, "BackWall", Vector3.new(200, 30, 2), Color3.fromRGB(235, 220, 200), Vector3.new(0, 15, -78), Enum.Material.Wood)
	local sign = makePart(world, "TitleSign", Vector3.new(70, 10, 1), Color3.fromRGB(40, 30, 25), Vector3.new(0, 22, -76.5), Enum.Material.Wood)
	paintText(sign, "STEAL A SNACKROT", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 210, 80))
	-- Three wooden shelves with coloured jars.
	for i = 1, 3 do
		local shelfX = (i - 2) * 55
		makePart(world, "Shelf" .. tostring(i), Vector3.new(36, 1, 4), Color3.fromRGB(150, 100, 55), Vector3.new(shelfX, 10, -76), Enum.Material.Wood)
		for j = 1, 4 do
			local jarColor = Color3.fromRGB(200 + (j * 10) % 55, 120 + (i * 40) % 120, 80 + (j * 50) % 150)
			makePart(world, "Jar" .. tostring(i) .. "_" .. tostring(j), Vector3.new(3, 4, 3), jarColor, Vector3.new(shelfX - 13 + (j - 1) * 9, 12.5, -76), Enum.Material.Glass)
		end
	end
end

-- One base plot. `angle` places it on the ring; the entrance faces the centre.
local function buildPlot(world: Folder, index: number, angle: number): { centre: Vector3, slots: { Vector3 }, spawn: Vector3, accent: Color3 }
	local centre = Vector3.new(math.cos(angle) * Config.PLOT_RADIUS, 0, Config.PLOT_CENTRE.Z + math.sin(angle) * Config.PLOT_RADIUS)
	local accent = PLOT_COLORS[index]

	local platform = makePart(world, "Plot" .. tostring(index), Vector3.new(Config.PLOT_SIZE, 1, Config.PLOT_SIZE), Color3.fromRGB(245, 235, 210), centre + Vector3.new(0, 0.5, 0))
	platform.Material = Enum.Material.WoodPlanks
	makePart(world, "PlotTrim" .. tostring(index), Vector3.new(Config.PLOT_SIZE + 1, 0.4, Config.PLOT_SIZE + 1), accent, centre + Vector3.new(0, 0.3, 0))

	-- Entrance direction: from the plot centre toward the plaza centre.
	local toCentre = (Vector3.new(Config.PLOT_CENTRE.X, 0, Config.PLOT_CENTRE.Z) - centre).Unit
	local side = Vector3.new(-toCentre.Z, 0, toCentre.X)
	local half = Config.PLOT_SIZE / 2

	-- Low fences on three sides, with a gap at the entrance side.
	-- Each run is a thin bar `length` long, centred on `mid`.
	local function fenceRun(mid: Vector3, length: number)
		makePart(world, "Fence", Vector3.new(0.6, 3, length), accent, mid + Vector3.new(0, 2, 0))
	end
	-- Back side (opposite the entrance).
	fenceRun(centre - toCentre * half, Config.PLOT_SIZE)
	-- Left and right sides, each split so the entrance gap stays open.
	for _, s in ipairs({ -1, 1 }) do
		local sideMid = centre + side * (s * half)
		fenceRun(sideMid - toCentre * (half / 2), half)
	end

	-- Eight slot pads in a 4-by-2 grid, and a spawn pad at the entrance.
	local slots = {}
	for row = 0, 1 do
		for col = 0, 3 do
			local offset = side * ((col - 1.5) * 5) + toCentre * ((row - 0.5) * 6 - 2)
			local padPos = centre + offset + Vector3.new(0, 1.1, 0)
			local pad = makePart(world, "SlotPad" .. tostring(index) .. "_" .. tostring(row * 4 + col + 1), Vector3.new(4, 0.3, 4), accent, padPos)
			pad.Material = Enum.Material.Neon
			pad.CanCollide = false
			table.insert(slots, padPos)
		end
	end
	local spawnPos = centre + toCentre * (half + 3) + Vector3.new(0, 1.2, 0)
	local spawnPad = makePart(world, "SpawnPad" .. tostring(index), Vector3.new(5, 0.3, 5), Color3.fromRGB(255, 255, 255), spawnPos)
	spawnPad.Material = Enum.Material.Neon
	spawnPad.CanCollide = false

	return { centre = centre, slots = slots, spawn = spawnPos, accent = accent }
end

local function buildDecor(world: Folder)
	-- Giant dining table at the south end, with a plate and a mug.
	makePart(world, "DiningTable", Vector3.new(50, 3, 24), Color3.fromRGB(140, 90, 50), Vector3.new(0, 4, 88), Enum.Material.Wood)
	makePart(world, "TableLegL", Vector3.new(3, 4, 3), Color3.fromRGB(110, 70, 40), Vector3.new(-20, 2, 88))
	makePart(world, "TableLegR", Vector3.new(3, 4, 3), Color3.fromRGB(110, 70, 40), Vector3.new(20, 2, 88))
	makePart(world, "Plate", Vector3.new(8, 0.5, 8), Color3.fromRGB(250, 250, 250), Vector3.new(-8, 5.8, 88), Enum.Material.Ceramic)
	makePart(world, "Mug", Vector3.new(3, 4, 3), Color3.fromRGB(60, 120, 200), Vector3.new(10, 7.5, 88), Enum.Material.Ceramic)

	-- Giant white fridge on the west side.
	makePart(world, "Fridge", Vector3.new(16, 34, 14), Color3.fromRGB(240, 240, 240), Vector3.new(-105, 17, 30), Enum.Material.Metal)
	makePart(world, "FridgeHandle", Vector3.new(1, 10, 1.5), Color3.fromRGB(180, 180, 180), Vector3.new(-96.5, 20, 30), Enum.Material.Metal)

	-- Salt and pepper shakers near the plaza.
	makePart(world, "SaltShaker", Vector3.new(3, 7, 3), Color3.fromRGB(250, 250, 250), Vector3.new(45, 3.5, 45), Enum.Material.Glass)
	makePart(world, "PepperShaker", Vector3.new(3, 7, 3), Color3.fromRGB(40, 40, 40), Vector3.new(52, 3.5, 45), Enum.Material.Glass)

	-- A giant spoon lying on the floor.
	local spoonBowl = makePart(world, "SpoonBowl", Vector3.new(6, 1, 9), Color3.fromRGB(200, 200, 205), Vector3.new(-45, 0.8, 60), Enum.Material.Metal)
	spoonBowl.CFrame = CFrame.new(-45, 0.8, 60) * CFrame.Angles(0, math.rad(35), 0)
	local spoonHandle = makePart(world, "SpoonHandle", Vector3.new(1.5, 0.8, 16), Color3.fromRGB(200, 200, 205), Vector3.new(-38, 0.8, 52), Enum.Material.Metal)
	spoonHandle.CFrame = CFrame.new(-38, 0.8, 52) * CFrame.Angles(0, math.rad(35), 0)

	-- Three hanging lamps with warm point lights over the plaza.
	for i = -1, 1 do
		local lamp = makePart(world, "Lamp" .. tostring(i + 2), Vector3.new(4, 1, 4), Color3.fromRGB(60, 60, 60), Vector3.new(i * 40, 24, 20), Enum.Material.Metal)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Range = 60
		light.Brightness = 2
		light.Parent = lamp
		makePart(world, "LampCord" .. tostring(i + 2), Vector3.new(0.4, 8, 0.4), Color3.fromRGB(40, 40, 40), Vector3.new(i * 40, 28, 20))
	end
end

local function buildWaveWall(world: Folder): Part
	local wall = makePart(world, "WaveWall", Vector3.new(4, 42, 240), Color3.fromRGB(220, 30, 30), Vector3.new(Config.WAVE_PARK_X, 21, 0), Enum.Material.Neon)
	wall.Transparency = 0.45
	wall.CanCollide = false
	return wall
end

-- Builds the whole world and returns the plot table and the wave wall.
function MapBuilder.build(): { plots: { { centre: Vector3, slots: { Vector3 }, spawn: Vector3, accent: Color3 } }, chevrons: { Part }, waveWall: Part }
	local world = Instance.new("Folder")
	world.Name = "SnackrotWorld"
	world.Parent = workspace

	buildFloor(world)
	local chevrons = buildConveyor(world)
	buildBackWall(world)
	buildDecor(world)
	local waveWall = buildWaveWall(world)

	local plots = {}
	for i = 1, Config.PLOT_COUNT do
		local angle = (i - 1) * (math.pi * 2 / Config.PLOT_COUNT)
		plots[i] = buildPlot(world, i, angle)
	end

	return { plots = plots, chevrons = chevrons, waveWall = waveWall }
end

return MapBuilder
