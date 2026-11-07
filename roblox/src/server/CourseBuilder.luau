-- Constrói a Fábrica com Parts. Nada de Toolbox, decal, mesh ou som.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Course = require(Shared:WaitForChild("Course"))

local CourseBuilder = {}

local function color(c)
	return Config.toColor3(c)
end

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Name = props.name or "Part"
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = props.collide == true
	p.CanTouch = false
	p.CanQuery = props.query ~= false
	p.CastShadow = props.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.transparency then
		p.Transparency = props.transparency
	end
	if props.shape then
		p.Shape = props.shape
	end
	p.Parent = parent
	return p
end

local function floorRun(parent: Instance, x0: number, x1: number, widthZ: number, centerZ: number)
	local gray = color(Config.GROUND)
	local orange = color(Config.BELT)
	local x = x0
	while x < x1 - 0.1 do
		local len = math.min(40, x1 - x)
		local cx = x + len / 2
		part(parent, {
			name = "Base",
			size = Vector3.new(len, 3.2, widthZ),
			cframe = CFrame.new(cx, Course.FLOOR_TOP - 1.75, centerZ),
			color = gray,
			collide = true,
		})
		part(parent, {
			name = "Belt",
			size = Vector3.new(len, 0.3, widthZ),
			cframe = CFrame.new(cx, Course.FLOOR_TOP - 0.15, centerZ),
			color = orange,
			collide = true,
			shadow = false,
		})
		x += len
	end
end

local function chevron(parent: Instance, x: number, y: number, z: number)
	local white = Color3.fromRGB(236, 240, 244)
	for _, tilt in ipairs({ 38, -38 }) do
		local sign = tilt > 0 and 1 or -1
		local p = part(parent, {
			name = "Chevron",
			size = Vector3.new(1.35, 0.22, 0.18),
			cframe = CFrame.new(x, y + sign * 0.32, z) * CFrame.Angles(0, 0, math.rad(tilt)),
			color = white,
			shadow = false,
		})
		p:SetAttribute("Home", p.CFrame)
		CollectionService:AddTag(p, Config.TAG_CHEVRON)
	end
end

local function gear(parent: Instance, box)
	local model = Instance.new("Model")
	model.Name = "Gear_" .. box.id
	local center = Vector3.new(box.x, box.y, 0)
	local hub = part(model, {
		name = "Hub",
		size = Vector3.new(Course.LANE_HALF * 2, Course.GEAR_DIAMETER, Course.GEAR_DIAMETER),
		cframe = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
		color = color(Config.GEAR),
		material = Enum.Material.Metal,
		collide = true,
		shape = Enum.PartType.Cylinder,
	})
	hub:SetAttribute("Kind", "gear")
	hub:SetAttribute("ObstacleId", box.id)
	local cap = part(model, {
		name = "Cap",
		size = Vector3.new(Course.LANE_HALF * 2 + 0.2, 1.1, 1.1),
		cframe = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
		color = color(Config.BELT),
		collide = false,
		shape = Enum.PartType.Cylinder,
		shadow = false,
	})
	cap.CanCollide = false
	local radius = Course.GEAR_DIAMETER / 2 + 0.7
	for i = 1, 8 do
		local phase = (i - 1) * (math.pi / 4)
		local tooth = part(model, {
			name = "Tooth",
			size = Vector3.new(1.15, 0.7, Course.LANE_HALF * 2 - 1.2),
			cframe = CFrame.new(center + Vector3.new(math.cos(phase) * radius, math.sin(phase) * radius, 0)),
			color = color(Config.GEAR_TOOTH),
			material = Enum.Material.Metal,
			shadow = false,
		})
		tooth:SetAttribute("SpinCX", center.X)
		tooth:SetAttribute("SpinCY", center.Y)
		tooth:SetAttribute("SpinPhase", phase)
		tooth:SetAttribute("SpinRadius", radius)
		CollectionService:AddTag(tooth, Config.TAG_TOOTH)
	end
	model.PrimaryPart = hub
	model.Parent = parent
end

local function oil(parent: Instance, box)
	local puddle = part(parent, {
		name = "Oil_" .. box.id,
		size = Vector3.new(Course.OIL_LENGTH, 0.28, Course.LANE_HALF * 2 - 0.4),
		cframe = CFrame.new(box.x, Course.FLOOR_TOP + 0.2, 0),
		color = color(Config.OIL),
		transparency = 0.12,
		shadow = false,
	})
	puddle:SetAttribute("Kind", "oil")
	puddle:SetAttribute("ObstacleId", box.id)
	local shine = part(parent, {
		name = "OilShine_" .. box.id,
		size = Vector3.new(Course.OIL_LENGTH * 0.55, 0.08, 2.2),
		cframe = CFrame.new(box.x, Course.FLOOR_TOP + 0.38, 1.2),
		color = Color3.fromRGB(90, 140, 190),
		transparency = 0.35,
		shadow = false,
	})
	shine.CanCollide = false
