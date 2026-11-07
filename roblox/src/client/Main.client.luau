-- Câmera lateral, corrida automática e pedidos ao servidor.
-- O servidor continua dono de bateria, óleo, engrenagem, posto e chegada.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("NodexRemotes", 30)
local action = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")

local keys = {
	w = false,
	a = false,
	s = false,
	d = false,
	space = false,
}
local latest = nil

local function fire(payload)
	action:FireServer(payload)
end

local hud = Hud.mount(player:WaitForChild("PlayerGui"), fire)

local function setKey(code, down)
	if code == Enum.KeyCode.W or code == Enum.KeyCode.Up then
		keys.w = down
	elseif code == Enum.KeyCode.S or code == Enum.KeyCode.Down then
		keys.s = down
	elseif code == Enum.KeyCode.A or code == Enum.KeyCode.Left then
		keys.a = down
	elseif code == Enum.KeyCode.D or code == Enum.KeyCode.Right then
		keys.d = down
	elseif code == Enum.KeyCode.Space then
		keys.space = down
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setKey(input.KeyCode, true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		setKey(input.KeyCode, false)
	end
end)

ContextActionService:BindActionAtPriority("NodexSinkMove", function()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space)

task.spawn(function()
	local scripts = player:WaitForChild("PlayerScripts", 15)
	if not scripts then
		return
	end
	local moduleScript = scripts:WaitForChild("PlayerModule", 15)
	if not moduleScript then
		return
	end
	local ok, controls = pcall(function()
		return require(moduleScript):GetControls()
	end)
	if ok and controls then
		controls:Disable()
	end
end)

local function applyCollected(ids)
	local set = {}
	if ids then
		for _, id in ipairs(ids) do
			set[id] = true
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(Config.TAG_PICKUP)) do
		if inst:IsA("BasePart") then
			local hide = set[inst:GetAttribute("ObstacleId")] == true
			inst.LocalTransparencyModifier = hide and 1 or 0
		end
	end
end

local function animateCourse(dt)
	local t = os.clock()
	for _, tooth in ipairs(CollectionService:GetTagged(Config.TAG_TOOTH)) do
		if tooth:IsA("BasePart") then
			local phase = tooth:GetAttribute("SpinPhase") or 0
			local cx = tooth:GetAttribute("SpinCX") or tooth.Position.X
			local cy = tooth:GetAttribute("SpinCY") or tooth.Position.Y
			local radius = tooth:GetAttribute("SpinRadius") or 2
			local angle = t * 1.7 + phase
			tooth.CFrame = CFrame.new(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, tooth.Position.Z) * CFrame.Angles(0, 0, angle)
		end
	end
	local shift = (t * 5) % 8
	for _, chevron in ipairs(CollectionService:GetTagged(Config.TAG_CHEVRON)) do
		if chevron:IsA("BasePart") then
			local home = chevron:GetAttribute("Home")
			if typeof(home) == "CFrame" then
				chevron.CFrame = home + Vector3.new(shift, 0, 0)
			end
		end
	end
	for _, bob in ipairs(CollectionService:GetTagged(Config.TAG_BOB)) do
		if bob:IsA("BasePart") and bob.LocalTransparencyModifier < 1 then
			local home = bob:GetAttribute("Home")
			if typeof(home) == "CFrame" then
				local wave = math.sin(t * 3 + home.Position.X * 0.2) * 0.25
				bob.CFrame = home + Vector3.new(0, wave, 0)
			end
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local char = other.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.Health > 0 then
			local lhip = char:FindFirstChild("Left Hip", true)
			local rhip = char:FindFirstChild("Right Hip", true)
			local lshould = char:FindFirstChild("Left Shoulder", true)
			local rshould = char:FindFirstChild("Right Shoulder", true)
			if lhip and rhip and lhip:IsA("Motor6D") and rhip:IsA("Motor6D") then
				local moving = hum.MoveDirection.Magnitude > 0.1 and hum.WalkSpeed > 0.5
				local airborne = hum.FloorMaterial == Enum.Material.Air
				local angle = 0
				if moving and not airborne then
					angle = math.sin(t * 9 + other.UserId) * 0.65
				elseif airborne then
					angle = -0.4
				end
				lhip.Transform = CFrame.Angles(0, 0, angle)
				rhip.Transform = CFrame.Angles(0, 0, -angle)
				if lshould and rshould and lshould:IsA("Motor6D") and rshould:IsA("Motor6D") then
					lshould.Transform = CFrame.Angles(0, 0, -angle * 0.5)
					rshould.Transform = CFrame.Angles(0, 0, angle * 0.5)
				end
			end
		end
	end
	return dt
end

local function drive(_dt)
	animateCourse(_dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 68
		if hrp then
			local look = hrp.Position + Vector3.new(12, 1.2, 0)
			local camPos = Vector3.new(hrp.Position.X - 4, hrp.Position.Y + 6.2, 32)
			camera.CFrame = CFrame.lookAt(camPos, look)
		end
	end
	if not hum or not hrp or hum.Health <= 0 or hrp.Anchored then
		return
	end
	local phase = ReplicatedStorage:GetAttribute("Phase")
	if phase == "countdown" or phase == "podium" then
		return
	end
	local holds = hud.holds()
	local jump = keys.space or holds.jump
	local axisX, axisZ = 0, 0
	if keys.d or holds.forward then
		axisX += 1
	end
	if keys.a or holds.back then
		axisX -= 1
	end
	if keys.s or holds.down then
		axisZ += 1
	end
	if keys.w or holds.up then
		axisZ -= 1
	end
	local racing = phase == "race" and player:GetAttribute("InRace") == true and player:GetAttribute("Finished") ~= true
	if racing then
		axisX = 1
		local speed = player:GetAttribute("MoveSpeed")
		if typeof(speed) == "number" then
			hum.WalkSpeed = speed
		end
	elseif phase == "lobby" then
		hum.WalkSpeed = Rules.LOBBY_SPEED
	end
	if jump and (racing or phase == "lobby") then
		hum.Jump = true
	end
	local dir = Vector3.new(axisX, 0, axisZ)
	if dir.Magnitude > 0.05 then
		hum:Move(dir.Unit, false)
	end
end

RunService:BindToRenderStep("NodexDrive", Enum.RenderPriority.Camera.Value + 1, drive)

stateRemote.OnClientEvent:Connect(function(snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end
	latest = snapshot
	hud.render(snapshot)
	applyCollected(snapshot.you and snapshot.you.collected or {})
end)

CollectionService:GetInstanceAddedSignal(Config.TAG_PICKUP):Connect(function()
	if latest and latest.you then
		applyCollected(latest.you.collected)
	end
end)

fire({ t = "hello" })
