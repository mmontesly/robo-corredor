-- Corrida no servidor. O cliente só pede apelido, pronto, início, posto e pulo.
-- Posição, bateria, óleo, engrenagem, posto, chegada e pódio são decididos aqui.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Course = require(Shared:WaitForChild("Course"))
local Rules = require(Shared:WaitForChild("Rules"))

local RaceService = {}

local started = false
local records = {}
local joinOrder = {}
local diedConn = {}
local charConn = {}
local pads = nil
local boxes = nil
local clearPowers

local state = {
	phase = "lobby",
	roundId = 0,
	hostUserId = 0,
	countdownEnd = 0,
	raceStart = 0,
	raceStartServer = 0,
	firstFinishAt = nil,
	podiumUntil = 0,
	notice = "",
	noticeUntil = 0,
	rockets = {},
	oils = {},
	wins = {},
	dirty = true,
	acc = 0,
}

local remotes
local pushAccum = 0

local function pose(x, y, z, yaw)
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
end

local function humanoidOf(player)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function setNotice(text)
	state.notice = text
	state.noticeUntil = os.clock() + 4
	state.dirty = true
end

local function updateHost()
	local host = 0
	for _, userId in ipairs(joinOrder) do
		if Players:GetPlayerByUserId(userId) then
			host = userId
			break
		end
	end
	state.hostUserId = host
	ReplicatedStorage:SetAttribute("HostUserId", host)
end

local function publishPhase()
	ReplicatedStorage:SetAttribute("Phase", state.phase)
	ReplicatedStorage:SetAttribute("RoundId", state.roundId)
	ReplicatedStorage:SetAttribute("CountdownEnd", state.countdownEnd)
	ReplicatedStorage:SetAttribute("RaceStartServer", state.raceStartServer)
	ReplicatedStorage:SetAttribute("HostUserId", state.hostUserId)
end

local function paint(player, record)
	local char = player.Character
	if not char then
		return
	end
	local tint = Config.COLORS[record.colorIndex]
	local body = tint and Config.toColor3(tint) or Color3.fromRGB(76, 201, 240)
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("Role") == "body" then
			desc.Color = body
		end
	end
	local head = char:FindFirstChild("Head")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = record.nick
		hum.UseJumpPower = false
		hum.JumpHeight = Rules.JUMP_HEIGHT
		hum.AutoRotate = true
		pcall(function()
			hum.AutoJumpEnabled = false
		end)
	end
	if not head then
		return
	end
	local existing = head:FindFirstChild("NickTag")
	if existing then
		existing:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NickTag"
	billboard.Size = UDim2.fromOffset(88, 16)
	billboard.StudsOffset = Vector3.new(0, 1.7, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 180
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextScaled = false
	label.Text = record.nick
	label.TextColor3 = body
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard
end

local function syncStats(player, record)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local bat = Instance.new("IntValue")
		bat.Name = "Baterias"
		bat.Parent = folder
		local posto = Instance.new("IntValue")
		posto.Name = "Posto"
		posto.Parent = folder
		local lugar = Instance.new("IntValue")
		lugar.Name = "Lugar"
		lugar.Parent = folder
		folder.Parent = player
	end
	folder.Baterias.Value = record.batteries or 0
	folder.Posto.Value = record.checkpoint or 0
	folder.Lugar.Value = record.place or 0
end

local function ensureBoostFx(hrp)
	local existing = hrp:FindFirstChild("NodexTurbo")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "NodexTurbo"
	local back = Instance.new("Attachment")
	back.Name = "TurboBack"
	back.Position = Vector3.new(0, 0.35, 0.55)
	back.Parent = hrp
	local tail = Instance.new("Attachment")
	tail.Name = "TurboTail"
	tail.Position = Vector3.new(0, 0.15, 1.7)
	tail.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "TurboTrail"
	trail.Attachment0 = back
	trail.Attachment1 = tail
	trail.Lifetime = 0.28
	trail.MinLength = 0.04
	trail.FaceCamera = true
	trail.LightEmission = 0.55
	trail.LightInfluence = 0.15
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 214, 70), Color3.fromRGB(76, 201, 240))
	trail.Enabled = false
	trail.Parent = hrp
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "TurboSparks"
	sparks.Rate = 42
	sparks.Lifetime = NumberRange.new(0.16, 0.3)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(14, 14)
	sparks.EmissionDirection = Enum.NormalId.Back
	sparks.Drag = 1.5
	sparks.LightEmission = 0.65
	sparks.LightInfluence = 0.1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 248, 210), Color3.fromRGB(255, 190, 11))
	sparks.Enabled = false
	sparks.Parent = back
	folder.Parent = hrp
	return folder
end

local function setBoostVisual(hrp, on)
	local folder = ensureBoostFx(hrp)
	local trail = hrp:FindFirstChild("TurboTrail")
	local back = hrp:FindFirstChild("TurboBack")
	local sparks = back and back:FindFirstChild("TurboSparks")
	if trail and trail:IsA("Trail") then
		trail.Enabled = on
	end
	if sparks and sparks:IsA("ParticleEmitter") then
		sparks.Enabled = on
		if not on then
			sparks:Clear()
		end
	end
	folder:SetAttribute("On", on == true)
