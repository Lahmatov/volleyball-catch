-- Тесты экрана игрока (Vide): правила в Logic (юнит) и сам экран — кнопки, окна, анимации.
-- Запуск из корня репозитория: lune run tests/roblox/ui
local process = require("@lune/process")
local UI = require("./ui_loader")
local Logic, Config = UI.Logic, UI.Config

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS  " .. name)
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err):split("\n")[1])
	end
end
local function eq(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: ожидали %s, получили %s", what, tostring(expected), tostring(actual)), 2)
	end
end
local function truthy(v, what)
	if not v then
		error(what, 2)
	end
end

local function view(over)
	local v = {
		coins = 100,
		eggs = { normal = 1, gold = 0, rainbow = 0 },
		pets = {},
		equippedPet = 0,
		owned = {},
		equipped = { hat = "", back = "", trail = "" },
		badges = {},
		cups = 0,
		dailyReady = true,
		dailyDay = 1,
		dailyWait = 0,
		wheelReady = true,
		wheelWait = 0,
		saving = true,
		event = "none",
	}
	for k, x in over or {} do
		v[k] = x
	end
	return v
end

-- ---------- юнит: правила экрана ----------

test("L1 Время и ожидание", function()
	eq(Logic.formatTime(95), "1:35", "1:35")
	eq(Logic.formatTime(-3), "0:00", "отрицательное время")
	eq(Logic.formatWait(3 * 3600 + 5 * 60), "3 ч 5 мин", "часы")
	eq(Logic.formatWait(59), "0 мин", "меньше минуты")
end)

test("L2 Магазин: цена, «Надеть», «Снять», праздничное прячется", function()
	local rows = Logic.shopRows(view({ owned = { hat_dino = true, trail_fire = true }, equipped = { hat = "hat_dino", back = "", trail = "" } }), Config)
	local byId = {}
	for _, r in rows do
		byId[r.id] = r
	end
	eq(byId.hat_dino.button, "Снять", "надетая шапка")
	eq(byId.trail_fire.button, "Надеть", "купленный след")
	eq(byId.hat_crown.button, "🪙 150", "корона")
	eq(byId.hat_pumpkin, nil, "тыква не в праздник")
	eq(byId.egg_normal.action, "buy", "яйцо всегда покупается")
end)

test("L3 Подарки: забрано, сегодня, потом", function()
	local boxes = Logic.dailyBoxes(view({ dailyDay = 3, dailyReady = true }), Config)
	eq(boxes[2].state, "claimed", "день 2")
	eq(boxes[3].state, "today", "день 3")
	eq(boxes[4].state, "later", "день 4")
	eq(boxes[7].icon, "🥚🪙", "день 7 с яйцом")
end)

test("L4 Колесо останавливается на выпавшем секторе", function()
	for index = 1, #Config.WHEEL do
		local final = Logic.wheelFinal(index, #Config.WHEEL)
		local x, y = Logic.wheelChip(index, #Config.WHEEL, Logic.wheelAngle(final, 1))
		truthy(math.abs(x - 0.5) < 1e-6 and y < 0.2, "сектор " .. index .. " не под стрелкой: " .. x .. ", " .. y)
	end
	eq(Logic.wheelAngle(1000, 0), 0, "начало")
end)

test("L5 Питомцы: редкие сверху, надетый отмечен", function()
	local rows = Logic.petRows(view({ pets = { { id = 1, kind = "green" }, { id = 2, kind = "rainbow" }, { id = 3, kind = "gold" } }, equippedPet = 3 }), Config)
	eq(rows[1].kind, "rainbow", "первый")
	eq(rows[2].kind, "gold", "второй")
	eq(rows[2].worn, true, "золотой надет")
	eq(rows[3].kind, "green", "последний")
end)

-- ---------- экран ----------

test("U1 Табло показывает очки, время, карту и монетки", function()
	local ui = UI.new()
	ui.app.setData(view({ coins = 42 }))
	ui.app.setHud({ humans = 2, dinos = 1, timeLeft = 95, status = "", map = "🌼 Поле", dinoPlayer = "Миша", boss = true })
	eq(ui.named("Humans").Text, "👫 Люди 2", "люди")
	eq(ui.named("Dinos").Text, "🦖 Дино 1", "динозавры")
	eq(ui.named("Time").Text, "1:35", "время")
	eq(ui.named("Coins").Text, "🪙 42", "монетки")
	eq(ui.named("Status").Text, "🗺 🌼 Поле   🦖 Миша   ⚠️ Ти-Рекс!", "строка статуса")
	ui.app.setHud({ humans = 0, dinos = 0, timeLeft = -1, status = "Скоро 🌴 Джунгли: 5", map = "", dinoPlayer = "", boss = false })
	eq(ui.named("Time").Text, "⏳", "между таймами")
	eq(ui.named("Status").Text, "Скоро 🌴 Джунгли: 5", "отсчёт")
end)

test("U2 Сообщения: не больше 4, исчезают через 3.5 с", function()
	local ui = UI.new()
	for i = 1, 5 do
		ui.app.toast("сообщение " .. i)
	end
	local shown = 0
	for _, inst in UI.all(ui.named("Toasts")) do
		if inst.Name == "Toast" then
			shown += 1
		end
	end
	eq(shown, 4, "сообщений на экране")
	truthy(ui.find("сообщение 5"), "новое сообщение видно")
	truthy(not ui.find("сообщение 1"), "самое старое убрано")
	ui.tick(4)
	truthy(not ui.find("сообщение 5"), "через 4 с всё исчезло")
end)

test("U3 Магазин: нажатие «Купить» отправляет покупку на сервер", function()
	local ui = UI.new({ buy = { ok = true, msg = "Куплено: Шапка-динозавр" } })
	ui.app.setData(view())
	ui.app.open("shop")
	eq(ui.named("PanelTitle").Text, "🛒 Магазин", "заголовок")
	UI.press(ui.find("🪙 50", true))
	eq(ui.calls[1].action, "buy", "запрос")
	eq(ui.calls[1].arg, "hat_dino", "что купили")
	truthy(ui.find("Куплено: Шапка-динозавр"), "сообщение о покупке")
	ui.app.setData(view({ owned = { hat_dino = true }, equipped = { hat = "hat_dino", back = "", trail = "" } }))
	truthy(ui.find("Снять", true), "после покупки кнопка «Снять»")
	UI.press(ui.named("Close"))
	eq(ui.named("Panel"), nil, "окно закрылось")
end)

test("U4 Подарок: кнопка открывает и показывает награду", function()
	local ui = UI.new({ daily = { ok = true, day = 1, msg = "+20 🪙" } })
	ui.app.setData(view())
	ui.app.open("daily")
	UI.press(ui.find("Открыть подарок 🎁", true))
	eq(ui.calls[1].action, "daily", "запрос")
	eq(ui.named("Big").Text, "🎁 +20 🪙", "большая надпись")
	ui.app.setData(view({ dailyReady = false, dailyWait = 7200 }))
	truthy(ui.find("Следующий подарок через 2 ч 0 мин", true), "после подарка — сколько ждать")
	truthy(not ui.find("Открыть подарок 🎁", true), "кнопка исчезла")
end)

test("U5 Вылупление: яйцо трясётся, трескается, появляется питомец", function()
	local ui = UI.new({ hatch = { ok = true, pet = "gold" } })
	ui.app.setData(view())
	ui.app.open("pets")
	UI.press(ui.find("Вылупить", true))
	eq(ui.calls[1].arg, "normal", "какое яйцо")
	truthy(ui.named("HatchEgg"), "яйцо на экране")
	ui.tick(0.3)
	truthy(math.abs(ui.named("HatchEgg").Rotation) > 1, "яйцо трясётся")
	ui.tick(1.3)
	eq(ui.named("HatchEgg"), nil, "яйцо исчезло")
	eq(ui.named("PetName").Text, "Золотой динозаврик", "кто вылупился")
	eq(ui.named("PetRarity").Text, "Легендарный", "редкость")
	local cracks, wins = 0, 0
	for _, s in ui.sounds do
		cracks += s == "crack" and 1 or 0
		wins += s == "win" and 1 or 0
	end
	eq(cracks, 2, "звук трещины")
	eq(wins, 1, "звук победы")
	UI.press(ui.find("Ура!", true))
	eq(ui.named("Hatch"), nil, "окно вылупления закрылось")
end)

test("U6 Колесо крутится и останавливается на выпавшей награде", function()
	local ui = UI.new({ spin = { ok = true, index = 3, msg = "Яйцо 🥚" } })
	ui.app.setData(view())
	ui.app.open("wheel")
	UI.press(ui.find("Крутить! 🎡", true))
	ui.tick(1)
	truthy(ui.find("Крутится… 🎡", true), "крутится")
	ui.tick(3.2)
	local chip = ui.named("Chip3").Position
	truthy(math.abs(chip.X.Scale - 0.5) < 1e-3 and chip.Y.Scale < 0.2, "сектор 3 под стрелкой")
	eq(ui.named("Big").Text, "🎡 Яйцо 🥚", "награда")
end)

test("U7 Отпустить питомца можно только со второго нажатия", function()
	local ui = UI.new({ releasePet = { ok = true, msg = "Пока-пока! +5 🪙" } })
	ui.app.setData(view({ pets = { { id = 7, kind = "green" } } }))
	ui.app.open("pets")
	UI.press(ui.find("Отпустить +5🪙", true))
	eq(#ui.calls, 0, "после первого нажатия запроса нет")
	truthy(ui.find("Точно? 🥺", true), "переспрашивает")
	UI.press(ui.find("Точно? 🥺", true))
	eq(ui.calls[1].action, "releasePet", "запрос")
	eq(ui.calls[1].arg, 7, "какой питомец")
end)

test("U8 Секретный код отправляется на сервер", function()
	local ui = UI.new({ code = { ok = true, msg = "Код сработал: +50 🪙" } })
	ui.app.setData(view())
	ui.app.open("codes")
	ui.named("CodeBox").Text = "DINO"
	UI.press(ui.find("Проверить", true))
	eq(ui.calls[1].action, "code", "запрос")
	eq(ui.calls[1].arg, "DINO", "код")
	eq(ui.named("CodeBox").Text, "", "поле очистилось")
end)

test("U9 Кнопки динозавра: рык и перезарядка", function()
	local ui = UI.new({ roar = { ok = true, cooldown = 8 } })
	eq(ui.named("DinoPad"), nil, "у человека кнопок динозавра нет")
	ui.app.setDino(true)
	truthy(ui.named("DinoBanner"), "надпись «Ты динозавр»")
	UI.press(ui.named("roar"))
	UI.press(ui.named("roar"))
	eq(#ui.calls, 1, "второй рык во время перезарядки не отправляется")
	ui.tick(0.1)
	truthy(ui.find("8", true), "на кнопке осталось 8 секунд")
	ui.tick(8)
	truthy(ui.find("РЫК (Q)", true), "рык снова готов")
end)

test("U10 Кнопка пружинит при нажатии", function()
	local ui = UI.new()
	ui.app.setData(view())
	ui.app.open("emotes")
	local button = ui.find("Танец")
	local scale
	for _, c in button:GetChildren() do
		if c.Scale then
			scale = c
		end
	end
	button.MouseButton1Down:fire()
	ui.tick(0.1)
	truthy(scale.Scale < 0.99, "кнопка сжалась: " .. tostring(scale.Scale))
	button.MouseButton1Up:fire()
	ui.tick(1)
	truthy(math.abs(scale.Scale - 1) < 0.01, "кнопка вернулась: " .. tostring(scale.Scale))
end)

-- ---------- телефон: кнопки не закрывают игру ----------

-- прямоугольник элемента на экране W×H (без учёта UISizeConstraint — с запасом)
local function rect(inst, W, H)
	local size, pos = inst.Size, inst.Position
	local anchor = inst.AnchorPoint or { X = 0, Y = 0 }
	local w = size.X.Scale * W + size.X.Offset
	local h = size.Y.Scale * H + size.Y.Offset
	local x = pos.X.Scale * W + pos.X.Offset - anchor.X * w
	local y = pos.Y.Scale * H + pos.Y.Offset - anchor.Y * h
	return { x = x, y = y, w = w, h = h }
end
local function overlaps(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

test("U11 Телефон: джойстик и прыжок свободны, кнопки занимают мало места", function()
	local W, H = 812, 375 -- телефон боком
	local ui = UI.new()
	if ui.app.setViewport then
		ui.app.setViewport(W, H)
	end
	ui.app.setData(view())
	ui.app.setHud({ humans = 1, dinos = 2, timeLeft = 80, status = "", map = "🌼 Поле", dinoPlayer = "Миша", boss = true })
	ui.app.setDino(true)
	for i = 1, 5 do
		ui.app.toast("сообщение " .. i)
	end
	ui.app.big("🦖 ТИ-РЕКС! БЕГИ!", 3)
	local thumb = { x = 0, y = H * 0.45, w = W * 0.4, h = H * 0.55 } -- джойстик Roblox
	local jump = { x = W - 140, y = H - 140, w = 140, h = 140 } -- кнопка прыжка
	local area = 0
	for _, inst in ui.app.gui:GetChildren() do
		local r = rect(inst, W, H)
		truthy(not overlaps(r, thumb), inst.Name .. " закрывает джойстик")
		truthy(not overlaps(r, jump), inst.Name .. " закрывает кнопку прыжка")
		if inst.Name ~= "Big" and inst.Name ~= "Toasts" then -- надпись и сообщения живут 2–4 секунды
			area += r.w * r.h
		end
	end
	local toasts = 0
	for _, t in ui.named("Toasts"):GetChildren() do
		toasts += t.Name == "Toast" and 1 or 0
	end
	eq(toasts, 2, "на телефоне сообщений одновременно")
	truthy(area / (W * H) < 0.15, string.format("постоянные элементы занимают %.0f%% экрана", 100 * area / (W * H)))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
