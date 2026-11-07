-- Textos, apelidos e cores do Nodex: Robô Corredor.
-- Sem instâncias do Roblox neste arquivo, para os testes rodarem fora do Studio.
-- Color3 só é criado quando o jogo chama toColor3.

local Config = {}

Config.TITLE = "Nodex: Robô Corredor"
Config.WORLD = "Fábrica"
Config.TIP_JUMP = "Pule as engrenagens e o óleo!"
Config.TIP_BATTERY = "Baterias dão turbo!"
Config.TIP_TOUCH = "Toque para o Nodex pular."

-- Os mesmos apelidos fechados do app (sem texto livre).
Config.NICKS = {
	"Raio",
	"Foguete",
	"Turbo",
	"Faísca",
	"Pipoca",
	"Trovão",
	"Cometa",
	"Bolinha",
	"Pulinho",
	"Parafuso",
	"Estrela",
	"Biscoito",
}

-- As 8 primeiras cores do app. Vermelho e Folha ficam de fora: a sala Roblox cabe 8.
Config.COLORS = {
	{ name = "Azul", r = 76, g = 201, b = 240 },
	{ name = "Rosa", r = 255, g = 0, b = 110 },
	{ name = "Roxo", r = 131, g = 56, b = 236 },
	{ name = "Verde", r = 6, g = 214, b = 160 },
	{ name = "Laranja", r = 251, g = 86, b = 7 },
	{ name = "Amarelo", r = 255, g = 190, b = 11 },
	{ name = "Anil", r = 58, g = 134, b = 255 },
	{ name = "Marrom", r = 141, g = 110, b = 99 },
}

Config.SKY = { r = 255, g = 232, b = 163 }
Config.GROUND = { r = 108, g = 117, b = 125 }
Config.BELT = { r = 251, g = 133, b = 0 }
Config.OIL = { r = 29, g = 53, b = 87 }
Config.NAVY = { r = 2, g = 48, b = 71 }
Config.ORANGE = { r = 251, g = 86, b = 7 }
Config.TEAL = { r = 6, g = 214, b = 160 }
Config.TITLE_ORANGE = { r = 255, g = 102, b = 0 }
Config.BAR = { r = 46, g = 196, b = 182 }
Config.WHITE = { r = 255, g = 255, b = 255 }
Config.INK = { r = 2, g = 48, b = 71 }
Config.BATTERY = { r = 126, g = 214, b = 90 }
Config.BATTERY_CAP = { r = 255, g = 214, b = 70 }
Config.GEAR = { r = 90, g = 99, b = 110 }
Config.GEAR_TOOTH = { r = 70, g = 78, b = 88 }

Config.MACHINES = {
	{ r = 142, g = 202, b = 230 },
	{ r = 160, g = 196, b = 255 },
	{ r = 189, g = 178, b = 255 },
	{ r = 155, g = 246, b = 255 },
}

Config.CONFETTI = {
	{ r = 255, g = 0, b = 110 },
	{ r = 251, g = 86, b = 7 },
	{ r = 255, g = 190, b = 11 },
	{ r = 6, g = 214, b = 160 },
	{ r = 58, g = 134, b = 255 },
	{ r = 131, g = 56, b = 236 },
}

Config.TAG_TOOTH = "NodexTooth"
Config.TAG_PICKUP = "NodexPickup"
Config.TAG_CHEVRON = "NodexChevron"
Config.TAG_BOB = "NodexBob"

function Config.isNick(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, nick in ipairs(Config.NICKS) do
		if nick == value then
			return true
		end
	end
	return false
end

function Config.toColor3(c: { r: number, g: number, b: number })
	return Color3.fromRGB(c.r, c.g, c.b)
end

return Config