end

local function syncAttributes(player, record, speed)
	local racing = state.phase == "race" and record.inRound and not record.gone and not record.finished
	local turboLeft = math.max(0, (record.turboUntil or 0) - os.clock())
	player:SetAttribute("InRace", racing)
	player:SetAttribute("Finished", record.finished == true)
	player:SetAttribute("Spectating", record.spectating == true or (state.phase ~= "lobby" and not record.inRound))
	player:SetAttribute("MoveSpeed", speed)
	player:SetAttribute("TurboLeft", turboLeft)
	player:SetAttribute("Checkpoint", record.checkpoint or 0)
	player:SetAttribute("Nick", record.nick)
	player:SetAttribute("Slot", record.colorIndex)
	player:SetAttribute("Ready", record.ready == true)
	local hrp, hum = humanoidOf(player)
	if hrp then
		local alive = hum ~= nil and hum.Health > 0
		setBoostVisual(hrp, Rules.boostVisible(turboLeft, alive, racing))
	end
end

local function teleport(player, x, y, z, yaw, anchored)
	local hrp, hum = humanoidOf(player)
	if not hrp or not hum then
		return
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hum.PlatformStand = false
	hrp.CFrame = pose(x, y, z, yaw)
	hrp.Anchored = anchored
	if anchored then
		hum.WalkSpeed = 0
	end
end

local function bindSpawn(player, record)
	if not pads then
		return
	end
	local pad = pads.lobby
	if state.phase == "countdown" and record.inRound then
		pad = pads.track[0]
	elseif state.phase == "race" and record.inRound and not record.finished and not record.gone then
		pad = pads.track[record.checkpoint] or pads.track[0]
	end
	player.RespawnLocation = pad
end

local function placeForPhase(player, record)
	local x, y, z, yaw
	local anchored = false
	if state.phase == "countdown" and record.inRound then
		x, y, z, yaw = Course.slotPose(record.slot)
		anchored = true
	elseif state.phase == "race" and record.inRound and not record.gone then
		if record.finished then
			x, y, z, yaw = Course.finishHoldPose(record.colorIndex, record.slot)
			anchored = true
		else
			return
		end
	elseif state.phase == "podium" and record.inRound and not record.gone then
		local rank = record.place or record.slot
		x, y, z, yaw = Course.podiumPose(rank, record.slot)
		anchored = true
	else
		x, y, z, yaw = Course.lobbyPose(record.slot)
		anchored = false
	end
	teleport(player, x, y, z, yaw, anchored)
	bindSpawn(player, record)
end

local function freeJoin(userId)
	local nextOrder = {}
	for _, id in ipairs(joinOrder) do
		if id ~= userId then
			table.insert(nextOrder, id)
		end
	end
	joinOrder = nextOrder
end

local function lowestSlot(): number?
	local used = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local record = records[player.UserId]
		if record then
			used[record.slot] = true
		end
	end
	for slot = 1, Rules.MAX_PLAYERS do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function freshRoundFields(record)
	record.ready = false
	record.finished = false
	record.dnf = false
	record.gone = false
	record.time = nil
	record.batteries = 0
	record.checkpoint = 0
	record.hit = {}
	record.collected = {}
	record.slowUntil = 0
	record.turboUntil = 0
	record.place = nil
	record.parked = false
	record.lastReset = 0
	record.powerReadyAt = 0
	record.tumbleUntil = 0
	record.x = Course.SPAWN_X
end

local function ensureWin(record)
	local entry = state.wins[record.userId]
	if not entry then
		entry = { count = 0, nick = record.nick, colorIndex = record.colorIndex }
		state.wins[record.userId] = entry
	end
	entry.nick = record.nick
	entry.colorIndex = record.colorIndex
	return entry
end

local function resultRows()
	local rows = {}
	for userId, record in pairs(records) do
		if record.inRound then
			table.insert(rows, {
				id = userId,
				finished = record.finished == true,
				dnf = record.dnf == true,
				gone = record.gone == true,
				time = record.time,
				slot = record.colorIndex,
				nick = record.nick,
				batteries = record.batteries,
				colorIndex = record.colorIndex,
				checkpoint = record.checkpoint,
				x = record.x or 0,
			})
		end
	end
	return rows
end

local function recomputePlaces()
	local rows = {}
	for userId, record in pairs(records) do
		if record.inRound and not record.gone then
			table.insert(rows, {
				id = userId,
				finished = record.finished == true,
				time = record.time,
				x = record.x or 0,
				slot = record.colorIndex,
				gone = false,
			})
		end
	end
	for userId, record in pairs(records) do
		if record.inRound and not record.gone then
			record.place = Rules.placeOf(userId, rows)
		end
	end
end

