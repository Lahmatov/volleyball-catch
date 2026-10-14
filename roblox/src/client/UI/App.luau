-- Весь экран игрока на Vide (https://github.com/centau/vide): табло, сообщения, окна,
-- вылупление, колесо, кнопки динозавра. Работает от «источников» (source): поменял данные —
-- экран обновился сам. Без Roblox-сервисов: всё внешнее приходит в deps, поэтому экран
-- можно тестировать в Lune (tests/roblox/ui.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("vide"))
local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Logic = require(script.Parent.Logic)

local create, source, derive, show, switch, indexes, spring, changed, root =
	vide.create, vide.source, vide.derive, vide.show, vide.switch, vide.indexes, vide.spring, vide.changed, vide.root

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
	muted = Color3.fromRGB(90, 95, 80),
}
local FONT = Enum.Font.FredokaOne
local PET_COLORS = {
	green = Config.DINOS.green.color,
	red = Config.DINOS.red.color,
	gold = Config.DINOS.gold.color,
	rainbow = Color3.fromRGB(230, 90, 200),
}
local TITLES = {
	pets = "🐣 Питомцы",
	shop = "🛒 Магазин",
	daily = "🎁 Подарок каждый день",
	wheel = "🎡 Колесо удачи",
	badges = "🏅 Значки",
	codes = "🔑 Секретные коды",
	emotes = "😀 Эмоции",
}

-- плавное «выпрыгивание» с лёгким перелётом (t от 0 до 1)
local function popOut(t: number): number
	t = math.clamp(t, 0, 1) - 1
	return 1 + 2.70158 * t ^ 3 + 1.70158 * t ^ 2
end

-- склеить свойства: строки из обоих, дети (числа) — сначала base, потом extra
local function merge(base, extra)
	local out = {}
	for k, v in pairs(base) do
		if type(k) == "string" then
			out[k] = v
		end
	end
	for k, v in pairs(extra or {}) do
		if type(k) == "string" then
			out[k] = v
		end
	end
	for _, v in ipairs(base) do
		table.insert(out, v)
	end
	for _, v in ipairs(extra or {}) do
		table.insert(out, v)
	end
	return out
end

local function Corner(r: UDim?)
	return create "UICorner" { CornerRadius = r or UDim.new(0, 12) }
end

