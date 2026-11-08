-- Regras da corrida, em unidades do Roblox.
-- O app React usa 285 px/s, gravidade 2600 px/s² e impulso de pulo 980 px/s.
-- Aqui a gravidade é a padrão do Roblox (196.2) e a corrida anda a 22 studs/s.
-- Óleo/engrenagem e bateria mantêm a mesma fração e a mesma duração do app:
--   devagar = 0,5× por 1 s; turbo = 1,35× por 1,2 s.
-- O tempo esgotado continua 20 s depois de o primeiro chegar.

local Rules = {}

Rules.BASE_SPEED = 22
Rules.SLOW_MULT = 0.5
Rules.SLOW_TIME = 1
Rules.TURBO_MULT = 1.35
Rules.TURBO_TIME = 1.2
Rules.JUMP_HEIGHT = 8.5
Rules.GRAVITY = 196.2
Rules.LOBBY_SPEED = 18
Rules.COUNTDOWN_SECONDS = 3
Rules.DNF_AFTER = 20
Rules.PODIUM_HOLD = 16
Rules.RESET_COOLDOWN = 3
Rules.MAX_PLAYERS = 8
Rules.ALLOWANCE_SLACK = 6
Rules.ALLOWANCE_AHEAD = 12
Rules.REWIND_PAD = 4
-- O app: recarga 8 s, espera inicial 2 s, foguetinho 900 px/s e alcance 900 px.
-- 285 px/s lá equivalem a 22 studs/s aqui.
Rules.POWER_CD = 8
Rules.POWER_ARM = 2
Rules.ROCKET_LIFE = 2.5
Rules.ROCKET_RANGE = 22 * 900 / 285
Rules.ROCKET_SPEED = 22 * 900 / 285
Rules.OIL_LIFE = 8
Rules.OIL_BEHIND = 4
Rules.OIL_HALF = 3
Rules.OIL_JUMP = 2.15
Rules.MAX_POWERS = 8
-- Engrenagem: uma volta em 0,7 s. O óleo é mais curto: 0,4 s e a velocidade
-- cheia volta junto com o fim da capotagem. A pausa longa vinha do estado
-- GettingUp do Humanoid, não deste relógio.
Rules.TUMBLE_TIME = 0.7
Rules.OIL_TUMBLE_TIME = 0.4
-- Frente do Humanoid é -Z. A pista corre para +X.
-- CFrame.Angles(0, yaw, 0).LookVector = (-sin(yaw), 0, -cos(yaw)).
Rules.TRACK_YAW = -math.pi / 2

function Rules.speed(slowLeft: number, turboLeft: number): number
	local mult = 1
	if slowLeft > 0 then
		mult *= Rules.SLOW_MULT
	end
	if turboLeft > 0 then
		mult *= Rules.TURBO_MULT
	end
	return Rules.BASE_SPEED * mult
end

function Rules.currentSpeed(now: number, slowUntil: number, turboUntil: number): number
	return Rules.speed(slowUntil - now, turboUntil - now)
end

-- Documentação do Humanoid R6: a altura do RootPart parado é
-- LeftLeg.Size.Y + (0.5 * RootPart.Size.Y) + HipHeight.
-- HipHeight aqui é um deslocamento, não a distância do pé ao centro.
function Rules.r6RootClearance(legLength: number, rootHeight: number, hipHeight: number): number
	return legLength + (0.5 * rootHeight) + hipHeight
end

function Rules.r6HipHeightForFeet(legLength: number, rootHeight: number, rootAboveSoles: number): number
	return rootAboveSoles - legLength - (0.5 * rootHeight)
end

function Rules.lookVectorFromYaw(yaw: number): (number, number, number)
	return -math.sin(yaw), 0, -math.cos(yaw)
end

-- Ponto local (0, 0, localZ) depois da rotação Y do Roblox.
function Rules.rotatedLocalZ(localZ: number, yaw: number): (number, number)
	local x = localZ * math.sin(yaw)
	local z = localZ * math.cos(yaw)
	return x, z
end

function Rules.canUsePower(phase: string, inRound: boolean, finished: boolean, gone: boolean, now: number, readyAt: number): boolean
	if phase ~= "race" or not inRound or finished or gone then
		return false
	end
	return now >= readyAt
end

function Rules.nearestAhead(rows: { { id: number, x: number, racing: boolean } }, fromId: number, range: number): number?
	local fromX = nil
	for _, row in ipairs(rows) do
		if row.id == fromId then
			fromX = row.x
		end
	end
	if fromX == nil then
		return nil
	end
	local best = nil
	local bestDx = range
	for _, row in ipairs(rows) do
		if row.id ~= fromId and row.racing then
			local dx = row.x - fromX
			if dx > 0 and dx < bestDx then
				best = row.id
				bestDx = dx
			end
		end
	end
	return best
end

function Rules.rocketReached(rocketX: number, targetX: number, ownerId: number, targetId: number, targetRacing: boolean): boolean
	if ownerId == targetId or not targetRacing then
		return false
	end
	return rocketX >= targetX