local function snapshotFor(player, now)
	local you = records[player.UserId]
	local speed = Rules.LOBBY_SPEED
	if you and state.phase == "race" then
		speed = Rules.currentSpeed(now, you.slowUntil or 0, you.turboUntil or 0)
	end
	local players = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local record = records[other.UserId]
		if record then
			table.insert(players, {
				userId = other.UserId,
				nick = record.nick,
				colorIndex = record.colorIndex,
				ready = record.ready == true,
				spectating = record.spectating == true,
				inRound = record.inRound == true,
				finished = record.finished == true,
				place = record.place,
				batteries = record.batteries,
			})
		end
	end
	table.sort(players, function(a, b)
		return a.colorIndex < b.colorIndex
	end)
	local results = resultRows()
	local ordered
	if state.phase == "podium" then
		ordered = Rules.podium(results)
	else
		ordered = results
		table.sort(ordered, function(a, b)
			return (a.place or 99) < (b.place or 99)
		end)
	end
	local wins = {}
	for userId, entry in pairs(state.wins) do
		if entry.count > 0 then
			table.insert(wins, {
				userId = userId,
				nick = entry.nick,
				colorIndex = entry.colorIndex,
				count = entry.count,
			})
		end
	end
	table.sort(wins, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.nick < b.nick
	end)
	local youPack = nil
	if you then
		youPack = {
			userId = player.UserId,
			nick = you.nick,
			colorIndex = you.colorIndex,
			ready = you.ready == true,
			spectating = you.spectating == true or (state.phase ~= "lobby" and not you.inRound),
			inRound = you.inRound == true,
			finished = you.finished == true,
			dnf = you.dnf == true,
			time = you.time,
			batteries = you.batteries,
			checkpoint = you.checkpoint,
			place = you.place,
			collected = you.collected,
			slowLeft = math.max(0, (you.slowUntil or 0) - now),
			turboLeft = math.max(0, (you.turboUntil or 0) - now),
			powerLeft = math.max(0, (you.powerReadyAt or 0) - now),
			isHost = player.UserId == state.hostUserId,
			x = you.x or 0,
		}
	end
	return {
		phase = state.phase,
		roundId = state.roundId,
		hostUserId = state.hostUserId,
		countdownEnd = state.countdownEnd,
		raceStartServer = state.raceStartServer,
		notice = (state.noticeUntil > now) and state.notice or "",
		you = youPack,
		players = players,
		results = ordered,
		wins = wins,
		finishX = Course.FINISH_X,
		startX = Course.START_X,
		checkpointCount = Course.checkpointCount(),
		maxPlayers = Rules.MAX_PLAYERS,
		elapsed = (state.phase == "race" or state.phase == "podium") and math.max(0, now - state.raceStart) or 0,
	}
end

local function broadcast(now)
	if not remotes then
		return
	end
	now = now or os.clock()
	if state.phase == "race" then
		recomputePlaces()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local payload = snapshotFor(player, now)
		pcall(function()
			remotes.State:FireClient(player, payload)
		end)
	end
	state.dirty = false
end

