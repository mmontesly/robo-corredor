-- Interface em português, com botões grandes para toque e teclado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local Hud = {}

local function paint(c)
	return Config.toColor3(c)
end

local function corner(parent, radius)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
	return ui
end

local function label(parent, props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = props.font or Enum.Font.GothamBold
	text.TextSize = props.size or 18
	text.TextColor3 = props.color or paint(Config.NAVY)
	text.TextXAlignment = props.align or Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.TextWrapped = true
	text.Text = props.text or ""
	text.Size = props.sizeU or UDim2.fromScale(1, 0)
	text.AutomaticSize = props.auto or Enum.AutomaticSize.Y
	text.LayoutOrder = props.order or 0
	text.Parent = parent
	return text
end

local function button(parent, text, col, order)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 52)
	b.BackgroundColor3 = col
	b.Text = text
	b.TextSize = 22
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.LayoutOrder = order or 0
	b.Parent = parent
	corner(b, 16)
	return b
end

local function holdButton(parent, text, size, position, anchor)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.AnchorPoint = anchor
	b.BackgroundColor3 = paint(Config.NAVY)
	b.BackgroundTransparency = 0.12
	b.Text = text
	b.TextSize = 28
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.ZIndex = 20
	b.Parent = parent
	corner(b, 18)
	return b
end

