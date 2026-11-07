-- Testes puros, sem o aplicativo Roblox.
-- Roda com: lune run tests/check.luau
-- A simulação cinética usa a mesma gravidade, o mesmo pulo e as mesmas caixas da pista.
-- Ela não substitui um teste dentro do Roblox Studio.

local Config = require("../src/shared/Config")
local Course = require("../src/shared/Course")
local Rules = require("../src/shared/Rules")

local fails = 0
local checks = 0

local function check(ok, msg)
	checks += 1
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

local function near(a, b, msg)
	check(math.abs(a - b) < 1e-6, msg .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end

near(Rules.speed(0, 0), 22, "velocidade base")
near(Rules.speed(1, 0), 11, "óleo/engrenagem pela metade")
near(Rules.speed(0, 1), 29.7, "turbo 1,35×")
near(Rules.speed(1, 1), 14.85, "turbo e devagar juntos")
near(Rules.currentSpeed(10, 10, 0), 22, "efeito já acabou")
near(Rules.currentSpeed(10, 11, 12), 14.85, "os dois efeitos ainda valem")
near(Rules.GRAVITY, 196.2, "gravidade padrão do Roblox, não 2600")
near(Rules.SLOW_TIME, 1, "devagar dura 1 s como no app")
near(Rules.TURBO_TIME, 1.2, "turbo dura 1,2 s como no app")
near(Rules.SLOW_MULT, 0.5, "multiplicador do óleo")
near(Rules.TURBO_MULT, 1.35, "multiplicador da bateria")
near(Rules.DNF_AFTER, 20, "tempo esgotado 20 s")
near(Rules.COUNTDOWN_SECONDS, 3, "contagem 3, 2, 1")
check(Rules.MAX_PLAYERS == 8, "sala de 8")
check(Rules.JUMP_HEIGHT > 7 and Rules.JUMP_HEIGHT < 12, "pulo em studs, não em pixels")
check(Rules.jumpVelocity() > 40, "impulso de pulo coerente com a gravidade")

check(Rules.formatTime(nil) == "--", "tempo vazio")
check(Rules.formatTime(0) == "0:00.00", "zero")
check(Rules.formatTime(65.2) == "1:05.20", "1 min 5,2 s")
check(Rules.ordinal(1) == "1º" and Rules.ordinal(4) == "4º", "lugar em português")

local places = Rules.placeOf(2, {
	{ id = 1, finished = true, time = 40, x = 100, slot = 1 },
	{ id = 2, finished = false, time = nil, x = 80, slot = 2 },
	{ id = 3, finished = false, time = nil, x = 90, slot = 3 },
	{ id = 4, finished = true, time = 40, x = 100, slot = 4 },
})
check(places == 4, "quem já chegou fica na frente; empate de tempo usa o slot")
local first = Rules.placeOf(1, {
	{ id = 1, finished = true, time = 40, x = 100, slot = 2 },
	{ id = 4, finished = true, time = 40, x = 100, slot = 1 },
})
check(first == 2, "no empate, o slot menor fica na frente")

local pod = Rules.podium({
	{ id = 3, finished = false, dnf = true, gone = false, time = nil, slot = 1 },
	{ id = 2, finished = true, dnf = false, gone = false, time = 50, slot = 2 },
	{ id = 9, finished = false, dnf = false, gone = true, time = nil, slot = 3 },
	{ id = 1, finished = true, dnf = false, gone = false, time = 42, slot = 4 },
	{ id = 4, finished = true, dnf = false, gone = false, time = 42, slot = 1 },
})
check(pod[1].id == 4 and pod[2].id == 1, "pódio: menor tempo, empate pelo slot")
check(pod[3].id == 2, "terceiro é o outro que chegou")
check(pod[4].id == 3 and pod[4].dnf, "DNF depois de quem chegou")
check(pod[5].id == 9 and pod[5].gone, "quem saiu fica por último")

check(Rules.roundStatus(0, nil, { "racing", "racing" }) == "continue", "corrida segue")
check(Rules.roundStatus(29.9, 10, { "finished", "racing" }) == "continue", "19,9 s ainda corre")
check(Rules.roundStatus(50, nil, { "finished", "racing" }) == "continue", "sem primeiro colocado o relógio de DNF não corre")
check(Rules.roundStatus(30, 10, { "finished" }) == "done", "todo mundo chegou")
check(Rules.roundStatus(30, 10, { "finished", "racing" }) == "dnf_rest", "no instante dos 20 s o restante vira DNF")
check(Rules.roundStatus(30, 10.001, { "finished", "racing" }) == "continue", "19,999 s ainda não estoura")
check(Rules.roundStatus(40, 10, { "gone", "gone" }) == "done", "se todo mundo saiu, a rodada fecha")
check(Rules.roundStatus(0, nil, {}) == "done", "sem corredores")

local ok, errs = Course.validate()
if not ok then
	print(table.concat(errs, "\n"))
end
check(ok, "a pista da Fábrica passa na validação")
check(Course.checkpointCount() == 4, "quatro postos")
check(Course.FINISH_X > Course.CHECKPOINTS[4].x, "chegada depois do último posto")

local boxes = Course.boxes()
local gears, oils, bats, highs = 0, 0, 0, 0
for _, box in ipairs(boxes) do
	if box.kind == "gear" then
		gears += 1
	elseif box.kind == "oil" then
		oils += 1
	elseif box.kind == "battery" then
		bats += 1
		if box.lift == "high" then
			highs += 1
		end
	end
end
check(gears == 6 and oils == 5 and bats == 7 and highs == 3, "mistura de engrenagem, óleo e bateria")

local gear = boxes[1]
local standingFeet = Course.FLOOR_TOP
local jumpedFeet = Course.FLOOR_TOP + 6
check(Course.penalizeGear(standingFeet, gear.x, 0, gear), "no chão, a engrenagem pega")
check(not Course.penalizeGear(jumpedFeet, gear.x, 0, gear), "pulando, a engrenagem não pega")
check(not Course.penalizeGear(standingFeet, gear.x + 30, 0, gear), "longe, a engrenagem não pega")

local oil = nil
local lowBat = nil
local highBat = nil
for _, box in ipairs(boxes) do
	if box.kind == "oil" and not oil then
		oil = box
	elseif box.kind == "battery" and box.lift == "low" and not lowBat then
		lowBat = box
	elseif box.kind == "battery" and box.lift == "high" and not highBat then
		highBat = box
	end
end
check(oil ~= nil and lowBat ~= nil and highBat ~= nil, "há óleo, bateria baixa e bateria alta")
check(Course.penalizeOil(standingFeet, oil.x, 0, oil, false), "óleo pega quem está no chão")
check(not Course.penalizeOil(Course.FLOOR_TOP + 5, oil.x, 0, oil, false), "óleo não pega no alto do pulo")
local hip = Course.FLOOR_TOP + Course.HIP
check(Course.collectBattery(hip, lowBat.x, 0, lowBat), "bateria baixa é pega correndo")
check(not Course.collectBattery(hip, highBat.x, 0, highBat), "bateria alta não é pega parado")
check(Course.collectBattery(hip + 6, highBat.x, 0, highBat), "bateria alta é pega no pulo")
check(Course.clearedCheckpoint(Course.CHECKPOINTS[1].x, 0).index == 1, "primeiro posto")
local onlyNext = Course.clearedCheckpoint(Course.CHECKPOINTS[2].x + 5, 0)
check(onlyNext ~= nil and onlyNext.index == 1, "mesmo lá na frente, só marca o próximo posto")
check(Course.clearedCheckpoint(Course.CHECKPOINTS[2].x, 1).index == 2, "posto seguinte")
check(not Course.canFinish(Course.FINISH_X, 3), "sem o último posto não chega")
check(Course.canFinish(Course.FINISH_X, 4), "com os postos, a linha conta")

local function simulate(jump: boolean)
	local x = 0
	local feet = Course.FLOOR_TOP
	local vy = 0
	local hit = {}
	local slows = 0
	local batteries = 0
	local checkpoint = 0
	local t = 0
	local dt = 1 / 60
	local slowUntil = 0
	local g = Rules.GRAVITY
	local lead = { gear = 6.5, oil = 6.0, high = 4.0 }
	while t < 90 and x < Course.FINISH_X + 1 do
		local speed = Rules.currentSpeed(t, slowUntil, 0)
		if jump and feet <= Course.FLOOR_TOP + 0.05 then
			local nearest = nil
			for _, box in ipairs(boxes) do
				if box.x + box.hx >= x then
					local care = box.kind == "gear" or box.kind == "oil" or (box.kind == "battery" and box.lift == "high")
					if care and (nearest == nil or box.x < nearest.x) then
						nearest = box
					end
				end
			end
			if nearest then
				local distance = lead[nearest.kind] or lead.high
				if nearest.kind == "battery" then
					distance = lead.high
				end
				if x >= nearest.x - distance and x < nearest.x then
					vy = Rules.jumpVelocity(g)
				end
			end
		end
		vy -= g * dt
		feet += vy * dt
		if feet <= Course.FLOOR_TOP then
			feet = Course.FLOOR_TOP
			vy = 0
		end
		x += speed * dt
		for _, box in ipairs(boxes) do
			if box.kind == "gear" then
				local left = box.x - box.hx - Course.BODY_RADIUS
				local right = box.x + box.hx + Course.BODY_RADIUS
				if x > left and x < right and feet < Course.FLOOR_TOP + Course.GEAR_DIAMETER - 0.15 then
					x = left
				end
			end
		end
		local hrpY = feet + Course.HIP
		for _, box in ipairs(boxes) do
			if not hit[box.id] then
				local caught = false
				if box.kind == "gear" and Course.penalizeGear(feet, x, 0, box) then
					caught = true
					slows += 1
					slowUntil = t + Rules.SLOW_TIME
				elseif box.kind == "oil" and Course.penalizeOil(feet, x, 0, box, false) then
					caught = true
					slows += 1
					slowUntil = t + Rules.SLOW_TIME
				elseif box.kind == "battery" and Course.collectBattery(hrpY, x, 0, box) then
					caught = true
					batteries += 1
				end
				if caught then
					hit[box.id] = true
				end
			end
		end
		local cp = Course.clearedCheckpoint(x, checkpoint)
		if cp then
			checkpoint = cp.index
		end
		t += dt
		if Course.canFinish(x, checkpoint) then
			return {
				finished = true,
				t = t,
				x = x,
				checkpoint = checkpoint,
				batteries = batteries,
				slows = slows,
			}
		end
	end
	return {
		finished = false,
		t = t,
		x = x,
		checkpoint = checkpoint,
		batteries = batteries,
		slows = slows,
	}
end

local good = simulate(true)
check(good.finished, "quem pula atravessa a Fábrica")
check(good.checkpoint == 4, "quem pula passa nos 4 postos")
check(good.batteries == 7, "quem pula pega as 7 baterias")
check(good.slows == 0, "o pulo certo não toma óleo nem engrenagem")
check(good.t > 25 and good.t < 50, "volta limpa perto de meio minuto, não os 7000 px do app")

local stuck = simulate(false)
check(not stuck.finished, "sem pular, a engrenagem sólida barra")
check(stuck.checkpoint == 0, "sem pular, não alcança o posto")
check(stuck.slows >= 1, "encostar na engrenagem aplica o devagar uma vez")
check(stuck.x < 58, "fica antes da primeira engrenagem")

check(#Config.NICKS == 12, "doze apelidos")
local expectedNicks = { "Raio", "Foguete", "Turbo", "Faísca", "Pipoca", "Trovão", "Cometa", "Bolinha", "Pulinho", "Parafuso", "Estrela", "Biscoito" }
for i, nick in ipairs(expectedNicks) do
	check(Config.NICKS[i] == nick, "apelido " .. nick)
end
check(Config.isNick("Raio") and not Config.isNick("Mario") and not Config.isNick(""), "apelido só da lista")
check(#Config.COLORS == 8, "oito cores")
local expectedHex = { "#4CC9F0", "#FF006E", "#8338EC", "#06D6A0", "#FB5607", "#FFBE0B", "#3A86FF", "#8D6E63" }
local expectedNames = { "Azul", "Rosa", "Roxo", "Verde", "Laranja", "Amarelo", "Anil", "Marrom" }
for i, hex in ipairs(expectedHex) do
	local c = Config.COLORS[i]
	local got = string.format("#%02X%02X%02X", c.r, c.g, c.b)
	check(got == hex and c.name == expectedNames[i], "cor " .. expectedNames[i])
end
check(Config.TITLE == "Nodex: Robô Corredor", "título")
check(Config.WORLD == "Fábrica", "mundo")
check(Config.TIP_JUMP == "Pule as engrenagens e o óleo!", "dica da engrenagem")
check(Config.TIP_BATTERY == "Baterias dão turbo!", "dica da bateria")

local names = {}
for slot = 1, 8 do
	names[Config.NICKS[slot]] = true
	local x = select(1, Course.slotPose(slot))
	check(x > Course.TRACK_MIN_X and x < Course.START_X, "largada " .. tostring(slot))
end
check(names.Raio and names.Bolinha, "os oito primeiros apelidos cabem na largada")

local lx, ly, lz = Rules.lookVectorFromYaw(Rules.TRACK_YAW)
near(lx, 1, "yaw da pista olha para +X")
near(ly, 0, "yaw sem componente Y")
near(lz, 0, "yaw da pista não olha para Z")
local dx, _, dz = Rules.lookVectorFromYaw(0)
near(dx, 0, "yaw 0 é a frente padrão -Z em X")
near(dz, -1, "yaw 0 é a frente padrão -Z")
local faceX, faceZ = Rules.rotatedLocalZ(-1, Rules.TRACK_YAW)
near(faceX, 1, "rosto em -Z local aponta para a chegada")
near(faceZ, 0, "rosto em -Z local não vai para o lado")
local backX = Rules.rotatedLocalZ(1, Rules.TRACK_YAW)
near(backX, -1, "rosto em +Z local ficaria de costas")

-- Rig R6: perna 2, root altura 2, sola 3 abaixo do centro. Fórmula oficial:
-- altura do root = perna + metade do root + HipHeight.
local legLength, rootHeight, rootAboveSoles = 2, 2, Course.HIP
local wrongClearance = Rules.r6RootClearance(legLength, rootHeight, rootAboveSoles)
check(wrongClearance == 6, "HipHeight 3 no R6 deixa o root a 6 studs")
check(wrongClearance - rootAboveSoles == 3, "isso abre um vão de 3 studs sob o pé")
local hip = Rules.r6HipHeightForFeet(legLength, rootHeight, rootAboveSoles)
check(hip == 0, "HipHeight R6 derivado da geometria é 0")
check(Rules.r6RootClearance(legLength, rootHeight, hip) == rootAboveSoles, "com HipHeight 0 o pé encosta no chão")

check(Rules.POWER_CD == 8, "recarga do app é 8 s")
check(Rules.POWER_ARM == 2, "espera inicial de 2 s")
check(not Rules.canUsePower("lobby", true, false, false, 10, 0), "poder só na corrida")
check(not Rules.canUsePower("race", true, true, false, 10, 0), "quem chegou não atira")
check(not Rules.canUsePower("race", true, false, false, 5, 9), "recarga bloqueia")
check(Rules.canUsePower("race", true, false, false, 9, 9), "recarga zerada libera")
local aheadId = Rules.nearestAhead({
	{ id = 1, x = 10, racing = true },
	{ id = 2, x = 40, racing = true },
	{ id = 3, x = 80, racing = true },
	{ id = 4, x = 200, racing = true },
}, 1, Rules.ROCKET_RANGE)
check(aheadId == 2, "foguetinho mira o mais próximo à frente")
check(Rules.nearestAhead({ { id = 1, x = 10, racing = true } }, 1, Rules.ROCKET_RANGE) == nil, "solo não tem alvo")
check(Rules.nearestAhead({
	{ id = 1, x = 10, racing = true },
	{ id = 2, x = 5, racing = true },
}, 1, Rules.ROCKET_RANGE) == nil, "quem está atrás não é alvo")
check(not Rules.rocketReached(20, 30, 1, 1, true), "foguetinho não acerta o dono")
check(not Rules.rocketReached(40, 30, 1, 2, false), "alvo que já saiu da corrida não leva")
check(Rules.rocketReached(30, 30, 1, 2, true), "foguetinho acerta ao alcançar")
check(not Rules.rocketReached(29, 30, 1, 2, true), "ainda não chegou")
check(not Rules.oilHits(10, 3, 10, 0, Rules.OIL_JUMP, 1, 1, false), "óleo não pega o dono")
check(Rules.oilHits(10, 3, 11, 0, Rules.OIL_JUMP, 1, 2, false), "óleo pega quem vem por cima no chão")
check(not Rules.oilHits(10, 3, 11, 4, Rules.OIL_JUMP, 1, 2, false), "pulo passa pelo óleo")
check(not Rules.oilHits(10, 3, 11, 0, Rules.OIL_JUMP, 1, 2, true), "óleo não repete o acerto")
check(Rules.ROCKET_LIFE == 2.5, "vida do foguetinho do jogador")
check(Rules.MAX_POWERS == 8, "limite de projéteis")
check(Rules.POWER_CD > Rules.POWER_ARM, "recarga maior que a espera inicial")

if fails > 0 then
	error(tostring(fails) .. " falha(s) em " .. tostring(checks) .. " checagens")
end
print(string.format("OK %d checagens. Volta limpa simulada em %.2f s, %d baterias, %d postos.", checks, good.t, good.batteries, good.checkpoint))
