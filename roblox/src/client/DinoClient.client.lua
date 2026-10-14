-- Экран игрока: табло, большие кнопки, питомцы, магазин, подарки, колесо, значки, коды, эмоции.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("DinoRemotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent

local C = {
	cream = Color3.fromRGB(247, 243, 227),
	paper = Color3.fromRGB(235, 228, 205),
	ink = Color3.fromRGB(31, 42, 23),
	blue = Color3.fromRGB(47, 111, 216),
	red = Color3.fromRGB(216, 69, 47),
	gold = Color3.fromRGB(242, 184, 34),
	green = Color3.fromRGB(88, 170, 60),
	purple = Color3.fromRGB(150, 90, 230),
	grey = Color3.fromRGB(160, 160, 150),
}
local FONT = Enum.Font.FredokaOne
local PET_UI_COLORS = {
	green = Config.DINOS.green.color,
	red = Config.DINOS.red.color,
	gold = Config.DINOS.gold.color,
	rainbow = Color3.fromRGB(230, 90, 200),
}

local data: any = nil
local isDino = false

-- ---------- помощники ----------

local function make(class: string, props: { [string]: any }): any
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(o :: any)[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end

local function corner(o: Instance, r: UDim?)
	make("UICorner", { CornerRadius = r or UDim.new(0, 12), Parent = o })
end

local function stroke(o: Instance, thickness: number?, color: Color3?)
	make("UIStroke", { Thickness = thickness or 3, Color = color or C.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.ink,
		Parent = parent,
	})
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	return t
end

local playJingle: () -> ()

local function playSound(name: string)
	if name == "win" then
		playJingle()
		return
	end
	local def = Config.SOUNDS[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.PlaybackSpeed = def.speed or 1
	s.Volume = 0.6
	s.Parent = SoundService
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
end

local function button(parent: Instance, props: { [string]: any }, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.ink,
		BackgroundColor3 = C.gold,
		AutoButtonColor = true,
		Parent = parent,
	})
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	corner(b)
	stroke(b, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	b.Activated:Connect(function()
		playSound("pickup")
		onClick()
	end)
	return b
end

local function ask(action: string, arg: any?): any
	local ok, res = pcall(Request.InvokeServer, Request, action, arg)
	if ok and type(res) == "table" then
		return res
	end
	return { ok = false }
end

-- Голос: Roblox Text-to-Speech. Если не поддерживается — молча пропускаем, надписи всё равно есть.
local function speak(line: string)
	if not Config.VOICE_ENABLED then
		return
	end
	task.spawn(function()
		local tts, out
		local ok = pcall(function()
			tts = Instance.new("AudioTextToSpeech")
			tts.Text = line
			out = Instance.new("AudioDeviceOutput")
			local wire = Instance.new("Wire")
			tts.Parent = SoundService
			out.Parent = SoundService
			wire.SourceInstance = tts
			wire.TargetInstance = out
			wire.Parent = tts
			tts:Play()
		end)
		task.wait(ok and 8 or 0)
		if tts then
			tts:Destroy()
		end
		if out then
			out:Destroy()
		end
	end)
end

local function formatWait(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if h > 0 then
		return h .. " ч " .. m .. " мин"
	end
	return m .. " мин"
end

-- ---------- экран ----------

local gui = make("ScreenGui", {
	Name = "DinoUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- табло сверху
local bar = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.new(0.6, 0, 0, 46),
	BackgroundColor3 = C.cream,
	Parent = gui,
})
corner(bar)
stroke(bar)
make("UISizeConstraint", { MaxSize = Vector2.new(460, 46), MinSize = Vector2.new(280, 46), Parent = bar })
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = bar,
})
local function chip(order: number, width: number, bg: Color3?, fg: Color3): TextLabel
	local t = label(bar, {
		LayoutOrder = order,
		Size = UDim2.new(width, -6, 0, 36),
		BackgroundColor3 = bg or C.cream,
		BackgroundTransparency = bg and 0 or 1,
		TextColor3 = fg,
	})
	corner(t, UDim.new(1, 0))
	return t
end
local humansChip = chip(1, 0.36, C.blue, C.cream)
local timeChip = chip(2, 0.26, nil, C.ink)
local dinosChip = chip(3, 0.36, C.red, C.cream)

local statusLine = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.new(0.6, 0, 0, 24),
	TextColor3 = C.cream,
	TextStrokeTransparency = 0,
	Text = "",
})

local dinoBanner = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.new(0.5, 0, 0, 30),
	BackgroundColor3 = C.red,
	BackgroundTransparency = 0,
	TextColor3 = C.cream,
	Text = "🦖 Ты динозавр! Лови людей!",
	Visible = false,
})
corner(dinoBanner, UDim.new(1, 0))