local function bindHold(buttonObj, holds, key)
	local function down(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holds[key] = true
		end
	end
	local function up(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holds[key] = false
		end
	end
	buttonObj.InputBegan:Connect(down)
	buttonObj.InputEnded:Connect(up)
end

function Hud.mount(playerGui, fire)
	local holds = {
		forward = false,
		back = false,
		up = false,
		down = false,
		jump = false,
	}
	local last = nil
	local shownNotice = ""
	local noticeAt = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "NodexHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	gui.Parent = playerGui

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, -16, 0, 96)
	top.Position = UDim2.fromOffset(8, 8)
	top.BackgroundColor3 = Color3.new(1, 1, 1)
	top.BackgroundTransparency = 0.12
	top.Visible = false
	top.Parent = gui
	corner(top, 18)

	local batteryText = label(top, { text = "🔋 0", size = 22, align = Enum.TextXAlignment.Left })
	batteryText.AutomaticSize = Enum.AutomaticSize.None
	batteryText.Position = UDim2.fromOffset(14, 8)
	batteryText.Size = UDim2.fromOffset(120, 28)

	local placeText = label(top, { text = "1º lugar", size = 22, color = paint(Config.TITLE_ORANGE) })
	placeText.AutomaticSize = Enum.AutomaticSize.None
	placeText.Position = UDim2.new(0.5, -80, 0, 8)
	placeText.Size = UDim2.fromOffset(160, 28)

	local timeText = label(top, { text = "0:00.00", size = 20, align = Enum.TextXAlignment.Right })
	timeText.AutomaticSize = Enum.AutomaticSize.None
	timeText.Position = UDim2.new(1, -150, 0, 8)
	timeText.Size = UDim2.fromOffset(136, 28)

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(14, 44)
	barBack.Size = UDim2.new(1, -28, 0, 14)
	barBack.BackgroundColor3 = Color3.fromRGB(230, 234, 238)
	barBack.Parent = top
	corner(barBack, 8)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = paint(Config.BAR)
	barFill.Parent = barBack
	corner(barFill, 8)

	local effectText = label(top, { text = "", size = 16, color = paint(Config.NAVY) })
	effectText.AutomaticSize = Enum.AutomaticSize.None
	effectText.Position = UDim2.fromOffset(14, 64)
	effectText.Size = UDim2.new(1, -28, 0, 24)

	local resetBtn = Instance.new("TextButton")
	resetBtn.AnchorPoint = Vector2.new(0.5, 1)
	resetBtn.Size = UDim2.fromOffset(180, 40)
	resetBtn.Position = UDim2.new(0.5, 0, 1, -168)
	resetBtn.BackgroundColor3 = paint(Config.ORANGE)
	resetBtn.Text = "Voltar ao posto"
	resetBtn.TextSize = 14
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextColor3 = Color3.new(1, 1, 1)
	resetBtn.Visible = false
	resetBtn.ZIndex = 20
	resetBtn.Parent = gui
	corner(resetBtn, 12)
	resetBtn.MouseButton1Click:Connect(function()
		fire({ t = "checkpoint_reset" })
	end)

	local notice = label(gui, { text = "", size = 20, color = paint(Config.NAVY) })
	notice.AutomaticSize = Enum.AutomaticSize.None
	notice.BackgroundColor3 = Color3.new(1, 1, 1)
	notice.BackgroundTransparency = 0.1
	notice.Position = UDim2.new(0.5, -160, 0, 146)
	notice.Size = UDim2.fromOffset(320, 36)
	notice.Visible = false
	corner(notice, 12)

	local countdown = Instance.new("TextLabel")
	countdown.BackgroundTransparency = 1
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.38)
	countdown.Size = UDim2.fromOffset(280, 140)
	countdown.Font = Enum.Font.GothamBold
	countdown.TextScaled = true
	countdown.TextColor3 = paint(Config.TITLE_ORANGE)
	countdown.TextStrokeTransparency = 0.4
	countdown.TextStrokeColor3 = Color3.new(1, 1, 1)
	countdown.Text = ""
	countdown.Visible = false
	countdown.ZIndex = 15
	countdown.Parent = gui

	local hint = label(gui, { text = "", size = 16 })
	hint.AutomaticSize = Enum.AutomaticSize.None
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 108)
	hint.Size = UDim2.new(1, -24, 0, 32)
	hint.TextColor3 = paint(Config.NAVY)
	hint.BackgroundColor3 = Color3.new(1, 1, 1)
	hint.BackgroundTransparency = 0.2
	corner(hint, 12)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Card"
	scroll.AnchorPoint = Vector2.new(0.5, 0)
	scroll.Position = UDim2.new(0.5, 0, 0, 8)
	scroll.Size = UDim2.new(0.94, 0, 1, -150)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = false
	scroll.Parent = gui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Parent = scroll
	corner(card, 22)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	local title = label(card, { text = Config.TITLE, size = 28, color = paint(Config.TITLE_ORANGE), order = 1 })
	local world = label(card, { text = "🏭 " .. Config.WORLD, size = 20, order = 2 })
	local tip = label(card, {
		text = Config.TIP_TOUCH .. "\n" .. Config.TIP_JUMP .. "\n" .. Config.TIP_BATTERY .. "\nNo lobby: WASD ou setas, Espaço pula. ◀▶ andam, ▲▼ desviam.",
		size = 16,
		font = Enum.Font.Gotham,
		order = 3,
	})
	local countText = label(card, { text = "", size = 16, order = 4 })
	local winsText = label(card, { text = "", size = 15, font = Enum.Font.Gotham, order = 5 })

	local chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, 0, 0, 0)
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.LayoutOrder = 6
	chips.Parent = card
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(112, 36)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chips
	local chipButtons = {}
	for index, nick in ipairs(Config.NICKS) do
		local chip = Instance.new("TextButton")
		chip.BackgroundColor3 = Color3.fromRGB(233, 236, 239)
		chip.Text = nick
		chip.TextSize = 16
		chip.Font = Enum.Font.GothamBold
		chip.TextColor3 = paint(Config.NAVY)
		chip.LayoutOrder = index
		chip.Parent = chips
		corner(chip, 10)
		chip.MouseButton1Click:Connect(function()
			fire({ t = "nick", v = nick })
		end)
		chipButtons[nick] = chip
	end

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 7
	rows.Parent = card
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 4)
	rowLayout.Parent = rows

	local readyBtn = button(card, "Pronto", paint(Config.TEAL), 8)
	local startBtn = button(card, "Começar", paint(Config.ORANGE), 9)
	local returnBtn = button(card, "Nova corrida", paint(Config.ORANGE), 10)
	local waitText = label(card, { text = "", size = 16, font = Enum.Font.Gotham, order = 11 })

	readyBtn.MouseButton1Click:Connect(function()
		local ready = not (last and last.you and last.you.ready)
		fire({ t = "ready", v = ready })
	end)
	startBtn.MouseButton1Click:Connect(function()
		fire({ t = "start" })
	end)
	returnBtn.MouseButton1Click:Connect(function()
		fire({ t = "return" })
	end)

	local function touchPad(text, xScale, yScale, key)
		local b = holdButton(gui, text, UDim2.fromOffset(76, 64), UDim2.new(xScale, 0, yScale, 0), Vector2.new(0, 1))
		bindHold(b, holds, key)
		return b
	end
	-- 2x2 no canto esquerdo: não cobre o botão Pular da direita.
	local upBtn = touchPad("▲", 0, 1, "up")
	upBtn.Position = UDim2.new(0, 12, 1, -88)
	local downBtn = touchPad("▼", 0, 1, "down")
	downBtn.Position = UDim2.new(0, 12, 1, -16)
	local backBtn = touchPad("◀", 0, 1, "back")
	backBtn.Position = UDim2.new(0, 96, 1, -88)
	local forwardBtn = touchPad("▶", 0, 1, "forward")
	forwardBtn.Position = UDim2.new(0, 96, 1, -16)
	local jumpBtn = holdButton(gui, "Pular", UDim2.fromOffset(104, 104), UDim2.new(1, -16, 1, -16), Vector2.new(1, 1))
	jumpBtn.BackgroundColor3 = paint(Config.ORANGE)
	jumpBtn.TextSize = 24
	bindHold(jumpBtn, holds, "jump")

	local function clearRows()
		for _, child in ipairs(rows:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function addRow(text)
		local row = label(rows, { text = text, size = 16, align = Enum.TextXAlignment.Left, font = Enum.Font.Gotham })
		row.AutomaticSize = Enum.AutomaticSize.None
		row.Size = UDim2.new(1, 0, 0, 24)
	end

	local function render(snapshot)
		last = snapshot
		local phase = snapshot and snapshot.phase or "lobby"
		local you = snapshot and snapshot.you or nil
		local spectating = you and you.spectating or false
		local racing = phase == "race" or phase == "countdown"
		top.Visible = racing
		scroll.Visible = phase == "lobby" or phase == "podium" or spectating
		resetBtn.Visible = phase == "race" and you ~= nil and you.inRound and not you.finished and not you.spectating
		local showBelt = phase == "lobby"
		local showMove = phase == "lobby" or (phase == "race" and you and you.inRound and not you.finished and not you.spectating)
		backBtn.Visible = showBelt
		forwardBtn.Visible = showBelt
		upBtn.Visible = showMove
		downBtn.Visible = showMove
		jumpBtn.Visible = showMove == true

		if phase == "race" and not spectating then
			hint.Text = "A corrida anda sozinha. Espaço ou Pular. W/S ou ▲▼ desviam."
			hint.Visible = true
		elseif phase == "countdown" and not spectating then
			hint.Text = Config.TIP_JUMP
			hint.Visible = true
		else
			hint.Text = ""
			hint.Visible = false
		end

		if you and racing then
			batteryText.Text = "🔋 " .. tostring(you.batteries or 0)
			local place = you.place or 1
			placeText.Text = Rules.ordinal(place) .. " lugar"
			local elapsed = 0
			if you.finished and you.time then
				elapsed = you.time
			elseif snapshot.raceStartServer and snapshot.raceStartServer > 0 and phase == "race" then
				elapsed = math.max(0, Workspace:GetServerTimeNow() - snapshot.raceStartServer)
			end
			timeText.Text = Rules.formatTime(elapsed)
			local span = math.max(1, (snapshot.finishX or 1) - (snapshot.startX or 0))
			local hrp = nil
			local char = game:GetService("Players").LocalPlayer.Character
			if char then
				hrp = char:FindFirstChild("HumanoidRootPart")
			end
			local x = hrp and hrp.Position.X or you.x or 0
			local alpha = math.clamp((x - (snapshot.startX or 0)) / span, 0, 1)
			if you.finished then
				alpha = 1
			end
			barFill.Size = UDim2.fromScale(alpha, 1)
			local bits = {}
			if (you.turboLeft or 0) > 0 then
				table.insert(bits, string.format("TURBO %.1fs", you.turboLeft))
			end
			if (you.slowLeft or 0) > 0 then
				table.insert(bits, string.format("DEVAGAR %.1fs", you.slowLeft))
			end
			effectText.Text = #bits > 0 and table.concat(bits, "  ·  ") or Config.TIP_BATTERY
		end

		local countdownText = ""
		if phase == "countdown" and snapshot.countdownEnd and snapshot.countdownEnd > 0 then
			local left = snapshot.countdownEnd - Workspace:GetServerTimeNow()
			if left <= 0 then
				countdownText = "Já!"
			else
				countdownText = tostring(math.max(1, math.ceil(left)))
			end
		elseif phase == "race" and snapshot.raceStartServer and snapshot.raceStartServer > 0 then
			local elapsed = Workspace:GetServerTimeNow() - snapshot.raceStartServer
			if elapsed >= 0 and elapsed < 0.75 then
				countdownText = "Já!"
			end
		end
		countdown.Text = countdownText
		countdown.Visible = countdownText ~= ""

		if snapshot and snapshot.notice and snapshot.notice ~= "" and snapshot.notice ~= shownNotice then
			shownNotice = snapshot.notice
			noticeAt = os.clock()
		end
		if shownNotice ~= "" and os.clock() - noticeAt < 4 then
			notice.Text = shownNotice
			notice.Visible = true
		else
			notice.Visible = false
		end

		local nick = you and you.nick or ""
		for name, chip in pairs(chipButtons) do
			local on = name == nick
			chip.BackgroundColor3 = on and paint(Config.ORANGE) or Color3.fromRGB(233, 236, 239)
			chip.TextColor3 = on and Color3.new(1, 1, 1) or paint(Config.NAVY)
			chip.Visible = phase == "lobby"
		end
		chips.Visible = phase == "lobby"

		local total = snapshot and #snapshot.players or 0
		local cap = snapshot and snapshot.maxPlayers or Rules.MAX_PLAYERS
		if phase == "lobby" then
			local solo = total <= 1
			countText.Text = string.format("Robôs na sala: %d/%d%s", total, cap, solo and "  ·  treino solo" or "")
			title.Text = Config.TITLE
			world.Text = "🏭 " .. Config.WORLD
			tip.Visible = true
		elseif spectating then
			countText.Text = "Corrida em andamento. Você entra na próxima."
			title.Text = Config.TITLE
			tip.Visible = false
		elseif phase == "podium" then
			countText.Text = "Pódio da " .. Config.WORLD
			title.Text = "Pódio"
			world.Text = "🏭 " .. Config.WORLD
			tip.Visible = false
		end

		local winBits = {}
		if snapshot and snapshot.wins then
			for _, entry in ipairs(snapshot.wins) do
				table.insert(winBits, entry.nick .. " " .. tostring(entry.count))
			end
		end
		winsText.Text = #winBits > 0 and ("Vitórias nesta sessão: " .. table.concat(winBits, " · ")) or "Vitórias nesta sessão: ainda nenhuma"

		clearRows()
		if phase == "podium" and snapshot and snapshot.results then
			for index, row in ipairs(snapshot.results) do
				local tint = Config.COLORS[row.colorIndex]
				local who = row.nick .. (tint and (" · " .. tint.name) or "")
				if row.finished then
					addRow(Rules.ordinal(index) .. "  " .. who .. "  " .. Rules.formatTime(row.time) .. "  🔋 " .. tostring(row.batteries or 0))
				elseif row.dnf then
					addRow("DNF  " .. who .. "  tempo esgotado")
				else
					addRow("—  " .. who .. "  saiu")
				end
			end
		elseif snapshot and snapshot.players and (phase == "lobby" or spectating) then
			for _, row in ipairs(snapshot.players) do
				local tint = Config.COLORS[row.colorIndex]
				local bits = { row.nick }
				if tint then
					table.insert(bits, tint.name)
				end
				if you and row.userId == you.userId then
					table.insert(bits, "você")
				end
				if snapshot.hostUserId == row.userId then
					table.insert(bits, "anfitrião")
				end
				if row.ready then
					table.insert(bits, "pronto")
				end
				addRow("● " .. table.concat(bits, " · "))
			end
		end

		local isHost = you and you.isHost or false
		readyBtn.Visible = phase == "lobby"
		readyBtn.Text = (you and you.ready) and "Pronto ✓" or "Pronto"
		startBtn.Visible = phase == "lobby" and isHost
		startBtn.Text = total <= 1 and "Começar treino" or "Começar"
		returnBtn.Visible = phase == "podium"
		if phase == "lobby" and not isHost then
			waitText.Text = "O anfitrião pode começar, ou todos apertam Pronto."
		elseif phase == "podium" then
			waitText.Text = "A sala volta ao lobby sozinha. Ou toque em Nova corrida."
		elseif spectating then
			waitText.Text = "Espere esta corrida acabar."
		else
			waitText.Text = ""
		end
	end

	return {
		render = render,
		holds = function()
			return holds
		end,
		releaseTouch = function()
			holds.forward = false
			holds.back = false
			holds.up = false
			holds.down = false
			holds.jump = false
		end,
	}
end

return Hud
