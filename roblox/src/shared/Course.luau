-- Pista única da Fábrica, gerada por código (sem asset externo).
-- Os centros abaixo deixam pelo menos 20 studs entre as bordas dos obstáculos,
-- tempo para pousar e pular de novo a 22 studs/s com JumpHeight 8.5.

local Course = {}

Course.FLOOR_TOP = 4
Course.LANE_HALF = 8.5
Course.HIP = 3
Course.BODY_RADIUS = 1.5
Course.GEAR_DIAMETER = 3.6
Course.OIL_LENGTH = 9
Course.BATTERY_LENGTH = 5.2
Course.START_X = 0
Course.FINISH_X = 748
Course.SPAWN_X = -4
Course.TRACK_MIN_X = -40
Course.TRACK_END = 810
Course.LOBBY_MIN_X = -112
Course.LOBBY_MAX_X = -54
Course.LOBBY_HALF_Z = 16
Course.MIN_EDGE_GAP = 20
Course.RESPAWN_BACK = 12

Course.CHECKPOINTS = {
	{ index = 1, x = 152.7 },
	{ index = 2, x = 305.9 },
	{ index = 3, x = 460.3 },
	{ index = 4, x = 614.7 },
}

Course.OBSTACLES = {
	{ id = "g1", kind = "gear", x = 58.0 },
	{ id = "o1", kind = "oil", x = 90.5 },
	{ id = "b1", kind = "battery", x = 123.6, lift = "low" },
	{ id = "g2", kind = "gear", x = 181.2 },
	{ id = "o2", kind = "oil", x = 213.7 },
	{ id = "b2", kind = "battery", x = 246.8, lift = "high" },
	{ id = "g3", kind = "gear", x = 277.4 },
	{ id = "b6", kind = "battery", x = 335.0, lift = "low" },
	{ id = "g4", kind = "gear", x = 365.6 },
	{ id = "o3", kind = "oil", x = 398.1 },
	{ id = "b3", kind = "battery", x = 431.2, lift = "high" },
	{ id = "o4", kind = "oil", x = 491.3 },
	{ id = "g5", kind = "gear", x = 523.8 },
	{ id = "b7", kind = "battery", x = 554.4, lift = "low" },
	{ id = "b4", kind = "battery", x = 585.6, lift = "high" },
	{ id = "g6", kind = "gear", x = 643.2 },
	{ id = "o5", kind = "oil", x = 675.7 },
	{ id = "b5", kind = "battery", x = 708.8, lift = "low" },
}

export type Box = {
	id: string,
	kind: string,
	x: number,
	y: number,
	z: number,
	hx: number,
	hy: number,
	hz: number,
	lift: string?,
	feetCut: number?,
}

function Course.checkpointCount(): number
	return #Course.CHECKPOINTS
end

local function halfX(kind: string): number
	if kind == "gear" then
		return Course.GEAR_DIAMETER / 2
	elseif kind == "oil" then
		return Course.OIL_LENGTH / 2
	elseif kind == "battery" then
		return Course.BATTERY_LENGTH / 2
	end
	return 1
end

function Course.boxes(): { Box }
	local list = {}
	for _, ob in ipairs(Course.OBSTACLES) do
		local hx = halfX(ob.kind)
		local box: Box = {
			id = ob.id,
			kind = ob.kind,
			x = ob.x,
			z = 0,
			hx = hx,
			hy = 1,
			hz = Course.LANE_HALF,
			y = Course.FLOOR_TOP,
			lift = ob.lift,
		}
		if ob.kind == "gear" then
			box.y = Course.FLOOR_TOP + Course.GEAR_DIAMETER / 2
			box.hy = Course.GEAR_DIAMETER / 2
			box.feetCut = Course.FLOOR_TOP + Course.GEAR_DIAMETER - 0.55
		elseif ob.kind == "oil" then
			box.y = Course.FLOOR_TOP + 0.25
			box.hy = 0.4
			box.feetCut = Course.FLOOR_TOP + 2.15
		else
			local high = ob.lift == "high"
			box.y = Course.FLOOR_TOP + (high and 8.35 or 3.15)
			box.hy = high and 1.25 or 1.45
		end
		table.insert(list, box)
	end
	return list
end