-- монетки
local coinsLabel = label(gui, {
	Position = UDim2.new(0, 10, 0, 6),
	Size = UDim2.new(0, 134, 0, 40),
	BackgroundColor3 = C.cream,
	BackgroundTransparency = 0,
	Text = "🪙 0",
})
corner(coinsLabel, UDim.new(1, 0))
stroke(coinsLabel)

-- большая надпись
local bigLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.3, 0),
	Size = UDim2.new(0.8, 0, 0, 64),
	TextColor3 = C.cream,
	TextStrokeTransparency = 0,
	Text = "",
	ZIndex = 5,
})
local bigToken = 0
local function showBig(text: string, seconds: number)
	bigToken += 1
	local my = bigToken
	bigLabel.Text = text
	bigLabel.TextTransparency = 0
	bigLabel.TextStrokeTransparency = 0
	bigLabel.Size = UDim2.new(0.5, 0, 0, 40)
	TweenService:Create(bigLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.8, 0, 0, 64) }):Play()
	task.delay(seconds, function()
		if my == bigToken then
			bigLabel.Text = ""
		end
	end)
end

-- маленькие сообщения внизу
local toastArea = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.7, 0, 0, 200),
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastArea,
})
local toastOrder = 0
local function toast(text: string)
	toastOrder += 1
	local t = label(toastArea, {
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.2,
		TextColor3 = C.cream,
		Text = text,
	})
	corner(t)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = t })
	local items = {}
	for _, c in ipairs(toastArea:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items > 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(3.5, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.45)
			t:Destroy()
		end
	end)
end

-- ---------- окно-панель ----------

local overlay = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.ink,
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.86),
	BackgroundColor3 = C.cream,
	ZIndex = 11,
	Parent = overlay,
})
corner(panel, UDim.new(0, 18))
stroke(panel, 4)
make("UISizeConstraint", { MaxSize = Vector2.new(580, 440), Parent = panel })
local panelTitle = label(panel, {
	Position = UDim2.new(0, 16, 0, 10),
	Size = UDim2.new(1, -80, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
})
local content = make("ScrollingFrame", {
	Position = UDim2.new(0, 12, 0, 58),
	Size = UDim2.new(1, -24, 1, -70),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = C.ink,
	ZIndex = 12,
	Parent = panel,
})
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

local currentPanel: string? = nil
local render: () -> ()

local function closePanel()
	currentPanel = nil
	overlay.Visible = false
end

button(panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.new(0, 44, 0, 44),
	BackgroundColor3 = C.red,
	TextColor3 = C.cream,
	Text = "✕",
	ZIndex = 13,
}, closePanel)

local function openPanel(name: string)
	currentPanel = name
	overlay.Visible = true
	content.CanvasPosition = Vector2.zero
	render()
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function clearContent()
	for _, c in ipairs(content:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	order = 0
end

local function heading(text: string)
	label(content, { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), Text = text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
end

local function note(text: string)
	label(content, {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 22),
		Text = text,
		TextColor3 = Color3.fromRGB(90, 95, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
end

local function row(height: number): Frame
	local f = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = C.paper,
		ZIndex = 12,
		Parent = content,
	})
	corner(f)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = f })
	return f
end

local function sorted<T>(list: { T }, less: (T, T) -> boolean): { T }
	local copy = table.clone(list)
	table.sort(copy, less)
	return copy
end

-- ---------- вылупление ----------

local hatchLayer = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.ink,
	BackgroundTransparency = 0.25,
	Visible = false,
	ZIndex = 30,
	Parent = gui,
})
local hatchEgg = label(hatchLayer, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0, 180, 0, 180),
	Text = "🥚",
	ZIndex = 31,
})
local hatchCard = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 300, 0, 300),
	BackgroundColor3 = C.cream,
	Visible = false,
	ZIndex = 31,
	Parent = hatchLayer,
})
corner(hatchCard, UDim.new(0, 20))
stroke(hatchCard, 4)
local hatchCircle = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.new(0, 110, 0, 110),
	BackgroundColor3 = C.green,
	ZIndex = 32,
	Parent = hatchCard,
})
corner(hatchCircle, UDim.new(1, 0))
label(hatchCircle, { Size = UDim2.fromScale(1, 1), Text = "🦖", ZIndex = 33 })
local hatchName = label(hatchCard, { Position = UDim2.new(0, 10, 0, 134), Size = UDim2.new(1, -20, 0, 34), ZIndex = 32 })
local hatchRarity = label(hatchCard, { Position = UDim2.new(0, 10, 0, 170), Size = UDim2.new(1, -20, 0, 26), ZIndex = 32 })
local hatchPower = label(hatchCard, { Position = UDim2.new(0, 10, 0, 198), Size = UDim2.new(1, -20, 0, 22), TextColor3 = Color3.fromRGB(90, 95, 80), ZIndex = 32 })
button(hatchCard, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(0, 160, 0, 50),
	BackgroundColor3 = C.green,
	Text = "Ура!",
	ZIndex = 33,
}, function()
	hatchLayer.Visible = false
