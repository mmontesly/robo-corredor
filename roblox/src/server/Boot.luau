-- Ordem do boot, sem depender do Roblox, para poder executar fora do Studio.
-- O chão de segurança tem de existir antes de qualquer require que possa falhar.
-- Se a fábrica ou o robô quebrarem, o erro é reportado e a corrida não segue calada.

local Boot = {}

function Boot.run(api)
	api.log("[Nodex] boot: script do servidor iniciou")
	local safetyOk, safetyErr = pcall(api.ensureSafety)
	if not safetyOk then
		local text = "chão de segurança: " .. tostring(safetyErr)
		api.fail(text)
		return false, text
	end
	api.log("[Nodex] boot: chão de segurança pronto")

	local pads
	local ok, err = xpcall(function()
		api.installCharacter()
		pads = api.buildFactory()
		api.startRace(pads)
	end, debug.traceback)

	if not ok then
		api.fail(err)
		return false, err
	end

	api.log("[Nodex] boot: Fábrica pronta")
	return true, pads
end

return Boot