local function confetti()
	local folder = workspace:FindFirstChild("NodexConfetti")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "NodexConfetti"
	folder.Parent = workspace
	local rng = Random.new()
	for i = 1, 28 do
		local tint = Config.CONFETTI[(i % #Config.CONFETTI) + 1]
		local piece = Instance.new("Part")
		piece.Name = "Confetti"
		piece.Size = Vector3.new(0.6, 0.35, 0.2)
		piece.Color = Config.toColor3(tint)
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.CFrame = CFrame.new(-74 + rng:NextNumber(-8, 8), Course.FLOOR_TOP + 14 + rng:NextNumber(0, 4), rng:NextNumber(-3, 3))
		piece.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(4, 16), rng:NextNumber(-8, 8))
		piece.Parent = folder
	end
	Debris:AddItem(folder, 6)
end

local function returnToLobby()
	if state.phase == "lobby" then
		return
	end
	state.phase = "lobby"
	clearPowers()
	state.firstFinishAt = nil
	state.countdownEnd = 0
	state.raceStartServer = 0
	local stale = {}
	for userId, record in pairs(records) do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			table.insert(stale, userId)
		else
			freshRoundFields(record)
			record.inRound = false
			record.spectating = false
			record.ready = false
			local x, y, z, yaw = Course.lobbyPose(record.slot)
			teleport(player, x, y, z, yaw, false)
			bindSpawn(player, record)
			local hrp, hum = humanoidOf(player)
			if hum then
				hum.AutoRotate = true
				hum.WalkSpeed = Rules.LOBBY_SPEED
			end
			local align = hrp and hrp:FindFirstChild("FaceTrackAlign")
			if align and align:IsA("AlignOrientation") then
				align.Enabled = false
			end
			syncAttributes(player, record, Rules.LOBBY_SPEED)
			syncStats(player, record)
		end
	end
	for _, userId in ipairs(stale) do
		records[userId] = nil
	end
	publishPhase()
	state.dirty = true
	broadcast()
	print("[Nodex] De volta ao lobby.")
end

local function park(player, record)
	record.parked = true
	record.slowUntil = 0
	record.turboUntil = 0
	record.tumbleUntil = 0
	local x, y, z, yaw = Course.finishHoldPose(record.colorIndex, record.slot)
	teleport(player, x, y, z, yaw, true)
	syncAttributes(player, record, 0)
end

local function closeRound(now, asDnf)
	if state.phase ~= "race" and state.phase ~= "countdown" then
		return
	end
	if asDnf then
		for _, record in pairs(records) do
			if record.inRound and not record.finished and not record.gone and not record.dnf then
				record.dnf = true
			end
		end
		setNotice("Tempo esgotado!")
	end
	local ordered = Rules.podium(resultRows())
	for index, row in ipairs(ordered) do
		local record = records[row.id]
		if record then
			record.place = index
		end
	end
	if ordered[1] and ordered[1].finished then
		local winner = records[ordered[1].id]
		if winner then
			local entry = ensureWin(winner)
			entry.count += 1
		end
	end
	state.phase = "podium"
	state.podiumUntil = now + Rules.PODIUM_HOLD
	for _, player in ipairs(Players:GetPlayers()) do
		local record = records[player.UserId]
		if record and record.inRound and not record.gone then
			local rank = record.place or record.slot
			local x, y, z, yaw = Course.podiumPose(rank, record.slot)
			teleport(player, x, y, z, yaw, true)
			syncAttributes(player, record, 0)
			syncStats(player, record)
		end
	end
	confetti()
	publishPhase()
	state.dirty = true
	broadcast(now)
	print("[Nodex] Pódio da rodada " .. tostring(state.roundId) .. ".")
end

local function roundStates()
	local list = {}
	for _, record in pairs(records) do
		if record.inRound then
			local name = "racing"
			if record.gone then
				name = "gone"
			elseif record.finished then
				name = "finished"
			elseif record.dnf then
				name = "dnf"
			end
			table.insert(list, name)
		end
	end
	return list
end

local function considerRoundEnd(now)
	if state.phase ~= "race" then
		return
	end
	local status = Rules.roundStatus(now, state.firstFinishAt, roundStates())
	if status == "dnf_rest" then
		closeRound(now, true)
	elseif status == "done" then
		closeRound(now, false)
	end
end

local function beginCountdown()
	if state.phase ~= "lobby" then
		return
	end
	local roster = Players:GetPlayers()
	if #roster < 1 then
		return
	end
	state.phase = "countdown"
	state.roundId += 1
	state.firstFinishAt = nil
	state.countdownEnd = Workspace:GetServerTimeNow() + Rules.COUNTDOWN_SECONDS
	state.notice = ""
	state.noticeUntil = 0
	clearPowers()
	for _, player in ipairs(roster) do
		local record = records[player.UserId]
		if record then
			freshRoundFields(record)
			record.inRound = true
			record.spectating = false
			record.ready = false
			local x, y, z, yaw = Course.slotPose(record.slot)
			record.x = x
			record.allowedX = x + Rules.ALLOWANCE_AHEAD
			teleport(player, x, y, z, yaw, true)
			bindSpawn(player, record)
			syncAttributes(player, record, 0)
			syncStats(player, record)
			paint(player, record)
		end
	end
	publishPhase()
	state.dirty = true
	broadcast()
	print("[Nodex] Contagem da rodada " .. tostring(state.roundId) .. ".")
end

local function startRace(now)
	state.phase = "race"
	state.raceStart = now
	state.raceStartServer = Workspace:GetServerTimeNow()
	state.countdownEnd = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local record = records[player.UserId]
		if record and record.inRound then
			local hrp, hum = humanoidOf(player)
			local x = hrp and hrp.Position.X or select(1, Course.slotPose(record.slot))
			record.allowedX = x + Rules.ALLOWANCE_AHEAD
			record.x = x
			syncAttributes(player, record, Rules.BASE_SPEED)
			bindSpawn(player, record)
			if hum then
				hum.WalkSpeed = Rules.BASE_SPEED
				hum.UseJumpPower = false
				hum.JumpHeight = Rules.JUMP_HEIGHT
				hum.AutoRotate = false
			end
			if hrp then
				local align = hrp:FindFirstChild("FaceTrackAlign")
				if align and align:IsA("AlignOrientation") then
					align.Enabled = true
				end
			end
			record.powerReadyAt = now + Rules.POWER_ARM
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.Anchored = false
			end
			if hum then
				hum.PlatformStand = false
			end
		end
	end
	publishPhase()
	state.dirty = true
	broadcast(now)
	print("[Nodex] Valendo!")
end

local function feetOf(hrp, hum)
	local feetY = hrp.Position.Y - Course.HIP
	local lowGround = hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y < Course.FLOOR_TOP + Course.HIP + 1.25
	if lowGround then
		feetY = math.min(feetY, Course.FLOOR_TOP + 0.15)
	end
	return feetY
end

local function rewindX(hrp, x)
	local pos = hrp.Position
	hrp.CFrame = CFrame.new(x, pos.Y, pos.Z) * hrp.CFrame.Rotation
	local velocity = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, velocity.Z)