end)

local hatching = false
local function hatch(eggKind: string)
	if hatching then
		return
	end
	local res = ask("hatch", eggKind)
	if not res.ok then
		toast(res.msg or "Не получилось")
		return
	end
	hatching = true
	hatchLayer.Visible = true
	hatchCard.Visible = false
	hatchEgg.Visible = true
	hatchEgg.Text = Config.EGGS[eggKind].icon
	hatchEgg.Rotation = 0
	for i = 1, 6 do
		local t = TweenService:Create(hatchEgg, TweenInfo.new(0.14), { Rotation = (i % 2 == 0) and -18 or 18 })
		t:Play()
		t.Completed:Wait()
		if i % 2 == 0 then
			playSound("crack")
		end
	end
	hatchEgg.Rotation = 0
	hatchEgg.Text = "💥"
	task.wait(0.35)
	hatchEgg.Visible = false
	local def = Config.PETS[res.pet]
	hatchCircle.BackgroundColor3 = PET_UI_COLORS[res.pet]
	hatchName.Text = def.name
	hatchRarity.Text = def.rarity
	hatchRarity.TextColor3 = Config.RARITY_COLORS[def.rarity]
	hatchPower.Text = def.power
	hatchCard.Size = UDim2.new(0, 120, 0, 120)
	hatchCard.Visible = true
	TweenService:Create(hatchCard, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = UDim2.new(0, 300, 0, 300) }):Play()
	playSound("win")
	speak("Ура! Новый питомец!")
	hatching = false
	if currentPanel then
		render()
	end
end

-- ---------- панели ----------

local builders = {}

