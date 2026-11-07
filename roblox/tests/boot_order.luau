-- Executa a ordem real do boot. Não é um teste do Roblox Studio.
local Boot = require("../src/server/Boot")

local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

local function run(install, build)
	local order = {}
	local ok = Boot.run({
		log = function(message)
			table.insert(order, message)
		end,
		ensureSafety = function()
			table.insert(order, "safety")
		end,
		installCharacter = function()
			table.insert(order, "install")
			if install then
				install()
			end
		end,
		buildFactory = function()
			table.insert(order, "build")
			if build then
				return build()
			end
			return { lobby = true }
		end,
		startRace = function(pads)
			table.insert(order, "race")
			check(pads ~= nil, "a corrida recebe o retorno da fábrica")
		end,
		fail = function(err)
			table.insert(order, "fail:" .. tostring(err))
		end,
	})
	return ok, order
end

local ok, order = run(nil, nil)
check(ok == true, "boot feliz")
check(order[1] == "[Nodex] boot: script do servidor iniciou", "primeira linha é o boot")
check(order[2] == "safety", "chão antes de qualquer montagem")
check(order[3] == "[Nodex] boot: chão de segurança pronto", "log do chão")
check(order[4] == "install" and order[5] == "build" and order[6] == "race", "robô, fábrica, corrida nessa ordem")

local failed, badOrder = run(function()
	error("rig quebrado")
end, nil)
check(failed == false, "erro no robô não é silêncio")
check(badOrder[2] == "safety", "o chão existe mesmo se o robô quebrar")
local sawFail = false
local sawBuild = false
for _, step in ipairs(badOrder) do
	if string.sub(step, 1, 5) == "fail:" then
		sawFail = true
		check(string.find(step, "rig quebrado", 1, true) ~= nil, "a falha cita a causa")
	end
	if step == "build" or step == "race" then
		sawBuild = true
	end
end
check(sawFail, "fail foi chamado")
check(not sawBuild, "fábrica e corrida não seguem depois do erro")

local _, factoryFail = run(nil, function()
	error("pista inválida")
end)
local stopped = false
for _, step in ipairs(factoryFail) do
	if string.find(step, "pista inválida", 1, true) then
		stopped = true
	end
	if step == "race" then
		check(false, "corrida não começa se a fábrica quebra")
	end
end
check(stopped, "erro da fábrica é reportado")
check(factoryFail[2] == "safety", "chão continua antes da fábrica")

if fails > 0 then
	error(tostring(fails) .. " falha(s) no boot")
end
print("OK boot: chão primeiro, erro visível, sem espera infinita")