end

local function applySlow(record, now)
	record.slowUntil = now + Rules.SLOW_TIME
end

local function faceAlign(hrp)
	local align = hrp:FindFirstChild("FaceTrackAlign")
	if align and align:IsA("AlignOrientation") then
		return align
	end
	return nil
end

local function endTumble(player, record, faceTrack)
	record.tumbleUntil = 0
	local hrp, hum = humanoidOf(player)
	if not hrp or not hum then
		return
	end
	hrp.AssemblyAngularVelocity = Vector3.zero
	hum.PlatformStand = false
	if faceTrack and hum.Health > 0 then
		-- Um quadro só, na posição atual. Não trava a altura durante a corrida.
		-- Sem isso o Humanoid entra em GettingUp e o robô soldado fica parado.
		local pos = hrp.Position
		hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, Rules.TRACK_YAW, 0)
		local vel = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(math.max(hum.WalkSpeed, 0), vel.Y, 0)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
	local align = faceAlign(hrp)
	if align then
		align.Enabled = faceTrack
	end
end

local function beginTumble(player, record, now, kind)
	local duration = Rules.tumbleDuration(kind)
	if duration <= 0 or not Rules.canBeginTumble(now, record.tumbleUntil or 0) then
		return
	end
	local hrp, hum = humanoidOf(player)
	if not hrp or not hum then
		return
	end
	record.tumbleUntil = now + duration
	local align = faceAlign(hrp)
	if align then
		align.Enabled = false
	end
	hum.PlatformStand = true
	-- Uma volta só. Não reaplicar no quadro seguinte.
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, Rules.tumbleSpinFor(duration))
end

local function applyOilSlip(player, record, now)
	record.slowUntil = Rules.oilSlowUntil(now)
	beginTumble(player, record, now, "oil")
end

local function stepRacer(player, record, now, step)
	local hrp, hum = humanoidOf(player)
	if not hrp or not hum then
		return
	end
	if record.finished then
		if not record.parked then
			park(player, record)
		end
		record.x = hrp.Position.X
		return
	end

	local speed = Rules.currentSpeed(now, record.slowUntil, record.turboUntil)
	local px = hrp.Position.X
	local py = hrp.Position.Y
	local pz = hrp.Position.Z

	record.allowedX += (speed + Rules.ALLOWANCE_SLACK) * step
	if record.allowedX > px + Rules.ALLOWANCE_AHEAD then
		record.allowedX = px + Rules.ALLOWANCE_AHEAD
	end
	if px > record.allowedX + Rules.REWIND_PAD then
		rewindX(hrp, record.allowedX)
		px = record.allowedX
	end

	if py < Course.FLOOR_TOP - 10 then
		local x, y, z, yaw = Course.respawnPose(record.slot, record.checkpoint)
		record.allowedX = x
		record.x = x
		record.tumbleUntil = 0
		teleport(player, x, y, z, yaw, false)
		bindSpawn(player, record)
		syncAttributes(player, record, speed)
		return
	end

	if math.abs(pz) > Course.LANE_HALF + 2 then
		local nz = math.clamp(pz, -Course.LANE_HALF + 1, Course.LANE_HALF - 1)
		hrp.CFrame = CFrame.new(px, py, nz) * hrp.CFrame.Rotation
		pz = nz
	end

	local feetY = feetOf(hrp, hum)
	local hrpY = hrp.Position.Y
	for _, box in ipairs(boxes) do
		if not record.hit[box.id] then
			local hit = false
			if box.kind == "gear" and Course.penalizeGear(feetY, px, pz, box) then
				hit = true
				applySlow(record, now)
				beginTumble(player, record, now, "gear")
			elseif box.kind == "oil" and Course.penalizeOil(feetY, px, pz, box, false) and Rules.canSlipPuddle(false, true, now, record.tumbleUntil or 0) then
				hit = true
				applyOilSlip(player, record, now)
			elseif box.kind == "battery" and Course.collectBattery(hrpY, px, pz, box) then
				hit = true
				record.batteries += 1
				record.turboUntil = now + Rules.TURBO_TIME
				table.insert(record.collected, box.id)
				state.dirty = true
			end
			if hit then
				record.hit[box.id] = true
				state.dirty = true
			end
		end
	end

	local cp = Course.clearedCheckpoint(px, record.checkpoint)
	if cp then
		record.checkpoint = cp.index
		bindSpawn(player, record)
		state.dirty = true
	end

	if Course.canFinish(px, record.checkpoint) then
		record.finished = true
		record.time = now - state.raceStart
		record.x = px
		if not state.firstFinishAt then
			state.firstFinishAt = now
		end
		park(player, record)
		syncStats(player, record)
		state.dirty = true
		setNotice(record.nick .. " chegou!")
		return
	end

	local recovering = (record.tumbleUntil or 0) ~= 0 and not Rules.tumbleActive(now, record.tumbleUntil)
	speed = Rules.currentSpeed(now, record.slowUntil, record.turboUntil)
	hum.WalkSpeed = speed
	if recovering then
		endTumble(player, record, true)
	end
	local tumbling = Rules.tumbleActive(now, record.tumbleUntil or 0)
	hum.AutoRotate = false
	local align = faceAlign(hrp)
	if align and align.Enabled == tumbling then
		align.Enabled = not tumbling
	end
	if hum.PlatformStand ~= tumbling then
		hum.PlatformStand = tumbling
	end
	hum.JumpHeight = Rules.JUMP_HEIGHT
	hum.UseJumpPower = false
	record.x = hrp.Position.X
	syncAttributes(player, record, speed)