function builders.pets()
	panelTitle.Text = "🐣 Питомцы"
	heading("Яйца")
	for _, kind in ipairs(Config.EGG_ORDER) do
		local egg = Config.EGGS[kind]
		local count = data.eggs[kind] or 0
		local r = row(52)
		label(r, { LayoutOrder = 1, Size = UDim2.new(0, 40, 0, 40), Text = egg.icon, ZIndex = 13 })
		label(r, { LayoutOrder = 2, Size = UDim2.new(1, -220, 0, 30), Text = egg.name .. "  ×" .. count, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
		button(r, {
			LayoutOrder = 3,
			Size = UDim2.new(0, 150, 0, 40),
			BackgroundColor3 = count > 0 and C.green or C.grey,
			Text = "Вылупить",
			ZIndex = 13,
		}, function()
			if count > 0 then
				hatch(kind)
			else
				toast("Унеси яйцо с поля или купи в магазине 🛒")
			end
		end)
	end
	note("Яйца приносишь с поля 🥚 или покупаешь в магазине 🛒")

	heading("Мои питомцы (" .. #data.pets .. "/" .. Config.MAX_PETS .. ")")
	if #data.pets == 0 then
		note("Пока никого нет. Вылупи яйцо!")
	end
	local rank = {}
	for i, k in ipairs(Config.PET_ORDER) do
		rank[k] = i
	end
	local list = sorted(data.pets, function(a, b)
		if rank[a.kind] ~= rank[b.kind] then
			return rank[a.kind] < rank[b.kind]
		end
		return a.id < b.id
	end)
	for _, pet in ipairs(list) do
		local def = Config.PETS[pet.kind]
		local on = data.equippedPet == pet.id
		local r = row(60)
		local icon = make("Frame", { LayoutOrder = 1, Size = UDim2.new(0, 44, 0, 44), BackgroundColor3 = PET_UI_COLORS[pet.kind], ZIndex = 13, Parent = r })
		corner(icon, UDim.new(1, 0))
		label(icon, { Size = UDim2.fromScale(1, 1), Text = "🦖", ZIndex = 14 })
		local info = make("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -330, 1, -8), BackgroundTransparency = 1, ZIndex = 13, Parent = r })
		label(info, { Size = UDim2.new(1, 0, 0.55, 0), Text = def.name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
		label(info, {
			Position = UDim2.fromScale(0, 0.55),
			Size = UDim2.new(1, 0, 0.45, 0),
			Text = def.rarity .. " · " .. def.power,
			TextColor3 = Config.RARITY_COLORS[def.rarity],
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		})
		button(r, {
			LayoutOrder = 3,
			Size = UDim2.new(0, 120, 0, 42),
			BackgroundColor3 = on and C.blue or C.gold,
			TextColor3 = on and C.cream or C.ink,
			Text = on and "Снять" or "Взять",
			ZIndex = 13,
		}, function()
			ask("equipPet", pet.id)
		end)
		local sure = false
		local releaseBtn
		releaseBtn = button(r, {
			LayoutOrder = 4,
			Size = UDim2.new(0, 120, 0, 42),
			BackgroundColor3 = C.paper,
			Text = "Отпустить +" .. def.release .. "🪙",
			ZIndex = 13,
		}, function()
			if not sure then
				sure = true
				releaseBtn.Text = "Точно? 🥺"
				releaseBtn.BackgroundColor3 = C.red
				task.delay(3, function()
					if releaseBtn.Parent then
						sure = false
						releaseBtn.Text = "Отпустить +" .. def.release .. "🪙"
						releaseBtn.BackgroundColor3 = C.paper
					end
				end)
				return
			end
			local res = ask("releasePet", pet.id)
			if res.msg then
				toast(res.msg)
			end
		end)
	end
end

function builders.shop()
	panelTitle.Text = "🛒 Магазин"
	note("Монетки дают за яйца, победы, спасение друзей и обби")
	for _, item in ipairs(Config.SHOP) do
		if not item.event or item.event == data.event then
			local owned = item.slot ~= "egg" and data.owned[item.id]
			local wearing = owned and data.equipped[item.slot] == item.id
			local r = row(56)
			label(r, { LayoutOrder = 1, Size = UDim2.new(0, 42, 0, 42), Text = item.icon, ZIndex = 13 })
			label(r, {
				LayoutOrder = 2,
				Size = UDim2.new(1, -230, 0, 30),
				Text = item.name .. (item.event and " (праздник!)" or ""),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
			})
			local text, color = "🪙 " .. item.price, C.gold
			if owned then
				text, color = wearing and "Снять" or "Надеть", wearing and C.blue or C.green
			end
			button(r, {
				LayoutOrder = 3,
				Size = UDim2.new(0, 160, 0, 42),
				BackgroundColor3 = color,
				TextColor3 = wearing and C.cream or C.ink,
				Text = text,
				ZIndex = 13,
			}, function()
				local res = owned and ask("equip", item.id) or ask("buy", item.id)
				if res.msg then
					toast(res.msg)
				end
			end)
		end
	end
end

function builders.daily()
	panelTitle.Text = "🎁 Подарок каждый день"
	note("Заходи каждый день подряд: подарок становится больше!")
	local grid = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 176), BackgroundTransparency = 1, ZIndex = 12, Parent = content })
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 74, 0, 82),
		CellPadding = UDim2.new(0, 8, 0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for day, coins in ipairs(Config.DAILY) do
		local claimed = day < data.dailyDay or (day == data.dailyDay and not data.dailyReady)
		local current = day == data.dailyDay and data.dailyReady
		local box = make("Frame", {
			LayoutOrder = day,
			BackgroundColor3 = current and C.gold or (claimed and C.green or C.paper),
			ZIndex = 13,
			Parent = grid,
		})
		corner(box)
		if current then
			stroke(box, 3)
		end
		label(box, { Size = UDim2.new(1, 0, 0.3, 0), Text = "День " .. day, ZIndex = 14 })
		label(box, { Position = UDim2.fromScale(0, 0.3), Size = UDim2.new(1, 0, 0.4, 0), Text = claimed and "✔" or (day == 7 and "🥚🪙" or "🪙"), ZIndex = 14 })
		label(box, { Position = UDim2.fromScale(0, 0.7), Size = UDim2.new(1, 0, 0.3, 0), Text = tostring(coins), ZIndex = 14 })
	end
	if data.dailyReady then
		local r = row(60)
		r.BackgroundTransparency = 1
		button(r, { Size = UDim2.new(1, -16, 0, 52), BackgroundColor3 = C.gold, Text = "Открыть подарок 🎁", ZIndex = 13 }, function()
			local res = ask("daily")
			if res.ok then
				showBig("🎁 " .. res.msg, 3)
				playSound("win")
			elseif res.msg then
				toast(res.msg)
			end
		end)
	else
		note("Следующий подарок через " .. formatWait(data.dailyWait))
	end
end

function builders.wheel()
	panelTitle.Text = "🎡 Колесо удачи"
	note("Крути раз в день!")
	local holder = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 280), BackgroundTransparency = 1, ZIndex = 12, Parent = content })
	local wheel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(0, 250, 0, 250),
		BackgroundColor3 = C.paper,
		ZIndex = 13,
		Parent = holder,
	})
	corner(wheel, UDim.new(1, 0))
	stroke(wheel, 4)
	label(holder, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 40, 0, 34), Text = "🔻", ZIndex = 15 })
	local chips = {}
	local colors = { C.gold, C.blue, C.green, C.red, C.purple, C.gold, C.blue, C.green }
	for i, seg in ipairs(Config.WHEEL) do
		local c = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 66, 0, 66), BackgroundColor3 = colors[i], ZIndex = 14, Parent = wheel })
		corner(c, UDim.new(1, 0))
		stroke(c, 2)
		label(c, { Size = UDim2.new(1, 0, 0.55, 0), Text = seg.icon, ZIndex = 15 })
		label(c, { Position = UDim2.fromScale(0.1, 0.55), Size = UDim2.new(0.8, 0, 0.32, 0), Text = seg.label, TextColor3 = C.cream, TextStrokeTransparency = 0.3, ZIndex = 15 })
		chips[i] = c
	end
	local step = 360 / #Config.WHEEL
	local function place(offset: number)
		for i, c in ipairs(chips) do
			local a = math.rad((i - 1) * step + offset)
			c.Position = UDim2.new(0.5 + 0.36 * math.sin(a), 0, 0.5 - 0.36 * math.cos(a), 0)
		end
	end
	place(0)

	local r = row(60)
	r.BackgroundTransparency = 1
	local spinning = false
	button(r, {
		Size = UDim2.new(1, -16, 0, 52),
		BackgroundColor3 = data.wheelReady and C.gold or C.grey,
		Text = data.wheelReady and "Крутить! 🎡" or ("Приходи через " .. formatWait(data.wheelWait)),
		ZIndex = 13,
	}, function()
		if spinning or not data.wheelReady then
			return
		end
		local res = ask("spin")
		if not res.ok then
			if res.msg then
				toast(res.msg)
			end
			return
		end
		spinning = true
		local final = 360 * 5 - (res.index - 1) * step
		local start = os.clock()
		local duration = 4
		while true do
			local t = math.min(1, (os.clock() - start) / duration)
			place(final * (1 - (1 - t) ^ 3))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		playSound("win")
		showBig("🎡 " .. res.msg, 3)
		spinning = false
		if currentPanel == "wheel" then
			render()
		end
	end)