end

function Rules.oilHits(puddleX: number, half: number, playerX: number, feetAbove: number, jumpClear: number, ownerId: number, playerId: number, already: boolean): boolean
	if playerId == ownerId or already then
		return false
	end
	if math.abs(playerX - puddleX) > half then
		return false
	end
	return feetAbove <= jumpClear
end

function Rules.canBeginTumble(now: number, tumbleUntil: number): boolean
	return now >= tumbleUntil
end

function Rules.tumbleActive(now: number, tumbleUntil: number): boolean
	return tumbleUntil > now
end

function Rules.tumbleCause(kind: string): boolean
	return kind == "gear" or kind == "oil"
end

function Rules.tumbleDuration(kind: string): number
	if kind == "oil" then
		return Rules.OIL_TUMBLE_TIME
	elseif kind == "gear" then
		return Rules.TUMBLE_TIME
	end
	return 0
end

-- Uma volta em torno de Z (o eixo da câmera lateral) durante a duração.
function Rules.tumbleSpinFor(duration: number): number
	return (2 * math.pi) / duration
end

function Rules.tumbleSpin(): number
	return Rules.tumbleSpinFor(Rules.TUMBLE_TIME)
end

-- O freio do óleo acaba no mesmo instante da capotagem.
function Rules.oilSlowUntil(now: number): number
	return now + Rules.OIL_TUMBLE_TIME
end

function Rules.gearSlowUntil(now: number): number
	return now + Rules.SLOW_TIME
end

-- Mancha já escorregada não dispara de novo, mesmo com o robô parado em cima
-- depois que o relógio zerou. Outra mancha, com o relógio livre, pode.
function Rules.canSlipPuddle(already: boolean, stillInside: boolean, now: number, tumbleUntil: number): boolean
	if already or not stillInside or Rules.tumbleActive(now, tumbleUntil) then
		return false
	end
	return Rules.canBeginTumble(now, tumbleUntil)
end

-- Rastro e chip só enquanto o servidor ainda conta turbo, o robô vive e corre.
function Rules.boostVisible(turboLeft: number, alive: boolean, racing: boolean): boolean
	return alive and racing and turboLeft > 0
end

function Rules.jumpVelocity(gravity: number?): number
	local g = gravity or Rules.GRAVITY
	return math.sqrt(2 * g * Rules.JUMP_HEIGHT)
end

function Rules.formatTime(seconds: number?): string
	if seconds == nil then
		return "--"
	end
	if seconds < 0 then
		seconds = 0
	end
	local totalCs = math.floor(seconds * 100 + 0.5)
	local cs = totalCs % 100
	local totalS = math.floor(totalCs / 100)
	local s = totalS % 60
	local m = math.floor(totalS / 60)
	return string.format("%d:%02d.%02d", m, s, cs)
end

function Rules.ordinal(n: number): string
	return tostring(n) .. "º"
end

export type Standing = {
	id: number,
	finished: boolean,
	time: number?,
	x: number,
	slot: number,
	gone: boolean?,
}

function Rules.placeOf(selfId: number, rows: { Standing }): number?
	local active = {}
	for _, row in ipairs(rows) do
		if not row.gone then
			table.insert(active, row)
		end
	end
	table.sort(active, function(a, b)
		if a.finished ~= b.finished then
			return a.finished
		end
		if a.finished and b.finished then
			local ta = a.time or math.huge
			local tb = b.time or math.huge
			if ta ~= tb then
				return ta < tb
			end
			return a.slot < b.slot
		end
		if a.x ~= b.x then
			return a.x > b.x
		end
		return a.slot < b.slot
	end)
	for i, row in ipairs(active) do
		if row.id == selfId then
			return i
		end
	end
	return nil
end

export type ResultRow = {
	id: number,
	finished: boolean,
	dnf: boolean,
	gone: boolean,
	time: number?,
	slot: number,
}

function Rules.podium(rows: { ResultRow }): { ResultRow }
	local copy = table.clone(rows)
	table.sort(copy, function(a, b)
		local function rank(r: ResultRow): number
			if r.finished then
				return 1
			end
			if r.dnf then
				return 2
			end
			return 3
		end
		local ra = rank(a)
		local rb = rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if ra == 1 then
			local ta = a.time or math.huge
			local tb = b.time or math.huge
			if ta ~= tb then
				return ta < tb
			end
		end
		return a.slot < b.slot
	end)
	return copy
end

export type RoundState = "racing" | "finished" | "dnf" | "gone"

function Rules.roundStatus(now: number, firstFinishAt: number?, states: { RoundState }): string
	local racing = 0
	for _, state in ipairs(states) do
		if state == "racing" then
			racing += 1
		end
	end
	if racing == 0 then
		return "done"
	end
	if firstFinishAt ~= nil and (now - firstFinishAt) >= Rules.DNF_AFTER then
		return "dnf_rest"
	end
	return "continue"
end

return Rules