function Course.inLane(pz: number): boolean
	return math.abs(pz) <= Course.LANE_HALF + 1
end

function Course.penalizeGear(feetY: number, px: number, pz: number, box: Box): boolean
	if box.kind ~= "gear" or box.feetCut == nil then
		return false
	end
	if not Course.inLane(pz) then
		return false
	end
	if math.abs(px - box.x) > box.hx + Course.BODY_RADIUS + 0.35 then
		return false
	end
	return feetY < box.feetCut
end

function Course.penalizeOil(feetY: number, px: number, pz: number, box: Box, grounded: boolean?): boolean
	if box.kind ~= "oil" or box.feetCut == nil then
		return false
	end
	if not Course.inLane(pz) then
		return false
	end
	if math.abs(px - box.x) > box.hx + 0.4 then
		return false
	end
	if feetY < box.feetCut then
		return true
	end
	return grounded == true and feetY < box.feetCut + 0.4
end

function Course.collectBattery(hrpY: number, px: number, pz: number, box: Box): boolean
	if box.kind ~= "battery" then
		return false
	end
	if not Course.inLane(pz) then
		return false
	end
	if math.abs(px - box.x) > box.hx + Course.BODY_RADIUS then
		return false
	end
	return math.abs(hrpY - box.y) <= box.hy + 1.35
end

function Course.clearedCheckpoint(px: number, lastIndex: number)
	local nextIndex = lastIndex + 1
	local cp = Course.CHECKPOINTS[nextIndex]
	if cp and cp.index == nextIndex and px >= cp.x then
		return cp
	end
	return nil
end

function Course.canFinish(px: number, checkpointIndex: number): boolean
	return checkpointIndex >= #Course.CHECKPOINTS and px >= Course.FINISH_X
end

function Course.slotPose(slot: number): (number, number, number, number)
	local x = Course.SPAWN_X - (slot - 1) * 3.5
	local z = (slot % 2 == 0) and 1.8 or -1.8
	local y = Course.FLOOR_TOP + Course.HIP
	return x, y, z, -math.pi / 2
end

function Course.lobbyPose(slot: number): (number, number, number, number)
	local x = -70 - (slot - 1) * 3.2
	local z = (slot % 2 == 0) and 5 or -5
	local y = Course.FLOOR_TOP + Course.HIP
	return x, y, z, -math.pi / 2
end

function Course.respawnPose(slot: number, checkpointIndex: number): (number, number, number, number)
	local _, _, z, yaw = Course.slotPose(slot)
	local y = Course.FLOOR_TOP + Course.HIP
	if checkpointIndex <= 0 then
		local x = select(1, Course.slotPose(slot))
		return x, y, z, yaw
	end
	local cp = Course.CHECKPOINTS[checkpointIndex]
	return cp.x - Course.RESPAWN_BACK, y, z, yaw
end

function Course.finishHoldPose(orderIndex: number, slot: number): (number, number, number, number)
	local x = Course.FINISH_X + 12 + (orderIndex - 1) * 4.5
	local z = (slot % 2 == 0) and 2.2 or -2.2
	local y = Course.FLOOR_TOP + Course.HIP
	return x, y, z, -math.pi / 2
end

function Course.podiumPose(rank: number, _slot: number): (number, number, number, number, number)
	local yaw = -math.pi / 2
	local x, z, extra
	if rank == 1 then
		x, z, extra = -74, 0, 3.2
	elseif rank == 2 then
		x, z, extra = -86, 0, 2.0
	elseif rank == 3 then
		x, z, extra = -64, 0, 1.15
	else
		local i = math.max(0, rank - 4)
		x = -102
		z = -8 + i * 3.2
		extra = 0
	end
	local y = Course.FLOOR_TOP + extra + Course.HIP
	return x, y, z, yaw, extra
end

local function inside(x: number, left: number, right: number): boolean
	return x >= left and x <= right
end