end

function builders.badges()
	local got = 0
	for _, b in ipairs(Config.BADGES) do
		if data.badges[b.id] then
			got += 1
		end
	end
	panelTitle.Text = "🏅 Значки " .. got .. "/" .. #Config.BADGES
	local grid = make("Frame", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = content,
	})
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 120, 0, 112),
		CellPadding = UDim2.new(0, 8, 0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, b in ipairs(Config.BADGES) do
		local has = data.badges[b.id]
		local box = make("Frame", { LayoutOrder = i, BackgroundColor3 = has and C.gold or C.paper, ZIndex = 13, Parent = grid })
		corner(box)
		label(box, { Size = UDim2.new(1, 0, 0.45, 0), Text = has and b.icon or "🔒", ZIndex = 14 })
		label(box, { Position = UDim2.new(0.05, 0, 0.45, 0), Size = UDim2.new(0.9, 0, 0.22, 0), Text = b.name, ZIndex = 14 })
		label(box, {
			Position = UDim2.new(0.05, 0, 0.68, 0),
			Size = UDim2.new(0.9, 0, 0.28, 0),
			Text = b.text,
			TextColor3 = Color3.fromRGB(80, 85, 70),
			ZIndex = 14,
		})
	end
end

local codeText = ""
function builders.codes()
	panelTitle.Text = "🔑 Секретные коды"
	note("Знаешь секретное слово? Напиши его здесь!")
	local r = row(60)
	local box = make("TextBox", {
		LayoutOrder = 1,
		Size = UDim2.new(1, -170, 0, 44),
		BackgroundColor3 = C.cream,
		Font = FONT,
		TextScaled = true,
		TextColor3 = C.ink,
		PlaceholderText = "Код",
		Text = codeText,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = r,
	})
	corner(box)
	stroke(box, 2)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		codeText = box.Text
	end)
	button(r, { LayoutOrder = 2, Size = UDim2.new(0, 150, 0, 44), BackgroundColor3 = C.green, Text = "Проверить", ZIndex = 13 }, function()
		local res = ask("code", box.Text)
		if res.ok then
			showBig("🔑 " .. res.msg, 3)
			codeText = ""
			box.Text = ""
		elseif res.msg then
			toast(res.msg)
		end
	end)
end

local function playEmote(emote)
	if emote.id == "tongue" or emote.id == "fart" then
		ask(emote.id)
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (hum and animator) then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = emote.anim
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = emote.id == "dance"
	track:Play()
	task.spawn(function()
		local start = os.clock()
		task.wait(0.3)
		while track.IsPlaying and os.clock() - start < 6 do
			if hum.MoveDirection.Magnitude > 0.1 then
				break
			end
			task.wait(0.1)
		end
		track:Stop()
	end)
end