end

local function containLobby(player, record)
	local hrp, hum = humanoidOf(player)
	if not hrp or not hum then
		return
	end
	local px = hrp.Position.X
	local py = hrp.Position.Y
	local pz = hrp.Position.Z
	local outside = px > Course.LOBBY_MAX_X + 2 or px < Course.LOBBY_MIN_X - 4 or math.abs(pz) > Course.LOBBY_HALF_Z + 4 or py < Course.FLOOR_TOP - 8
	if outside then
		local x, y, z, yaw = Course.lobbyPose(record.slot)
		teleport(player, x, y, z, yaw, false)
	end
	if state.phase == "lobby" then
		hum.AutoRotate = true
		local align = hrp:FindFirstChild("FaceTrackAlign")
		if align and align:IsA("AlignOrientation") then
			align.Enabled = false
		end
		hum.WalkSpeed = Rules.LOBBY_SPEED
		syncAttributes(player, record, Rules.LOBBY_SPEED)
	end
end

local powerSerial = 0

local function powersFolder()
	local folder = Workspace:FindFirstChild("NodexPowers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NodexPowers"
		folder.Parent = Workspace
	end
	return folder
end

clearPowers = function()
	for _, rocket in ipairs(state.rockets) do
		if rocket.part then
			rocket.part:Destroy()
		end
	end
	for _, puddle in ipairs(state.oils) do
		if puddle.part then
			puddle.part:Destroy()
		end
	end
	table.clear(state.rockets)
	table.clear(state.oils)
	local folder = Workspace:FindFirstChild("NodexPowers")
	if folder then
		folder:Destroy()
	end
end

local function dropOldest(list)
	local old = table.remove(list, 1)
	if old and old.part then
		old.part:Destroy()
	end
end

local function racingRows()
	local rows = {}
	for userId, record in pairs(records) do
		table.insert(rows, {
			id = userId,
			x = record.x or 0,
			racing = record.inRound == true and record.finished ~= true and record.gone ~= true and record.dnf ~= true,
		})
	end
	return rows
end

local function spawnRocket(record)
	while #state.rockets >= Rules.MAX_POWERS do
		dropOldest(state.rockets)
	end
	powerSerial += 1
	local origin = (record.x or 0) + 2.3
	local targetId = Rules.nearestAhead(racingRows(), record.userId, Rules.ROCKET_RANGE)
	local body = Instance.new("Part")
	body.Name = "Foguetinho"
	body.Size = Vector3.new(1.6, 0.45, 0.45)
	body.Color = Color3.fromRGB(251, 86, 7)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CFrame = CFrame.new(origin, Course.FLOOR_TOP + 3.2, 0)
	body.Parent = powersFolder()
	table.insert(state.rockets, {
		id = powerSerial,
		ownerId = record.userId,
		targetId = targetId,
		x = origin,
		life = Rules.ROCKET_LIFE,
		part = body,
	})
end

local function spawnOil(record)
	while #state.oils >= Rules.MAX_POWERS do
		dropOldest(state.oils)
	end
	powerSerial += 1
	local origin = (record.x or 0) - Rules.OIL_BEHIND
	local puddle = Instance.new("Part")
	puddle.Name = "OleoSolto"
	puddle.Size = Vector3.new(Rules.OIL_HALF * 2, 0.22, Course.LANE_HALF * 2 - 1)
	puddle.Color = Color3.fromRGB(61, 52, 139)
	puddle.Material = Enum.Material.SmoothPlastic
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanTouch = false
	puddle.CFrame = CFrame.new(origin, Course.FLOOR_TOP + 0.2, 0)
	puddle.Parent = powersFolder()
	table.insert(state.oils, {
		id = powerSerial,
		ownerId = record.userId,
		x = origin,
		life = Rules.OIL_LIFE,
		hit = {},
		part = puddle,
	})
end

local function stepPowers(now, step)
	local index = 1
	while index <= #state.rockets do
		local rocket = state.rockets[index]
		rocket.x += Rules.ROCKET_SPEED * step
		rocket.life -= step
		local target = rocket.targetId and records[rocket.targetId]
		local remove = rocket.life <= 0 or rocket.x > Course.FINISH_X + 40
		if target then
			local racing = target.inRound == true and target.finished ~= true and target.gone ~= true
			if Rules.rocketReached(rocket.x, target.x or 0, rocket.ownerId, target.userId, racing) then
				applySlow(target, now)
				remove = true
			end
		end
		if rocket.part then
			rocket.part.CFrame = CFrame.new(rocket.x, Course.FLOOR_TOP + 3.2, 0)
		end
		if remove then
			if rocket.part then
				rocket.part:Destroy()
			end
			table.remove(state.rockets, index)
		else
			index += 1
		end
	end
	index = 1
	while index <= #state.oils do
		local puddle = state.oils[index]
		puddle.life -= step
		for userId, record in pairs(records) do
			if record.inRound and not record.finished and not record.gone then
				local player = Players:GetPlayerByUserId(userId)
				local hrp, hum = player and humanoidOf(player)
				local feetAbove = 0
				if hrp and hum then
					feetAbove = feetOf(hrp, hum) - Course.FLOOR_TOP
				end
				local alreadySlip = puddle.hit[userId] == true
				if Rules.oilHits(puddle.x, Rules.OIL_HALF, record.x or 0, feetAbove, Rules.OIL_JUMP, puddle.ownerId, userId, alreadySlip) and Rules.canSlipPuddle(alreadySlip, true, now, record.tumbleUntil or 0) then
					puddle.hit[userId] = true
					local oilPlayer = Players:GetPlayerByUserId(userId)
					if oilPlayer then
						applyOilSlip(oilPlayer, record, now)
					end
				end
			end
		end
		if puddle.life <= 0 then
			if puddle.part then
				puddle.part:Destroy()
			end
			table.remove(state.oils, index)
		else
			index += 1
		end
	end
end

local function onHeartbeat(dt)
	local now = os.clock()
	local step = math.clamp(dt, 0, 0.2)
	if state.phase == "countdown" then
		if Workspace:GetServerTimeNow() >= state.countdownEnd then
			startRace(now)
		end
	elseif state.phase == "race" then
		for _, player in ipairs(Players:GetPlayers()) do
			local record = records[player.UserId]
			if record and record.inRound and not record.gone then
				stepRacer(player, record, now, step)
			elseif record then
				containLobby(player, record)
			end
		end
		stepPowers(now, step)
		considerRoundEnd(now)
	elseif state.phase == "podium" then
		if now >= state.podiumUntil then
			returnToLobby()
			return
		end
	else
		for _, player in ipairs(Players:GetPlayers()) do
			local record = records[player.UserId]
			if record then
				containLobby(player, record)
			end
		end
	end
	pushAccum += dt
	if state.dirty or pushAccum >= 0.2 then
		pushAccum = 0
		broadcast(now)
	end
end

local function allReady()
	local roster = Players:GetPlayers()
	if #roster < 1 then
		return false
	end
	for _, player in ipairs(roster) do
		local record = records[player.UserId]
		if not record or not record.ready then
			return false
		end
	end
	return true
end

local lastAction = {}

local function onAction(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.t
	if type(kind) ~= "string" then
		return
	end
	local now = os.clock()
	if kind ~= "hello" and lastAction[player.UserId] and now - lastAction[player.UserId] < 0.12 then
		return
	end
	lastAction[player.UserId] = now
	local record = records[player.UserId]
	if not record then
		return
	end
	if kind == "hello" then
		broadcast()
		return
	end
	if kind == "ready" and state.phase == "lobby" then
		if type(payload.v) ~= "boolean" then
			return
		end
		record.ready = payload.v
		syncAttributes(player, record, Rules.LOBBY_SPEED)
		state.dirty = true
		if allReady() then
			beginCountdown()
		else
			broadcast()
		end
		return
	end
	if kind == "start" and state.phase == "lobby" then
		if player.UserId ~= state.hostUserId then
			return
		end
		beginCountdown()
		return
	end
	if kind == "nick" and state.phase == "lobby" then
		if not Config.isNick(payload.v) then
			return
		end
		record.nick = payload.v
		ensureWin(record)
		paint(player, record)
		syncAttributes(player, record, Rules.LOBBY_SPEED)
		state.dirty = true
		broadcast()
		return
	end
	if kind == "return" and state.phase == "podium" then
		returnToLobby()
		return
	end
	if kind == "power" then
		if payload.v ~= "rocket" and payload.v ~= "oil" then
			return
		end
		if not Rules.canUsePower(state.phase, record.inRound == true, record.finished == true, record.gone == true, now, record.powerReadyAt or 0) then
			return
		end
		record.powerReadyAt = now + Rules.POWER_CD
		if payload.v == "rocket" then
			spawnRocket(record)
		else
			spawnOil(record)
		end
		state.dirty = true
		broadcast(now)
		return
	end
	if kind == "checkpoint_reset" and state.phase == "race" then
		if not record.inRound or record.finished or record.gone or record.spectating then
			return
		end
		if now - (record.lastReset or 0) < Rules.RESET_COOLDOWN then
			return
		end
		record.lastReset = now
		local x, y, z, yaw = Course.respawnPose(record.slot, record.checkpoint)
		record.allowedX = x
		record.x = x
		teleport(player, x, y, z, yaw, false)
		bindSpawn(player, record)
		state.dirty = true
		return
	end
end

local function hookCharacter(player, char)
	local record = records[player.UserId]
	if not record then
		return
	end
	local hum = char:WaitForChild("Humanoid", 5)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hum or not hrp or not player.Parent then
		return
	end
	if diedConn[player] then
		diedConn[player]:Disconnect()
	end
	diedConn[player] = hum.Died:Connect(function()
		record.tumbleUntil = 0
		record.turboUntil = 0
		hum.PlatformStand = false
		hrp.AssemblyAngularVelocity = Vector3.zero
		syncAttributes(player, record, 0)
		task.delay(0.6, function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
	paint(player, record)
	if state.phase == "race" and record.inRound and not record.gone and not record.finished then
		local x, y, z, yaw = Course.respawnPose(record.slot, record.checkpoint)
		record.allowedX = x
		record.x = x
		teleport(player, x, y, z, yaw, false)
	else
		placeForPhase(player, record)
	end
	bindSpawn(player, record)
	local speed = Rules.LOBBY_SPEED
	if state.phase == "race" and record.inRound and not record.finished then
		speed = Rules.currentSpeed(os.clock(), record.slowUntil or 0, record.turboUntil or 0)
	elseif state.phase ~= "lobby" then
		speed = 0
	end
	hum.WalkSpeed = speed
	syncAttributes(player, record, speed)
	syncStats(player, record)
end

local function onPlayer(player)
	if records[player.UserId] then
		return
	end
	local slot = lowestSlot()
	if not slot then
		player:Kick("A Fábrica comporta até 8 robôs.")
		return
	end
	local record = {
		userId = player.UserId,
		slot = slot,
		colorIndex = slot,
		nick = Config.NICKS[slot],
		ready = false,
		spectating = state.phase ~= "lobby",
		inRound = false,
		finished = false,
		dnf = false,
		gone = false,
		time = nil,
		batteries = 0,
		checkpoint = 0,
		hit = {},
		collected = {},
		slowUntil = 0,
		turboUntil = 0,
		allowedX = 0,
		x = 0,
		lastReset = 0,
		powerReadyAt = 0,
		tumbleUntil = 0,
		parked = false,
	}
	records[player.UserId] = record
	table.insert(joinOrder, player.UserId)
	ensureWin(record)
	updateHost()
	if charConn[player] then
		charConn[player]:Disconnect()
	end
	charConn[player] = player.CharacterAdded:Connect(function(char)
		hookCharacter(player, char)
	end)
	task.spawn(function()
		if not player.Parent then
			return
		end
		local current = player.Character
		if current == nil or current:FindFirstChild("Antenna", true) == nil then
			player:LoadCharacter()
		elseif current then
			hookCharacter(player, current)
		end
	end)
	state.dirty = true
	broadcast()
end

local function onLeave(player)
	local record = records[player.UserId]
	if charConn[player] then
		charConn[player]:Disconnect()
		charConn[player] = nil
	end
	if diedConn[player] then
		diedConn[player]:Disconnect()
		diedConn[player] = nil
	end
	lastAction[player.UserId] = nil
	freeJoin(player.UserId)
	if record then
		endTumble(player, record, false)
		if record.inRound and (state.phase == "race" or state.phase == "countdown") and not record.finished then
			record.gone = true
			record.spectating = false
			if state.phase == "countdown" then
				record.inRound = false
			end
			setNotice(record.nick .. " saiu")
		elseif state.phase == "lobby" or state.phase == "podium" then
			records[player.UserId] = nil
		end
	end
	updateHost()
	if state.phase == "countdown" then
		local still = 0
		for _, other in ipairs(Players:GetPlayers()) do
			local otherRecord = records[other.UserId]
			if otherRecord and otherRecord.inRound then
				still += 1
			end
		end
		if still < 1 then
			returnToLobby()
			return
		end
	end
	if state.phase == "race" then
		considerRoundEnd(os.clock())
	end
	state.dirty = true
	broadcast()
end

function RaceService.start(spawnPads)
	if started then
		return
	end
	started = true
	pads = spawnPads
	boxes = Course.boxes()

	local folder = ReplicatedStorage:FindFirstChild("NodexRemotes")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "NodexRemotes"
	folder.Parent = ReplicatedStorage
	local action = Instance.new("RemoteEvent")
	action.Name = "Action"
	action.Parent = folder
	local stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "State"
	stateRemote.Parent = folder
	remotes = { Action = action, State = stateRemote }

	action.OnServerEvent:Connect(onAction)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(onLeave)
	RunService.Heartbeat:Connect(onHeartbeat)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	publishPhase()
	print(string.format(
		"[Nodex] Robô Corredor — Fábrica pronta. Chegada em %d studs, %d postos. Até %d robôs; treino solo permitido.",
		Course.FINISH_X,
		Course.checkpointCount(),
		Rules.MAX_PLAYERS
	))
end

return RaceService