end

local function battery(parent: Instance, box)
	local model = Instance.new("Model")
	model.Name = "Battery_" .. box.id
	local y = box.y
	local body = part(model, {
		name = "Body",
		size = Vector3.new(1.5, 2.3, 0.8),
		cframe = CFrame.new(box.x, y, 0),
		color = color(Config.BATTERY),
		material = Enum.Material.SmoothPlastic,
		shadow = false,
	})
	local cap = part(model, {
		name = "Cap",
		size = Vector3.new(0.7, 0.28, 0.4),
		cframe = CFrame.new(box.x, y + 1.28, 0),
		color = color(Config.BATTERY_CAP),
		shadow = false,
	})
	local plusV = part(model, {
		name = "PlusV",
		size = Vector3.new(0.16, 0.7, 0.08),
		cframe = CFrame.new(box.x, y + 0.05, 0.42),
		color = Color3.new(1, 1, 1),
		shadow = false,
	})
	local plusH = part(model, {
		name = "PlusH",
		size = Vector3.new(0.55, 0.16, 0.08),
		cframe = CFrame.new(box.x, y + 0.05, 0.42),
		color = Color3.new(1, 1, 1),
		shadow = false,
	})
	local glow = part(model, {
		name = "Glow",
		size = Vector3.new(Course.BATTERY_LENGTH, 0.15, Course.LANE_HALF * 2 - 1),
		cframe = CFrame.new(box.x, Course.FLOOR_TOP + 0.42, 0),
		color = color(Config.BATTERY_CAP),
		transparency = 0.45,
		material = Enum.Material.Neon,
		shadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color(Config.BATTERY)
	light.Brightness = 1.4
	light.Range = 14
	light.Parent = body
	for _, p in ipairs({ body, cap, plusV, plusH, glow }) do
		p:SetAttribute("Home", p.CFrame)
		p:SetAttribute("ObstacleId", box.id)
		CollectionService:AddTag(p, Config.TAG_PICKUP)
		CollectionService:AddTag(p, Config.TAG_BOB)
	end
	model.PrimaryPart = body
	model.Parent = parent
end

local function arch(parent: Instance, x: number, labelText: string, accent)
	local tall = 11
	local z = Course.LANE_HALF - 0.4
	local pillarL = part(parent, {
		name = "Pillar",
		size = Vector3.new(1.1, tall, 1.1),
		cframe = CFrame.new(x, Course.FLOOR_TOP + tall / 2, -z),
		color = accent,
		collide = true,
	})
	local pillarR = part(parent, {
		name = "Pillar",
		size = Vector3.new(1.1, tall, 1.1),
		cframe = CFrame.new(x, Course.FLOOR_TOP + tall / 2, z),
		color = accent,
		collide = true,
	})
	part(parent, {
		name = "Beam",
		size = Vector3.new(1.3, 1.1, z * 2 + 1),
		cframe = CFrame.new(x, Course.FLOOR_TOP + tall, 0),
		color = accent,
		collide = true,
	})
	local board = part(parent, {
		name = "Sign",
		size = Vector3.new(4.4, 1.6, 0.3),
		cframe = CFrame.new(x, Course.FLOOR_TOP + tall - 0.2, 0),
		color = color(Config.WHITE),
		shadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = color(Config.NAVY)
	text.Text = labelText
	text.Parent = gui
	return pillarL, pillarR
end

local function spawnPad(parent: Instance, name: string, x: number, z: number): SpawnLocation
	local pad = Instance.new("SpawnLocation")
	pad.Name = name
	pad.Size = Vector3.new(6, 1, 6)
	pad.CFrame = CFrame.new(x, Course.FLOOR_TOP - 0.5, z)
	pad.Anchored = true
	pad.CanCollide = false
	pad.Transparency = 1
	pad.Neutral = true
	pad.Duration = 0
	pad.Enabled = true
	pad.CastShadow = false
	pad.Parent = parent
	return pad
end

local function machines(parent: Instance)
	for i = 0, 14 do
		local x = -10 + i * 58
		local h = 9 + (i % 3) * 3.5
		local tint = Config.MACHINES[(i % #Config.MACHINES) + 1]
		local body = part(parent, {
			name = "Machine",
			size = Vector3.new(16, h, 6),
			cframe = CFrame.new(x, h / 2, -18),
			color = color(tint),
		})
		part(parent, {
			name = "Window",
			size = Vector3.new(7, 3.2, 0.3),
			cframe = CFrame.new(x, h * 0.62, -14.85),
			color = Color3.fromRGB(255, 248, 220),
			material = Enum.Material.Neon,
			transparency = 0.15,
			shadow = false,
		})
		if i % 2 == 0 then
			local stackHeight = h + 6
			part(parent, {
				name = "Stack",
				size = Vector3.new(stackHeight, 2.2, 2.2),
				cframe = CFrame.new(x + 6, stackHeight / 2, -22) * CFrame.Angles(0, 0, math.rad(90)),
				color = color(Config.GROUND),
				shape = Enum.PartType.Cylinder,
			})
		end
		body.CanCollide = true
	end
	part(parent, {
		name = "Pipe",
		size = Vector3.new(Course.TRACK_END - Course.TRACK_MIN_X, 1.1, 1.1),
		cframe = CFrame.new((Course.TRACK_MIN_X + Course.TRACK_END) / 2, 16, -23) * CFrame.Angles(0, 0, math.rad(90)),
		color = color(Config.GROUND),
		shape = Enum.PartType.Cylinder,
	})
end

local function backdrop(parent: Instance)
	part(parent, {
		name = "SkyWall",
		size = Vector3.new(Course.TRACK_END - Course.LOBBY_MIN_X + 80, 80, 2),
		cframe = CFrame.new((Course.LOBBY_MIN_X + Course.TRACK_END) / 2, 36, -36),
		color = color(Config.SKY),
		shadow = false,
		query = false,
	})
end

local function lobbySign(parent: Instance)
	local board = part(parent, {
		name = "LobbySign",
		size = Vector3.new(18, 8, 0.4),
		cframe = CFrame.new(-78, Course.FLOOR_TOP + 7, -13),
		color = color(Config.WHITE),
		collide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 36
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color(Config.WHITE)
	frame.Parent = gui
	local function line(text: string, y: number, h: number, col, weight)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, h)
		label.Font = weight
		label.TextScaled = true
		label.TextColor3 = col
		label.Text = text
		label.Parent = frame
	end
	line(Config.TITLE, 0.06, 0.28, color(Config.TITLE_ORANGE), Enum.Font.GothamBold)
	line("🏭  " .. Config.WORLD, 0.36, 0.16, color(Config.NAVY), Enum.Font.GothamBold)
	line(Config.TIP_JUMP, 0.56, 0.16, color(Config.NAVY), Enum.Font.Gotham)
	line(Config.TIP_BATTERY, 0.74, 0.16, color(Config.NAVY), Enum.Font.Gotham)
end

local function lessonProps(parent: Instance)
	local z = 10
	local baseX = -96
	local hub = part(parent, {
		name = "SampleGear",
		size = Vector3.new(1.2, 3.2, 3.2),
		cframe = CFrame.new(baseX, Course.FLOOR_TOP + 2.2, z) * CFrame.Angles(0, math.rad(90), 0),
		color = color(Config.GEAR),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
	})
	hub.CanCollide = false
	local puddle = part(parent, {
		name = "SampleOil",
		size = Vector3.new(4, 0.25, 3),
		cframe = CFrame.new(baseX + 6, Course.FLOOR_TOP + 0.2, z),
		color = color(Config.OIL),
	})
	puddle.CanCollide = false
	local cell = part(parent, {
		name = "SampleBattery",
		size = Vector3.new(1.2, 1.8, 0.6),
		cframe = CFrame.new(baseX + 11, Course.FLOOR_TOP + 1.5, z),
		color = color(Config.BATTERY),
	})
	cell.CanCollide = false
end

local function podium(parent: Instance)
	local paints = {
		Color3.fromRGB(255, 212, 59),
		Color3.fromRGB(222, 226, 230),
		Color3.fromRGB(205, 127, 50),
	}
	local ranks = { 2, 1, 3 }
	for _, rank in ipairs(ranks) do
		local x, _, _, _, extra = Course.podiumPose(rank, rank)
		if extra > 0 then
			local step = part(parent, {
				name = "Podium" .. tostring(rank),
				size = Vector3.new(6.5, extra, 7),
				cframe = CFrame.new(x, Course.FLOOR_TOP + extra / 2, 0),
				color = paints[rank],
				collide = true,
			})
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(80, 36)
			gui.StudsOffset = Vector3.new(0, extra / 2 + 1.2, 0)
			gui.AlwaysOnTop = true
			gui.Parent = step
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.fromScale(1, 1)
			text.Font = Enum.Font.GothamBold
			text.TextScaled = true
			text.TextColor3 = color(Config.NAVY)
			text.Text = tostring(rank) .. "º"
			text.Parent = gui
		end
	end
end

local function lighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(180, 158, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 168, 115)
	Lighting.FogColor = color(Config.SKY)
	Lighting.FogStart = 180
	Lighting.FogEnd = 700
	local old = Lighting:FindFirstChild("NodexAtmosphere")
	if old then
		old:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "NodexAtmosphere"
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.2
	atmosphere.Color = color(Config.SKY)
	atmosphere.Decay = color(Config.SKY)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
end

function CourseBuilder.build()
	local ok, errs = Course.validate()
	if not ok then
		error("[Nodex] Pista inválida: " .. table.concat(errs, "; "))
	end

	local previous = workspace:FindFirstChild("NodexWorld")
	if previous then
		previous:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "NodexWorld"
	world.Parent = workspace

	workspace.StreamingEnabled = false
	workspace.FallenPartsDestroyHeight = -80
	workspace.Gravity = 196.2

	lighting()
	backdrop(world)

	local track = Instance.new("Folder")
	track.Name = "Track"
	track.Parent = world
	floorRun(track, Course.TRACK_MIN_X, Course.TRACK_END, Course.LANE_HALF * 2, 0)

	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = world
	floorRun(lobby, Course.LOBBY_MIN_X, Course.LOBBY_MAX_X, Course.LOBBY_HALF_Z * 2, 0)
	lobbySign(lobby)
	podium(lobby)

	-- Muro invisível do lado da câmera e vidro do lado da fábrica.
	local span = Course.TRACK_END - Course.TRACK_MIN_X
	local mid = (Course.TRACK_MIN_X + Course.TRACK_END) / 2
	part(track, {
		name = "NearWall",
		size = Vector3.new(span, 14, 0.6),
		cframe = CFrame.new(mid, Course.FLOOR_TOP + 7, Course.LANE_HALF + 1.1),
		color = color(Config.SKY),
		transparency = 1,
		collide = true,
		shadow = false,
		query = false,
	})
	part(track, {
		name = "FarGlass",
		size = Vector3.new(span, 12, 0.5),
		cframe = CFrame.new(mid, Course.FLOOR_TOP + 6, -Course.LANE_HALF - 0.8),
		color = Color3.fromRGB(190, 220, 235),
		material = Enum.Material.Glass,
		transparency = 0.45,
		collide = true,
		shadow = false,
	})
	part(track, {
		name = "FinishWall",
		size = Vector3.new(1.2, 8, Course.LANE_HALF * 2),
		cframe = CFrame.new(Course.FINISH_X + 6, Course.FLOOR_TOP + 4, 0),
		color = color(Config.GROUND),
		collide = true,
	})

	part(track, {
		name = "StartLine",
		size = Vector3.new(0.4, 0.15, Course.LANE_HALF * 2),
		cframe = CFrame.new(Course.START_X, Course.FLOOR_TOP + 0.2, 0),
		color = color(Config.WHITE),
		shadow = false,
	})

	local decor = Instance.new("Folder")
	decor.Name = "Course"
	decor.Parent = world
	for _, box in ipairs(Course.boxes()) do
		if box.kind == "gear" then
			gear(decor, box)
		elseif box.kind == "oil" then
			oil(decor, box)
		else
			battery(decor, box)
		end
	end

	for _, cp in ipairs(Course.CHECKPOINTS) do
		arch(decor, cp.x, "POSTO " .. tostring(cp.index), color(Config.BELT))
	end
	arch(decor, Course.FINISH_X, "CHEGADA", color(Config.NAVY))

	local x = Course.TRACK_MIN_X + 6
	while x < Course.TRACK_END do
		chevron(decor, x, Course.FLOOR_TOP - 1.35, Course.LANE_HALF + 0.16)
		x += 8
	end

	machines(decor)
	lessonProps(lobby)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = world
	local pads = {
		lobby = spawnPad(spawns, "Lobby", -78, 0),
		track = {},
	}
	pads.track[0] = spawnPad(spawns, "Start", Course.SPAWN_X, 0)
	for _, cp in ipairs(Course.CHECKPOINTS) do
		pads.track[cp.index] = spawnPad(spawns, "Posto" .. tostring(cp.index), cp.x - Course.RESPAWN_BACK, 0)
	end

	return pads
end

return CourseBuilder