function builders.emotes()
	panelTitle.Text = "😀 Эмоции"
	local grid = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 260), BackgroundTransparency = 1, ZIndex = 12, Parent = content })
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 120, 0, 120),
		CellPadding = UDim2.new(0, 10, 0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, e in ipairs(Config.EMOTES) do
		button(grid, { LayoutOrder = i, BackgroundColor3 = C.paper, Text = e.icon .. "\n" .. e.name, ZIndex = 13 }, function()
			closePanel()
			playEmote(e)
		end)
	end
end

render = function()
	if not currentPanel then
		return
	end
	clearContent()
	if not data then
		panelTitle.Text = "Загрузка…"
		return
	end
	builders[currentPanel]()
	if not data.saving then
		note("ℹ️ Прогресс сейчас не сохраняется (так бывает при тесте в Studio)")
	end
end

-- ---------- большие кнопки слева ----------

local side = make("Frame", {
	Position = UDim2.new(0, 10, 0, 54),
	Size = UDim2.new(0, 136, 0, 280),
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIGridLayout", { CellSize = UDim2.new(0, 64, 0, 64), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
local dots = {}
local function sideButton(index: number, icon: string, caption: string, color: Color3, panelName: string, onClick: (() -> ())?)
	local b = button(side, { LayoutOrder = index, BackgroundColor3 = color, Text = "" }, function()
		if onClick then
			onClick()
		else
			openPanel(panelName)
		end
	end)
	local iconLabel = label(b, { Name = "Icon", Size = UDim2.new(1, 0, 0.68, 0), Text = icon })
	label(b, { Position = UDim2.fromScale(0, 0.68), Size = UDim2.new(1, 0, 0.32, 0), Text = caption })
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundColor3 = C.red,
		Visible = false,
		Parent = b,
	})
	corner(dot, UDim.new(1, 0))
	stroke(dot, 2, C.cream)
	dots[panelName] = dot
	return iconLabel
end
sideButton(1, "🐣", "Питомцы", C.green, "pets")
sideButton(2, "🛒", "Магазин", C.gold, "shop")
sideButton(3, "🎁", "Подарок", C.red, "daily")
sideButton(4, "🎡", "Колесо", C.purple, "wheel")
sideButton(5, "🏅", "Значки", C.blue, "badges")
sideButton(6, "🔑", "Коды", C.paper, "codes")
sideButton(7, "😀", "Эмоции", C.cream, "emotes")
local musicOn = true
local musicIcon: TextLabel
musicIcon = sideButton(8, "🎵", "Музыка", C.paper, "music", function()
	musicOn = not musicOn
	musicIcon.Text = musicOn and "🎵" or "🔇"
	toast(musicOn and "🎵 Музыка включена" or "🔇 Музыка выключена")
end)

-- ---------- кнопки динозавра ----------

local dinoPad = make("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -190),
	Size = UDim2.new(0, 230, 0, 100),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = dinoPad })
local cooldowns = { roar = 0, dash = 0 }
local dinoButtons = {}
local function dinoAction(action: string)
	if not isDino or os.clock() < cooldowns[action] then
		return
	end
	local res = ask(action)
	if res.ok then
		cooldowns[action] = os.clock() + (res.cooldown or 5)
	elseif res.wait then
		cooldowns[action] = os.clock() + res.wait
	end
end
local function dinoButton(action: string, icon: string, caption: string, color: Color3)
	local b = button(dinoPad, { Size = UDim2.new(0, 100, 0, 100), BackgroundColor3 = color, Text = "" }, function()
		dinoAction(action)
	end)
	corner(b, UDim.new(1, 0))
	label(b, { Size = UDim2.new(1, 0, 0.6, 0), Text = icon })
	local cap = label(b, { Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.3, 0), Text = caption, TextColor3 = C.cream, TextStrokeTransparency = 0.3 })
	dinoButtons[action] = { button = b, caption = cap, text = caption }
end
dinoButton("roar", "🦖", "РЫК (Q)", C.red)
dinoButton("dash", "💨", "РЫВОК (F)", C.blue)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		dinoAction("roar")
	elseif input.KeyCode == Enum.KeyCode.F then
		dinoAction("dash")
	end
end)

local function setDino(on: boolean)
	isDino = on
	dinoPad.Visible = on
	dinoBanner.Visible = on
end


-- ---------- музыка ----------
-- Мелодии играются нотами из встроенного звука Roblox, поэтому чужие аудио не нужны.

local NOTE_INDEX = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local function parseLine(line: string): { number | boolean }
	local out = {}
	for tok in line:gmatch("%S+") do
		if tok == "-" then
			table.insert(out, false)
		else
			local letter, acc, octave = tok:match("^(%a)([#b]?)(%d)$")
			local n = 12 * (tonumber(octave) :: number + 1) + NOTE_INDEX[letter] + (acc == "#" and 1 or acc == "b" and -1 or 0)
			table.insert(out, n)
		end
	end
	return out
end

