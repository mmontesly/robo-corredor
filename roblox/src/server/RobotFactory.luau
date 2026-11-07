-- Robô de blocos com Humanoid R6. Sem mesh, sem decal e sem animação da plataforma.
-- O rosto olha para a câmera lateral (+Z) enquanto o corpo corre para +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Course = require(Shared:WaitForChild("Course"))
local Rules = require(Shared:WaitForChild("Rules"))

local RobotFactory = {}

local HIP = 3

local function part(props): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = props.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		p.Shape = props.shape
	end
	if props.role then
		p:SetAttribute("Role", props.role)
	end
	p.Parent = props.parent
	return p
end

local function joint(name: string, part0: BasePart, part1: BasePart)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	motor.C1 = CFrame.new()
	motor.Parent = part0
	return motor
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

function RobotFactory.install()
	if Course.HIP ~= HIP then
		error("[Nodex] O rig do robô foi medido para HipHeight 3.")
	end

	local existing = StarterPlayer:FindFirstChild("StarterCharacter")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "StarterCharacter"

	local azul = Color3.fromRGB(76, 201, 240)
	local white = Color3.fromRGB(255, 255, 255)
	local ink = Color3.fromRGB(20, 24, 36)
	local yellow = Color3.fromRGB(255, 214, 70)
	local dark = Color3.fromRGB(40, 48, 58)

	local hrp = part({
		name = "HumanoidRootPart",
		size = Vector3.new(2, 2, 1),
		cframe = CFrame.new(0, HIP, 0),
		color = azul,
		parent = model,
		shadow = false,
	})
	hrp.Transparency = 1
	hrp.RootPriority = 1
	hrp.CanQuery = true
	hrp.CanTouch = true

	local torso = part({
		name = "Torso",
		size = Vector3.new(2.2, 2, 1.2),
		cframe = CFrame.new(0, HIP, 0),
		color = azul,
		parent = model,
		role = "body",
	})
	local head = part({
		name = "Head",
		size = Vector3.new(1.8, 1.5, 1.8),
		cframe = CFrame.new(0, 4.75, 0),
		color = azul,
		parent = model,
		role = "body",
	})
	local leftArm = part({
		name = "Left Arm",
		size = Vector3.new(0.9, 2, 0.9),
		cframe = CFrame.new(-1.6, HIP, 0),
		color = azul,
		parent = model,
		role = "body",
	})
	local rightArm = part({
		name = "Right Arm",
		size = Vector3.new(0.9, 2, 0.9),
		cframe = CFrame.new(1.6, HIP, 0),
		color = azul,
		parent = model,
		role = "body",
	})
	local leftLeg = part({
		name = "Left Leg",
		size = Vector3.new(0.95, 2, 1),
		cframe = CFrame.new(-0.55, 1, 0),
		color = azul,
		parent = model,
		role = "body",
	})
	local rightLeg = part({
		name = "Right Leg",
		size = Vector3.new(0.95, 2, 1),
		cframe = CFrame.new(0.55, 1, 0),
		color = azul,
		parent = model,
		role = "body",
	})

	local function face(name: string, size: Vector3, cf: CFrame, color: Color3, role: string)
		return part({
			name = name,
			size = size,
			cframe = cf,
			color = color,
			parent = model,
			role = role,
			shadow = false,
		})
	end

	local eyeL = face("EyeL", Vector3.new(0.32, 0.36, 0.16), CFrame.new(-0.38, 4.9, 0.98), white, "eye")
	local eyeR = face("EyeR", Vector3.new(0.32, 0.36, 0.16), CFrame.new(0.38, 4.9, 0.98), white, "eye")
	local pupilL = face("PupilL", Vector3.new(0.16, 0.18, 0.1), CFrame.new(-0.38, 4.86, 1.08), ink, "pupil")
	local pupilR = face("PupilR", Vector3.new(0.16, 0.18, 0.1), CFrame.new(0.38, 4.86, 1.08), ink, "pupil")
	local smile = face("Smile", Vector3.new(0.78, 0.14, 0.1), CFrame.new(0, 4.42, 1.04), ink, "smile")
	local pole = face("Antenna", Vector3.new(0.16, 0.7, 0.16), CFrame.new(0, 5.85, 0), dark, "antenna")
	local ball = face("AntennaBall", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 6.42, 0), yellow, "antennaBall")
	ball.Shape = Enum.PartType.Ball

	for _, extra in ipairs({ eyeL, eyeR, pupilL, pupilR, smile, pole, ball }) do
		extra.Massless = true
		weld(head, extra)
	end

	joint("RootJoint", hrp, torso)
	joint("Neck", torso, head)
	joint("Left Shoulder", torso, leftArm)
	joint("Right Shoulder", torso, rightArm)
	joint("Left Hip", torso, leftLeg)
	joint("Right Hip", torso, rightLeg)

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			child.Anchored = false
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = Course.HIP
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Rules.JUMP_HEIGHT
	humanoid.WalkSpeed = 0
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = true
	humanoid.MaxSlopeAngle = 40
	humanoid.AutomaticScalingEnabled = false
	pcall(function()
		humanoid.AutoJumpEnabled = false
	end)
	for _, stateName in ipairs({ "FallingDown", "Ragdoll", "Climbing", "Swimming" }) do
		local state = (Enum.HumanoidStateType :: any)[stateName]
		if state then
			humanoid:SetStateEnabled(state, false)
		end
	end
	humanoid.Parent = model
	model.PrimaryPart = hrp
	model.Parent = StarterPlayer

	pcall(function()
		(StarterPlayer :: any).AutoJumpEnabled = false
	end)
end

return RobotFactory
