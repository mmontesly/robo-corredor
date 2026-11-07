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