local SONGS = {
	-- весёлая прыгучая для Динопарка
	lobby = {
		bpm = 132,
		melody = parseLine("C5 - E5 G5 C6 - G5 E5 F5 - A5 F5 G5 - - - E5 - G5 E5 D5 - C5 D5 E5 - D5 B4 C5 - - -"),
		bass = parseLine("C3 - G3 - C3 - G3 - F3 - C4 - G3 - D3 - C3 - G3 - A3 - E3 - F3 - G3 - C3 - G3 -"),
	},
	-- быстрая приключенческая для игры
	round = {
		bpm = 152,
		melody = parseLine("A4 C5 E5 A5 G5 E5 C5 E5 F5 A5 C6 A5 G5 E5 D5 E5 A4 C5 E5 A5 B5 A5 G5 E5 F5 E5 D5 B4 A4 - - -"),
		bass = parseLine("A2 - A3 - A2 - A3 - F2 - F3 - F2 - F3 - C3 - C4 - G2 - G3 - E2 - E3 - A2 - A2 -"),
	},
	-- тревожная, когда приходит Ти-Рекс
	boss = {
		bpm = 176,
		melody = parseLine("E5 - E5 F5 E5 - D#5 - E5 - G5 - F5 - D#5 -"),
		bass = parseLine("E2 E3 E2 E3 E2 E3 F2 F3 E2 E3 E2 E3 G2 G3 F2 F3"),
	},
}
local JINGLE = parseLine("C5 E5 G5 C6 - G5 C6 C6")

local notePool = {}
for i = 1, 12 do
	local snd = Instance.new("Sound")
	snd.SoundId = Config.SOUNDS.note.id
	snd.Parent = SoundService
	notePool[i] = snd
end
local poolIndex = 0
local function playNote(midi: number, volume: number)
	poolIndex = poolIndex % #notePool + 1
	local snd = notePool[poolIndex]
	snd.PlaybackSpeed = 2 ^ ((midi - 72) / 12)
	snd.Volume = volume
	snd.TimePosition = 0
	snd:Play()
end

local jinglePlaying = false
playJingle = function()
	if jinglePlaying then
		return
	end
	jinglePlaying = true
	task.spawn(function()
		for _, n in ipairs(JINGLE) do
			if n then
				playNote(n :: number, Config.MUSIC_VOLUME * 1.6)
			end
			task.wait(0.15)
		end
		task.wait(0.4)
		jinglePlaying = false
	end)
end

local function songName(): string
	if remotes:GetAttribute("Boss") then
		return "boss"
	end
	return (remotes:GetAttribute("TimeLeft") or -1) >= 0 and "round" or "lobby"
end

