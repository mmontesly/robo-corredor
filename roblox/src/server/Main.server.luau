local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Boot = require(script.Parent.Boot)

local rescueBound = false

Players.CharacterAutoLoads = true

local function part(props)
	local item = Instance.new(props.className or "Part")
	item.Name = props.name
	item.Anchored = true
	item.CanCollide = props.collide ~= false
	item.Size = props.size
	item.CFrame = props.cframe
	item.Color = props.color
	item.Parent = Workspace
	return item
end

local function writeSign(titleText, bodyText, color)
	local old = Workspace:FindFirstChild("NodexBootSign")
	if old then
		old:Destroy()
	end
	local board = part({
		name = "NodexBootSign",
		size = Vector3.new(28, 14, 1),
		cframe = CFrame.new(0, 14, -18),
		color = color,
		collide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 28
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0.28, 0)
	title.Position = UDim2.fromOffset(8, 8)
	title.Font = Enum.Font.SourceSansBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = titleText
	title.Parent = frame
	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -16, 0.62, 0)
	body.Position = UDim2.fromOffset(8, 70)
	body.Font = Enum.Font.SourceSans
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.new(1, 1, 1)
	body.Text = string.sub(bodyText, 1, 900)
	body.Parent = frame
end

local function ensureSafety()
	if Workspace:FindFirstChild("NodexSafety") then
		return
	end
	local floor = part({
		name = "NodexSafety",
		size = Vector3.new(80, 2, 80),
		cframe = CFrame.new(0, 3, 0),
		color = Color3.fromRGB(251, 133, 0),
	})
	pcall(function()
		floor.TopSurface = Enum.SurfaceType.Smooth
		floor.BottomSurface = Enum.SurfaceType.Smooth
	end)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NodexSafetySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 4.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = Workspace
	Workspace.Gravity = 196.2
	-- FallenPartsDestroyHeight não é gravável por Script (capability PluginOrOpenCloud).
	-- Quem cair volta para este chão no Heartbeat abaixo.
	writeSign("Nodex: Robô Corredor", "Servidor iniciou. Montando a Fábrica…", Color3.fromRGB(2, 48, 71))
	if not rescueBound then
		rescueBound = true
		game:GetService("RunService").Heartbeat:Connect(function()
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and root.Position.Y < -30 then
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					humanoid.PlatformStand = false
					root.CFrame = CFrame.new(0, 8, 0)
				end
			end
		end)
	end
end

local reported = false

Boot.run({
	log = print,
	ensureSafety = ensureSafety,
	installCharacter = function()
		local ok, err = pcall(function()
			require(script.Parent.RobotFactory).install()
		end)
		if not ok then
			warn("[Nodex] robô customizado falhou; o avatar padrão do Roblox será usado. " .. tostring(err))
			local starter = StarterPlayer:FindFirstChild("StarterCharacter")
			if starter then
				starter:Destroy()
			end
		end
	end,
	buildFactory = function()
		local pads = require(script.Parent.CourseBuilder).build()
		local safety = Workspace:FindFirstChild("NodexSafety")
		if safety then
			safety:Destroy()
		end
		local safetySpawn = Workspace:FindFirstChild("NodexSafetySpawn")
		if safetySpawn then
			safetySpawn:Destroy()
		end
		return pads
	end,
	startRace = function(pads)
		require(script.Parent.RaceService).start(pads)
		local sign = Workspace:FindFirstChild("NodexBootSign")
		if sign then
			sign:Destroy()
		end
	end,
	fail = function(err)
		reported = true
		warn("[Nodex] FALHA NO BOOT:\n" .. tostring(err))
		pcall(function()
			writeSign("Nodex: erro ao montar", tostring(err), Color3.fromRGB(180, 30, 30))
		end)
	end,
})

task.delay(3, function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			continue
		end
		warn("[Nodex] " .. player.Name .. " sem personagem após 3 s. Removendo StarterCharacter e carregando o avatar padrão.")
		local starter = StarterPlayer:FindFirstChild("StarterCharacter")
		if starter then
			starter:Destroy()
		end
		pcall(function()
			player:LoadCharacter()
		end)
	end
	if reported then
		warn("[Nodex] O chão laranja NodexSafety ficou no Workspace. Leia a placa vermelha e o Output.")
	end
end)