local function Stroke(thickness: number?, color: Color3?)
	return create "UIStroke" { Thickness = thickness or 3, Color = color or C.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
end

local function Pad(x: number, y: number?)
	return create "UIPadding" {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	}
end

local function Label(props)
	return create "TextLabel"(merge({ BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = C.ink }, props))
end

local App = {}

function App.new(deps)
	deps = deps or {}
	local ask = deps.ask or function()
		return { ok = false }
	end
	local sound = deps.sound or function() end
	local speak = deps.speak or function() end
	local emote = deps.emote or function() end
	local delay = deps.delay or function(seconds, fn)
		task.delay(seconds, fn)
	end

	-- ---------- состояние экрана ----------
	local now = source(0)
	local data = source(nil :: any)
	local hud = source({ humans = 0, dinos = 0, timeLeft = -1, status = "", map = "", dinoPlayer = "", boss = false })
	local panel = source(nil :: string?)
	local toasts = source({})
	local big = source(nil :: any)
	local isDino = source(false)
	local cooldowns = source({ roar = 0, dash = 0 })
	local hatching = source(nil :: any)
	local spin = source(nil :: any)
	local codeText = source("")
	-- телефон: экран низкий или узкий — всё компактнее и подальше от джойстика и прыжка
	local viewport = source({ w = 1280, h = 720 })
	local function compact()
		local v = viewport()
		return v.h < 500 or v.w < 700
	end

	local api = {}

	-- кнопка, которая пружинит при нажатии
	local function Button(props)
		local pressed = source(false)
		local onClick = props.onClick
		local p = table.clone(props)
		p.onClick = nil
		local round = p.round
		p.round = nil
		return create "TextButton"(merge({
			Font = FONT,
			TextScaled = true,
			TextColor3 = C.ink,
			BackgroundColor3 = C.gold,
			AutoButtonColor = false,
			Activated = function()
				sound("pickup")
				onClick()
			end,
			MouseButton1Down = function()
				pressed(true)
			end,
			MouseButton1Up = function()
				pressed(false)
			end,
			MouseLeave = function()
				pressed(false)
			end,
			Corner(round and UDim.new(1, 0) or nil),
			Stroke(2),
			Pad(6, 4),
			create "UIScale" {
				Scale = spring(function()
					return pressed() and 0.88 or 1
				end, 0.25, 0.45),
			},
		}, p))
	end

	local function Heading(text)
		return Label { Size = UDim2.new(1, 0, 0, 30), Text = text, TextXAlignment = Enum.TextXAlignment.Left }
	end

	local function Note(text)
		return Label { Size = UDim2.new(1, 0, 0, 22), Text = text, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left }
	end

	local function Row(height: number, children)
		return create "Frame"(merge({
			Size = UDim2.new(1, -8, 0, height),
			BackgroundColor3 = C.paper,
			Corner(),
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Pad(8, 0),
		}, children))
	end

	local function Column(children)
		return create "Frame"(merge({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create "UIListLayout" { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
		}, children))
	end

	local function Grid(cell: UDim2, children)
		return create "Frame"(merge({
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create "UIGridLayout" {
				CellSize = cell,
				CellPadding = UDim2.new(0, 8, 0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		}, children))
	end

	-- ---------- действия ----------

	function api.toast(text: string)
		local list = table.clone(toasts())
		table.insert(list, { text = text, untilT = now() + 3.5 })
		while #list > (compact() and 2 or 4) do
			table.remove(list, 1)
		end
		toasts(list)
	end

	function api.big(text: string, seconds: number?)
		big({ text = text, started = now(), untilT = now() + (seconds or 2.5) })
	end

	function api.open(name: string)
		panel(name)
	end

	function api.close()
		panel(nil)
	end

	function api.setData(view)
		local first = data() == nil
		data(view)
		if first and view.dailyReady then
			api.toast("🎁 Тебя ждёт подарок! Нажми «Подарок»")
		end
	end

	function api.setViewport(w: number, h: number)
		viewport({ w = w, h = h })
	end

	function api.setHud(h)
		hud(h)
	end

	function api.setDino(on: boolean)
		isDino(on)
	end

	function api.dinoAction(action: string)
		if not isDino() or now() < cooldowns()[action] then
			return
		end
		local res = ask(action)
		local cd = table.clone(cooldowns())
		if res.ok then
			cd[action] = now() + (res.cooldown or 5)
		elseif res.wait then
			cd[action] = now() + res.wait
		end
		cooldowns(cd)
	end

	function api.hatch(eggKind: string)
		if hatching() then
			return
		end
		local res = ask("hatch", eggKind)
		if not res.ok then
			api.toast(res.msg or "Не получилось")
			return
		end
		hatching({ egg = eggKind, pet = res.pet, started = now(), cracks = 0 })
	end

	function api.spin()
		local s = spin()
		local d = data()
		if (s and not s.done) or not (d and d.wheelReady) then
			return
		end
		local res = ask("spin")
		if not res.ok then
			api.toast(res.msg or "Не получилось")
			return
		end
		spin({ index = res.index, final = Logic.wheelFinal(res.index, #Config.WHEEL), started = now(), msg = res.msg })
	end

	-- время идёт: убираем старые сообщения, двигаем вылупление и колесо
	function api.tick(t: number)
		now(t)
		local list = toasts()
		if #list > 0 and list[1].untilT < t then
			local keep = {}
			for _, item in ipairs(list) do
				if item.untilT >= t then
					table.insert(keep, item)
				end
			end
			toasts(keep)
		end
		local b = big()
		if b and t > b.untilT then
			big(nil)
		end
		local h = hatching()
		if h then
			local age = t - h.started
			local cracks = age >= 1.2 and 2 or (age >= 0.6 and 1 or 0)
			for _ = h.cracks + 1, cracks do
				sound("crack") -- даже если кадр подвис, каждая трещина звучит
			end
			h.cracks = math.max(h.cracks, cracks)
			if age >= 1.5 and not h.revealed then
				h.revealed = true
				sound("win")
				speak("Ура! Новый питомец!")
			end
		end
		local s = spin()
		if s and not s.done and t - s.started >= 4 then
			local done = table.clone(s)
			done.done = true
			spin(done)
			sound("win")
			api.big("🎡 " .. s.msg, 3)
		end
	end

	-- ---------- окна ----------

	local Panels = {}

	function Panels.pets()
		local eggRows = derive(function()
			return Logic.eggRows(data(), Config)
		end)
		local petRows = derive(function()
			return Logic.petRows(data(), Config)
		end)
		return Column {
			Heading "Яйца",
			indexes(eggRows, function(row)
				return Row(52, {
					Label { Size = UDim2.new(0, 40, 0, 40), Text = function()
						return row().icon
					end },
					Label { Size = UDim2.new(1, -220, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = function()
						return row().text
					end },
					Button {
						Size = UDim2.new(0, 150, 0, 40),
						Text = "Вылупить",
						BackgroundColor3 = function()
							return row().canHatch and C.green or C.grey
						end,
						onClick = function()
							if row().canHatch then
								api.hatch(row().kind)
							else
								api.toast("Унеси яйцо с поля или купи в магазине 🛒")
							end
						end,
					},
				})
			end),
			Note "Яйца приносишь с поля 🥚 или покупаешь в магазине 🛒",
			Heading(function()
				return "Мои питомцы (" .. #data().pets .. "/" .. Config.MAX_PETS .. ")"
			end),
			show(function()
				return #data().pets == 0
			end, function()
				return Note "Пока никого нет. Вылупи яйцо!"
			end),
			indexes(petRows, function(row)
				local sure = source(false)
				return Row(60, {
					create "Frame" {
						Size = UDim2.new(0, 44, 0, 44),
						BackgroundColor3 = function()
							return PET_COLORS[row().kind]
						end,
						Corner(UDim.new(1, 0)),
						Label { Size = UDim2.fromScale(1, 1), Text = "🦖" },
					},
					create "Frame" {
						Size = UDim2.new(1, -330, 1, -8),
						BackgroundTransparency = 1,
						Label { Size = UDim2.new(1, 0, 0.55, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = function()
							return row().name
						end },
						Label {
							Position = UDim2.fromScale(0, 0.55),
							Size = UDim2.new(1, 0, 0.45, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = function()
								return row().info
							end,
							TextColor3 = function()
								return Config.RARITY_COLORS[row().rarity]
							end,
						},
					},
					Button {
						Size = UDim2.new(0, 120, 0, 42),
						Text = function()
							return row().worn and "Снять" or "Взять"
						end,
						BackgroundColor3 = function()
							return row().worn and C.blue or C.gold
						end,
						TextColor3 = function()
							return row().worn and C.cream or C.ink
						end,
						onClick = function()
							ask("equipPet", row().id)
						end,
					},
					Button {
						Size = UDim2.new(0, 120, 0, 42),
						Text = function()
							return sure() and "Точно? 🥺" or ("Отпустить +" .. row().release .. "🪙")
						end,
						BackgroundColor3 = function()
							return sure() and C.red or C.paper
						end,
						onClick = function()
							if not sure() then
								sure(true)
								delay(3, function()
									sure(false)
								end)
								return
							end
							local res = ask("releasePet", row().id)
							if res.msg then
								api.toast(res.msg)
							end
						end,
					},
				})
			end),
		}
	end

	function Panels.shop()
		local rows = derive(function()
			return Logic.shopRows(data(), Config)
		end)
		local colors = { wearing = C.blue, owned = C.green, price = C.gold }
		return Column {
			Note "Монетки дают за яйца, победы, спасение друзей и обби",
			indexes(rows, function(row)
				return Row(56, {
					Label { Size = UDim2.new(0, 42, 0, 42), Text = function()
						return row().icon
					end },
					Label { Size = UDim2.new(1, -230, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = function()
						return row().name
					end },
					Button {
						Size = UDim2.new(0, 160, 0, 42),
						Text = function()
							return row().button
						end,
						BackgroundColor3 = function()
							return colors[row().state]
						end,
						TextColor3 = function()
							return row().state == "wearing" and C.cream or C.ink
						end,
						onClick = function()
							local res = ask(row().action, row().id)
							if res.msg then
								api.toast(res.msg)
							end
						end,
					},
				})
			end),
		}
	end

	function Panels.daily()
		local boxes = derive(function()
			return Logic.dailyBoxes(data(), Config)
		end)
		local colors = { today = C.gold, claimed = C.green, later = C.paper }
		return Column {
			Note "Заходи каждый день подряд: подарок становится больше!",
			Grid(UDim2.new(0, 74, 0, 82), {
				indexes(boxes, function(box)
					return create "Frame" {
						BackgroundColor3 = function()
							return colors[box().state]
						end,
						Corner(),
						Label { Size = UDim2.new(1, 0, 0.3, 0), Text = function()
							return "День " .. box().day
						end },
						Label { Position = UDim2.fromScale(0, 0.3), Size = UDim2.new(1, 0, 0.4, 0), Text = function()
							return box().icon
						end },
						Label { Position = UDim2.fromScale(0, 0.7), Size = UDim2.new(1, 0, 0.3, 0), Text = function()
							return tostring(box().coins)
						end },
					}
				end),
			}),
			show(function()
				return data().dailyReady
			end, function()
				return Button {
					Size = UDim2.new(1, -16, 0, 52),
					Text = "Открыть подарок 🎁",
					onClick = function()
						local res = ask("daily")
						if res.ok then
							api.big("🎁 " .. res.msg, 3)
							sound("win")
						elseif res.msg then
							api.toast(res.msg)
						end
					end,
				}
			end, function()
				return Note(function()
					return "Следующий подарок через " .. Logic.formatWait(data().dailyWait)
				end)
			end),
		}
	end

	function Panels.wheel()
		local n = #Config.WHEEL
		local colors = { C.gold, C.blue, C.green, C.red, C.purple, C.gold, C.blue, C.green }
		local angle = derive(function()
			local s = spin()
			if not s then
				return 0
			end
			return Logic.wheelAngle(s.final, (now() - s.started) / 4)
		end)
		local chips = {}
		for i, seg in ipairs(Config.WHEEL) do
			table.insert(chips, create "Frame" {
				Name = "Chip" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, 66, 0, 66),
				BackgroundColor3 = colors[(i - 1) % #colors + 1],
				Position = function()
					local x, y = Logic.wheelChip(i, n, angle())
					return UDim2.fromScale(x, y)
				end,
				Corner(UDim.new(1, 0)),
				Stroke(2),
				Label { Size = UDim2.new(1, 0, 0.55, 0), Text = seg.icon },
				Label { Position = UDim2.fromScale(0.1, 0.55), Size = UDim2.new(0.8, 0, 0.32, 0), Text = seg.label, TextColor3 = C.cream },
			})
		end
		return Column {
			Note "Крути раз в день!",
			create "Frame" {
				Size = UDim2.new(1, 0, 0, 280),
				BackgroundTransparency = 1,
				Label { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 40, 0, 34), Text = "🔻", ZIndex = 3 },
				create "Frame"(merge({
					Name = "Wheel",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 24),
					Size = UDim2.new(0, 250, 0, 250),
					BackgroundColor3 = C.paper,
					Corner(UDim.new(1, 0)),
					Stroke(4),
				}, chips)),
			},
			Button {
				Size = UDim2.new(1, -16, 0, 52),
				Text = function()
					local s = spin()
					if s and not s.done then
						return "Крутится… 🎡"
					end
					return data().wheelReady and "Крутить! 🎡" or ("Приходи через " .. Logic.formatWait(data().wheelWait))
				end,
				BackgroundColor3 = function()
					return data().wheelReady and C.gold or C.grey
				end,
				onClick = api.spin,
			},
		}
	end

	function Panels.badges()
		local rows = derive(function()
			local out = {}
			for _, b in ipairs(Config.BADGES) do
				table.insert(out, { icon = b.icon, name = b.name, text = b.text, has = data().badges[b.id] == true })
			end
			return out
		end)
		return Grid(UDim2.new(0, 120, 0, 112), {
			indexes(rows, function(b)
				return create "Frame" {
					BackgroundColor3 = function()
						return b().has and C.gold or C.paper
					end,
					Corner(),
					Label { Size = UDim2.new(1, 0, 0.45, 0), Text = function()
						return b().has and b().icon or "🔒"
					end },
					Label { Position = UDim2.new(0.05, 0, 0.45, 0), Size = UDim2.new(0.9, 0, 0.22, 0), Text = function()
						return b().name
					end },
					Label { Position = UDim2.new(0.05, 0, 0.68, 0), Size = UDim2.new(0.9, 0, 0.28, 0), TextColor3 = C.muted, Text = function()
						return b().text
					end },
				}
			end),
		})
	end

	function Panels.codes()
		local box = create "TextBox" {
			Name = "CodeBox",
			Size = UDim2.new(1, -170, 0, 44),
			BackgroundColor3 = C.cream,
			Font = FONT,
			TextScaled = true,
			TextColor3 = C.ink,
			PlaceholderText = "Код",
			Text = codeText(),
			ClearTextOnFocus = false,
			changed("Text", codeText),
			Corner(),
			Stroke(2),
		}
		return Column {
			Note "Знаешь секретное слово? Напиши его здесь!",
			Row(60, {
				box,
				Button {
					Size = UDim2.new(0, 150, 0, 44),
					BackgroundColor3 = C.green,
					Text = "Проверить",
					onClick = function()
						local res = ask("code", codeText())
						if res.ok then
							api.big("🔑 " .. res.msg, 3)
							box.Text = ""
						elseif res.msg then
							api.toast(res.msg)
						end
					end,
				},
			}),
		}
	end

	function Panels.emotes()
		local buttons = {}
		for _, e in ipairs(Config.EMOTES) do
			table.insert(buttons, Button {
				BackgroundColor3 = C.paper,
				Text = e.icon .. "\n" .. e.name,
				onClick = function()
					api.close()
					emote(e)
				end,
			})
		end
		return Grid(UDim2.new(0, 120, 0, 120), buttons)
	end

	-- ---------- части экрана ----------

	local function Hud()
		local function chip(name, width, bg, fg, text)
			return Label {
				Name = name,
				Size = UDim2.new(width, -6, 1, -8),
				BackgroundColor3 = bg or C.cream,
				BackgroundTransparency = bg and 0 or 1,
				TextColor3 = fg,
				Text = text,
				Corner(UDim.new(1, 0)),
			}
		end
		return {
			create "Frame" {
				Name = "Hud",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = function()
					return UDim2.new(0.5, 0, 0, compact() and 2 or 6)
				end,
				Size = function()
					return compact() and UDim2.new(0.55, 0, 0, 30) or UDim2.new(0.7, 0, 0, 46)
				end,
				BackgroundColor3 = C.cream,
				Corner(),
				Stroke(),
				create "UISizeConstraint" { MaxSize = Vector2.new(560, 46), MinSize = Vector2.new(260, 0) },
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				chip("Humans", 0.28, C.blue, C.cream, function()
					return "👫 Люди " .. hud().humans
				end),
				chip("Time", 0.18, nil, C.ink, function()
					local h = hud()
					return h.timeLeft >= 0 and Logic.formatTime(h.timeLeft) or "⏳"
				end),
				chip("Dinos", 0.28, C.red, C.cream, function()
					return "🦖 Дино " .. hud().dinos
				end),
				chip("Coins", 0.22, C.gold, C.ink, function()
					local d = data()
					return "🪙 " .. (d and d.coins or 0)
				end),
			},
			Label {
				Name = "Status",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = function()
					return UDim2.new(0.5, 0, 0, compact() and 34 or 56)
				end,
				Size = function()
					return compact() and UDim2.new(0.45, 0, 0, 14) or UDim2.new(0.6, 0, 0, 24)
				end,
				TextColor3 = C.cream,
				TextStrokeTransparency = 0,
				Text = function()
					return Logic.statusLine(hud())
				end,
			},
			show(isDino, function()
				return Label {
					Name = "DinoBanner",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = function()
						return UDim2.new(0.5, 0, 0, compact() and 50 or 82)
					end,
					Size = function()
						return compact() and UDim2.new(0.3, 0, 0, 18) or UDim2.new(0.5, 0, 0, 30)
					end,
					BackgroundColor3 = C.red,
					BackgroundTransparency = 0,
					TextColor3 = C.cream,
					Text = "🦖 Ты динозавр! Лови людей!",
					Corner(UDim.new(1, 0)),
				}
			end),
		}
	end

	local function BigText()
		return show(big, function()
			return Label {
				Name = "Big",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.3, 0),
				Size = function()
					return compact() and UDim2.new(0.6, 0, 0, 40) or UDim2.new(0.8, 0, 0, 64)
				end,
				TextColor3 = C.cream,
				TextStrokeTransparency = 0,
				ZIndex = 5,
				Text = function()
					local b = big()
					return b and b.text or ""
				end,
				create "UIScale" {
					Scale = function()
						local b = big()
						return b and math.max(0.05, popOut((now() - b.started) / 0.35)) or 1
					end,
				},
			}
		end)
	end

	local function Toasts()
		return create "Frame" {
			Name = "Toasts",
			-- на телефоне внизу джойстик и прыжок, поэтому сообщения наверху, под табло
			AnchorPoint = function()
				return compact() and Vector2.new(0.5, 0) or Vector2.new(0.5, 1)
			end,
			Position = function()
				return compact() and UDim2.new(0.5, 0, 0, 72) or UDim2.new(0.5, 0, 1, -16)
			end,
			Size = function()
				return compact() and UDim2.new(0.4, 0, 0, 54) or UDim2.new(0.7, 0, 0, 200)
			end,
			BackgroundTransparency = 1,
			ZIndex = 4,
			create "UIListLayout" {
				VerticalAlignment = function()
					return compact() and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
				end,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			indexes(toasts, function(item, i)
				return Label {
					Name = "Toast",
					LayoutOrder = i,
					Size = function()
						return UDim2.new(1, 0, 0, compact() and 24 or 34)
					end,
					BackgroundColor3 = C.ink,
					BackgroundTransparency = 0.2,
					TextColor3 = C.cream,
					Text = function()
						return item().text
					end,
					Corner(),
					Pad(10, 4),
				}
			end),
		}
	end

	local function PanelWindow()
		return show(panel, function()
			local opened = source(0)
			local slide = spring(opened, 0.35, 0.6)
			opened(1)
			return create "Frame" {
				Name = "Panel",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.ink,
				BackgroundTransparency = 0.45,
				ZIndex = 10,
				create "Frame" {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = function()
						return UDim2.fromScale(0.5, 0.62 - 0.12 * slide())
					end,
					Size = UDim2.fromScale(0.92, 0.86),
					BackgroundColor3 = C.cream,
					Corner(UDim.new(0, 18)),
					Stroke(4),
					create "UISizeConstraint" { MaxSize = Vector2.new(580, 440) },
					Label {
						Name = "PanelTitle",
						Position = UDim2.new(0, 16, 0, 10),
						Size = UDim2.new(1, -80, 0, 40),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							local name = panel()
							local d = data()
							if name == "badges" and d then
								return TITLES.badges .. " " .. Logic.badgeCount(d, Config) .. "/" .. #Config.BADGES
							end
							return name and TITLES[name] or ""
						end,
					},
					Button {
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 10),
						Size = UDim2.new(0, 44, 0, 44),
						BackgroundColor3 = C.red,
						TextColor3 = C.cream,
						Text = "✕",
						onClick = api.close,
					},
					create "ScrollingFrame" {
						Name = "Content",
						Position = UDim2.new(0, 12, 0, 58),
						Size = UDim2.new(1, -24, 1, -70),
						BackgroundTransparency = 1,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollBarThickness = 8,
						create "UIListLayout" { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
						show(data, function()
							return Column {
								switch(panel)(Panels),
								show(function()
									return not data().saving
								end, function()
									return Note "ℹ️ Прогресс сейчас не сохраняется (так бывает при тесте в Studio)"
								end),
							}
						end, function()
							return Note "Загрузка…"
						end),
					},
				},
			}
		end)
	end

	local function HatchLayer()
		return show(hatching, function()
			local age = function()
				local h = hatching()
				return h and now() - h.started or 0
			end
			local function pet()
				local h = hatching()
				return Config.PETS[h and h.pet or "green"]
			end
			return create "Frame" {
				Name = "Hatch",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.ink,
				BackgroundTransparency = 0.25,
				ZIndex = 30,
				show(function()
					return age() < 1.5
				end, function()
					return Label {
						Name = "HatchEgg",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.42),
						Size = UDim2.new(0, 180, 0, 180),
						Text = function()
							local h = hatching()
							return age() < 1.2 and Config.EGGS[h and h.egg or "normal"].icon or "💥"
						end,
						Rotation = function()
							local t = age()
							return t < 1.2 and math.sin(t * 45) * 18 * (1 - t / 1.2) or 0
						end,
					}
				end),
				show(function()
					return age() >= 1.5
				end, function()
					return create "Frame" {
						Name = "HatchCard",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(0, 300, 0, 300),
						BackgroundColor3 = C.cream,
						Corner(UDim.new(0, 20)),
						Stroke(4),
						create "UIScale" {
							Scale = function()
								return math.max(0.05, popOut((age() - 1.5) / 0.4))
							end,
						},
						create "Frame" {
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, 16),
							Size = UDim2.new(0, 110, 0, 110),
							BackgroundColor3 = function()
								local h = hatching()
								return PET_COLORS[h and h.pet or "green"]
							end,
							Corner(UDim.new(1, 0)),
							Label { Size = UDim2.fromScale(1, 1), Text = "🦖" },
						},
						Label { Name = "PetName", Position = UDim2.new(0, 10, 0, 134), Size = UDim2.new(1, -20, 0, 34), Text = function()
							return pet().name
						end },
						Label {
							Name = "PetRarity",
							Position = UDim2.new(0, 10, 0, 170),
							Size = UDim2.new(1, -20, 0, 26),
							Text = function()
								return pet().rarity
							end,
							TextColor3 = function()
								return Config.RARITY_COLORS[pet().rarity]
							end,
						},
						Label { Position = UDim2.new(0, 10, 0, 198), Size = UDim2.new(1, -20, 0, 22), TextColor3 = C.muted, Text = function()
							return pet().power
						end },
						Button {
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -14),
							Size = UDim2.new(0, 160, 0, 50),
							BackgroundColor3 = C.green,
							Text = "Ура!",
							onClick = function()
								hatching(nil)
							end,
						},
					}
				end),
			}
		end)
	end

	local function DinoPad()
		return show(isDino, function()
			local function dinoButton(action, icon, caption, color)
				return Button {
					Name = action,
					Size = function()
						local px = compact() and 62 or 100
						return UDim2.new(0, px, 0, px)
					end,
					BackgroundColor3 = color,
					BackgroundTransparency = function()
						return now() < cooldowns()[action] and 0.4 or 0
					end,
					Text = "",
					round = true,
					onClick = function()
						api.dinoAction(action)
					end,
					Label { Size = UDim2.new(1, 0, 0.6, 0), Text = icon },
					Label {
						Position = UDim2.fromScale(0, 0.6),
						Size = UDim2.new(1, 0, 0.3, 0),
						TextColor3 = C.cream,
						TextStrokeTransparency = 0.3,
						Text = function()
							local left = cooldowns()[action] - now()
							return left > 0 and tostring(math.ceil(left)) or caption
						end,
					},
				}
			end
			return create "Frame" {
				Name = "DinoPad",
				AnchorPoint = Vector2.new(1, 1),
				-- на телефоне — левее кнопки прыжка Roblox, а не над ней
				Position = function()
					return compact() and UDim2.new(1, -150, 1, -12) or UDim2.new(1, -16, 1, -190)
				end,
				Size = function()
					return compact() and UDim2.new(0, 136, 0, 62) or UDim2.new(0, 230, 0, 100)
				end,
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
				},
				dinoButton("roar", "🦖", "РЫК (Q)", C.red),
				dinoButton("dash", "💨", "РЫВОК (F)", C.blue),
			}
		end)
	end

	local destroy, gui = root(function()
		return create "ScreenGui" {
			Name = "DinoUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Hud(),
			Toasts(),
			BigText(),
			DinoPad(),
			PanelWindow(),
			HatchLayer(),
		}
	end)

	api.gui = gui
	api.destroy = destroy
	api.state = { data = data, panel = panel, hatching = hatching, spin = spin, isDino = isDino, now = now }
	return api
end

return App