task.spawn(function()
	local playing: string? = nil
	local custom: Sound? = nil
	local step = 0
	local nextT = os.clock()
	while true do
		local name = musicOn and songName() or nil
		if name ~= playing then
			playing = name
			step = 0
			if custom then
				custom:Destroy()
				custom = nil
			end
			local id = name and Config.MUSIC[name] or ""
			if id ~= "" then
				local snd = Instance.new("Sound")
				snd.SoundId = id
				snd.Looped = true
				snd.Volume = Config.MUSIC_VOLUME
				snd.Parent = SoundService
				snd:Play()
				custom = snd
			end
		end
		local song = name and SONGS[name]
		if song and not custom and not jinglePlaying then
			step += 1
			local m = song.melody[(step - 1) % #song.melody + 1]
			local b = song.bass[(step - 1) % #song.bass + 1]
			if m then
				playNote(m :: number, Config.MUSIC_VOLUME)
			end
			if b then
				playNote(b :: number, Config.MUSIC_VOLUME * 0.8)
			end
		end
		nextT += song and 60 / song.bpm / 2 or 0.25
		local wait = nextT - os.clock()
		if wait < -0.5 then
			nextT = os.clock()
			wait = 0
		end
		task.wait(math.max(0, wait))
	end
end)

-- ---------- шалости в Динопарке: батуты, бананы, горка, пукалки, грибы ----------

local BOUNCE_WORDS = { "Уиии! 🤸", "Выше неба! ☁️", "Я птица! 🐦", "Йу-ху! 🚀" }
local cool = { bounce = 0, slip = 0, fart = 0, mushroom = 0, slide = 0 }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function near(root: BasePart, p: BasePart, radius: number, height: number): boolean
	local d = Vector3.new(root.Position.X - p.Position.X, 0, root.Position.Z - p.Position.Z).Magnitude
	return d < radius and math.abs(root.Position.Y - p.Position.Y) < height
end

local function slip(hum: Humanoid, root: BasePart)
	cool.slip = os.clock() + 3
	playSound("slip")
	toast("Ой! Банан! 🍌😂")
	hum.PlatformStand = true
	root.AssemblyLinearVelocity = root.CFrame.LookVector * 25 + Vector3.new(0, 18, 0)
	root.AssemblyAngularVelocity = root.CFrame.RightVector * 10
	task.delay(1.3, function()
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	for _, p in ipairs(CollectionService:GetTagged("Trampoline")) do
		if now > cool.bounce and near(root, p, 3.4, 5) then
			cool.bounce = now + 0.5
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, 95, v.Z)
			playSound("boing")
			if math.random() < 0.3 then
				toast(BOUNCE_WORDS[math.random(#BOUNCE_WORDS)])
			end
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Banana")) do
		if now > cool.slip and near(root, p, 1.8, 4) then
			slip(hum, root)
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Fart")) do
		if now > cool.fart and near(root, p, 2.4, 4) then
			cool.fart = now + 2.5
			task.spawn(ask, "fart")
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Mushroom")) do
		if now > cool.mushroom and near(root, p, 3, 5) then
			cool.mushroom = now + 5
			task.spawn(ask, "mushroom", p:GetAttribute("Kind"))
		end
	end
	rayParams.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), rayParams)
	if hit and CollectionService:HasTag(hit.Instance, "Slide") then
		local dir = hit.Instance:GetAttribute("Dir")
		if typeof(dir) == "Vector3" then
			root.AssemblyLinearVelocity = dir * 55
		end
		if now > cool.slide then
			cool.slide = now + 3
			toast("Уииии! 🛝")
			playSound("swoosh")
		end
	end
end)

-- ---------- данные и события с сервера ----------

local function onData(view)
	local first = data == nil
	data = view
	coinsLabel.Text = "🪙 " .. view.coins
	dots.daily.Visible = view.dailyReady
	dots.wheel.Visible = view.wheelReady
	local eggs = 0
	for _, n in pairs(view.eggs) do
		eggs += n
	end
	dots.pets.Visible = eggs > 0
	if first and view.dailyReady then
		toast("🎁 Тебя ждёт подарок! Нажми кнопку «Подарок»")
	end
	if currentPanel and currentPanel ~= "codes" and not hatching then
		render()
	end
end

local shakeUntil = 0
Notify.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "data" then
		onData(payload)
	elseif kind == "toast" then
		toast(payload)
	elseif kind == "big" then
		showBig(payload.text, payload.seconds or 2.5)
	elseif kind == "voice" then
		speak(payload)
	elseif kind == "sound" then
		playSound(payload)
	elseif kind == "badge" then
		showBig("🏅 Новый значок: " .. payload.icon .. " " .. payload.name, 3)
	elseif kind == "panel" then
		openPanel(payload)
	elseif kind == "role" then
		setDino(payload.dino)
	elseif kind == "shake" then
		shakeUntil = os.clock() + 0.6 * (payload or 1)
	end
end)

task.spawn(function()
	local view = ask("getData")
	if view and view.coins then
		onData(view)
	end
end)

-- ---------- табло, лёд, тряска ----------

task.spawn(function()
	while true do
		local timeLeft = remotes:GetAttribute("TimeLeft") or -1
		humansChip.Text = "👫 Люди " .. (remotes:GetAttribute("Humans") or 0)
		dinosChip.Text = "🦖 Дино " .. (remotes:GetAttribute("Dinos") or 0)
		if timeLeft >= 0 then
			timeChip.Text = string.format("%d:%02d", timeLeft // 60, timeLeft % 60)
			local line = "🗺 " .. (remotes:GetAttribute("Map") or "")
			local dp = remotes:GetAttribute("DinoPlayer")
			if dp and dp ~= "" then
				line ..= "   🦖 " .. dp
			end
			if remotes:GetAttribute("Boss") then
				line ..= "   ⚠️ Ти-Рекс!"
			end
			statusLine.Text = line
		else
			timeChip.Text = "⏳"
			statusLine.Text = remotes:GetAttribute("Status") or ""
		end
		for action, b in pairs(dinoButtons) do
			local left = cooldowns[action] - os.clock()
			b.caption.Text = left > 0 and tostring(math.ceil(left)) or b.text
			b.button.BackgroundTransparency = left > 0 and 0.4 or 0
		end
		task.wait(0.2)
	end
end)

local slide = Vector3.zero
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hum and root) then
		return
	end

	-- на льду скользишь
	if remotes:GetAttribute("Theme") == "ice" and hum.FloorMaterial == Enum.Material.Ice then
		local want = hum.MoveDirection * hum.WalkSpeed
		slide = slide:Lerp(want, math.min(1, dt * 2.2))
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(slide.X, v.Y, slide.Z)
	else
		local v = root.AssemblyLinearVelocity
		slide = Vector3.new(v.X, 0, v.Z)
	end

	-- тряска экрана от Ти-Рекса и рыка
	if os.clock() < shakeUntil then
		hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.8
	elseif hum.CameraOffset.Magnitude > 0 then
		hum.CameraOffset = Vector3.zero
	end
end)