function Course.validate(): (boolean, { string })
	local errors = {}
	local function bad(msg: string)
		table.insert(errors, msg)
	end

	local ids = {}
	local counts = { gear = 0, oil = 0, battery = 0 }
	for _, ob in ipairs(Course.OBSTACLES) do
		if ids[ob.id] then
			bad("id repetido " .. ob.id)
		end
		ids[ob.id] = true
		if ob.kind ~= "gear" and ob.kind ~= "oil" and ob.kind ~= "battery" then
			bad("tipo inválido " .. tostring(ob.kind))
		else
			counts[ob.kind] += 1
		end
		if ob.kind == "battery" and ob.lift ~= "low" and ob.lift ~= "high" then
			bad("bateria sem altura " .. ob.id)
		end
		if ob.x <= Course.START_X + 40 then
			bad("obstáculo cedo demais " .. ob.id)
		end
		if ob.x >= Course.FINISH_X - 20 then
			bad("obstáculo perto demais da chegada " .. ob.id)
		end
	end
	if counts.gear < 1 or counts.oil < 1 or counts.battery < 1 then
		bad("faltou engrenagem, óleo ou bateria")
	end

	local boxes = Course.boxes()
	table.sort(boxes, function(a, b)
		return a.x < b.x
	end)
	for i = 2, #boxes do
		local prev = boxes[i - 1]
		local cur = boxes[i]
		local gap = (cur.x - cur.hx) - (prev.x + prev.hx)
		if gap < Course.MIN_EDGE_GAP then
			bad(string.format("vão %.1f entre %s e %s", gap, prev.id, cur.id))
		end
	end

	local last = boxes[#boxes]
	if Course.FINISH_X - (last.x + last.hx) < 24 then
		bad("chegada curta")
	end

	for i, cp in ipairs(Course.CHECKPOINTS) do
		if cp.index ~= i then
			bad("índice de posto " .. tostring(cp.index))
		end
		if i > 1 and cp.x <= Course.CHECKPOINTS[i - 1].x + 40 then
			bad("postos próximos demais")
		end
		for _, box in ipairs(boxes) do
			if inside(cp.x, box.x - box.hx, box.x + box.hx) then
				bad("posto " .. tostring(i) .. " dentro de " .. box.id)
			end
		end
		local back = cp.x - Course.RESPAWN_BACK
		for _, box in ipairs(boxes) do
			if inside(back, box.x - box.hx - 2, box.x + box.hx + 2) then
				bad("renascimento do posto " .. tostring(i) .. " dentro de " .. box.id)
			end
		end
		if back <= Course.START_X then
			bad("renascimento antes da largada")
		end
	end

	local lastCp = Course.CHECKPOINTS[#Course.CHECKPOINTS]
	if lastCp.x >= Course.FINISH_X - 30 then
		bad("último posto colado na chegada")
	end

	for slot = 1, 8 do
		local x, y, z = Course.slotPose(slot)
		if x <= Course.TRACK_MIN_X + 3 or x >= Course.START_X then
			bad("largada do robô " .. tostring(slot) .. " fora da reta")
		end
		if y ~= Course.FLOOR_TOP + Course.HIP then
			bad("altura da largada")
		end
		if math.abs(z) > Course.LANE_HALF - 2 then
			bad("largada fora da pista")
		end

		local lx, ly, lz = Course.lobbyPose(slot)
		if lx <= Course.LOBBY_MIN_X + 4 or lx >= Course.LOBBY_MAX_X - 4 then
			bad("lobby do robô " .. tostring(slot))
		end
		if math.abs(lz) > Course.LOBBY_HALF_Z - 2 then
			bad("lobby Z")
		end
		if ly ~= Course.FLOOR_TOP + Course.HIP then
			bad("altura do lobby")
		end
	end

	for rank = 1, 8 do
		local px, py, pz, _, extra = Course.podiumPose(rank, rank)
		if px <= Course.LOBBY_MIN_X + 2 or px >= Course.LOBBY_MAX_X - 2 then
			bad("pódio " .. tostring(rank) .. " fora do lobby")
		end
		if math.abs(pz) > Course.LOBBY_HALF_Z - 2 then
			bad("pódio Z " .. tostring(rank))
		end
		if py ~= Course.FLOOR_TOP + extra + Course.HIP then
			bad("altura do pódio")
		end
	end

	local holdX = select(1, Course.finishHoldPose(8, 8))
	if holdX >= Course.TRACK_END - 4 then
		bad("espera da chegada passa do chão")
	end

	return #errors == 0, errors
end

return Course
