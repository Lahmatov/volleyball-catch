-- E2E-тесты Roblox-игры: весь сервер (Main и все модули) работает по-настоящему,
-- Roblox заменён заглушками, время идёт по шагам, игроки «ходят» как живые.
-- Запуск из корня репозитория: lune run tests/roblox/e2e
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local H = require("./harness")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

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
local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- новый сервер, игроки заходят, ждём начала тайма (перерыв 15 с)
local function startRound(names: { string })
	H.fresh({ seed = 3 })
	H.startServer()
	local players = {}
	for _, n in names do
		table.insert(players, H.join(n))
	end
	H.run(19) -- 1 с ждём игроков + 15 с перерыв + 1 с перенос на поле
	return players
end

local function config()
	return H.load("Config")
end
local function data()
	return H.load("Data")
end

-- зелёный круг (3-й) и его яйца
local function greenCircle()
	return H.load("Arena").circleCenters()[3]
end
local function eggsNear(center: Vector3)
	local out = {}
	for inst, tags in H.tags do
		if tags.Egg and inst.Anchored and (inst.Transparency or 0) == 0 and inst.Parent and flatDist(inst.Position, center) < config().CIRCLE_RADIUS then
			table.insert(out, inst)
		end
	end
	table.sort(out, function(a, b)
		return a.Position.X < b.Position.X
	end)
	return out
end
local function humans(players)
	local dinoName = H.attr("DinoPlayer")
	local out = {}
	for _, p in players do
		if p.DisplayName ~= dinoName then
			table.insert(out, p)
		end
	end
	return out
end

-- честно сбегать за яйцом: подойти снаружи, забежать, схватить, выбежать за флажки
local function eggRun(player)
	local center = greenCircle()
	local egg = eggsNear(center)[1]
	local dir = Vector3.new(egg.Position.X - center.X, 0, egg.Position.Z - center.Z).Unit
	local outside = center + dir * (config().ZONE_RADIUS + 5)
	H.walkTo(player, outside)
	H.walkTo(player, Vector3.new(egg.Position.X, 0, egg.Position.Z))
	H.walkTo(player, outside)
	H.run(0.2)
end

test("E1 Тайм начинается: игрока переносит из Динопарка на поле", function()
	local p = startRound({ "Аня" })[1]
	local pos = H.root(p).Position
	truthy(math.abs(pos.X) < config().FIELD_X / 2 and math.abs(pos.Z) < config().FIELD_Z / 2, "игрок не на поле: " .. tostring(pos))
	local t = H.attr("TimeLeft")
	truthy(t > 100 and t <= 120, "таймер не идёт: " .. tostring(t))
	eq(H.attr("Map"), "🌼 Поле", "первая карта")
end)

test("E2 Честный забег за яйцом засчитывается", function()
	local p = startRound({ "Аня" })[1]
	eggRun(p)
	eq(H.attr("Humans"), 1, "очки людей")
	eq(H.attr("Dinos"), 0, "очки динозавров")
	eq(data().get(p).eggs.normal, 1, "яиц в рюкзаке")
	eq(data().get(p).coins, 5, "монетки")
end)

test("E3 Читер с телепортом не получает яйцо", function()
	local p = startRound({ "Читер" })[1]
	H.run(2) -- после переноса на поле прошла секунда «доверия»
	local start = H.root(p).Position
	local center = greenCircle()
	local egg = eggsNear(center)[1]
	H.root(p).CFrame = CFrame.new(egg.Position)
	H.step(1 / 20)
	H.root(p).CFrame = CFrame.new(center + Vector3.new(0, 3, config().ZONE_RADIUS + 10))
	H.step(1 / 20)
	H.run(0.5)
	eq(H.attr("Humans"), 0, "очки людей")
	eq(data().get(p).coins, 0, "монетки")
	truthy(flatDist(H.root(p).Position, start) < 6, "читера не вернуло назад")
end)

test("E4 Динозавр ловит, друг спасает из клетки", function()
	local hs = humans(startRound({ "Аня", "Миша", "Лиза" }))
	local a, b = hs[1], hs[2]
	local center = greenCircle()
	H.walkTo(a, center + Vector3.new(0, 0, config().ZONE_RADIUS + 4))
	H.walkTo(a, center, 3)
	H.run(0.3)
	eq(H.attr("Dinos"), 1, "очки динозавров после поимки")
	eq(a.Character.Humanoid.WalkSpeed, 0, "пойманный стоит в клетке")
	H.walkTo(b, H.root(a).Position + Vector3.new(0, 0, 3))
	H.run(0.3)
	truthy(a.Character.Humanoid.WalkSpeed > 0, "друг не спас из клетки")
	eq(data().get(b).badges.rescuer, true, "значок «Спасатель»")
end)

test("E5 Второй человек не может зайти в занятый круг", function()
	local hs = humans(startRound({ "Аня", "Миша", "Лиза" }))
	local a, b = hs[1], hs[2]
	local center = greenCircle()
	local R = config().CIRCLE_RADIUS
	H.walkTo(a, center + Vector3.new(0, 0, R + 3))
	H.walkTo(b, center + Vector3.new(R + 3, 0, 0))
	H.walkTo(a, center + Vector3.new(0, 0, R - 2), 2)
	H.walkTo(b, center + Vector3.new(R - 4, 0, 0), 1)
	truthy(flatDist(H.root(b).Position, center) >= R, "второго не вытолкнуло из круга")
end)

test("E6 Из клетки нельзя убежать читом", function()
	local hs = humans(startRound({ "Аня", "Миша", "Лиза" }))
	local a = hs[1]
	local center = greenCircle()
	H.walkTo(a, center + Vector3.new(0, 0, config().ZONE_RADIUS + 4))
	H.walkTo(a, center, 3)
	H.run(1.5)
	eq(a.Character.Humanoid.WalkSpeed, 0, "пойман")
	local cage = H.root(a).Position
	H.root(a).CFrame = CFrame.new(cage + Vector3.new(10, 0, 0))
	H.step(1 / 20)
	truthy(flatDist(H.root(a).Position, cage) < 2, "читер ушёл из клетки")
end)

test("E7 Тайм заканчивается кубком у людей", function()
	local p = startRound({ "Аня" })[1]
	eggRun(p)
	-- прячемся в кусте до конца тайма: ни динозавры, ни Ти-Рекс нас не видят
	local best, bestD
	for _, bush in H.game:GetService("Workspace").DinoArena:GetChildren() do
		if bush.Name == "Bush" then
			local center
			for _, ball in bush:GetChildren() do
				if ball.Size.X == 6 then
					center = ball.Position
				end
			end
			if center then
				local d = flatDist(center, H.root(p).Position)
				local safe = true
				for _, c in H.load("Arena").circleCenters() do
					if flatDist(center, c) < config().CIRCLE_RADIUS + 2 then
						safe = false
					end
				end
				if safe and (not bestD or d < bestD) then
					best, bestD = center, d
				end
			end
		end
	end
	truthy(best, "нет куста")
	H.walkTo(p, best)
	for _ = 1, 130 do
		if H.attr("TimeLeft") == -1 then
			break
		end
		H.run(1)
	end
	eq(H.attr("TimeLeft"), -1, "тайм закончился")
	eq(H.attr("Humans"), 1, "очки людей")
	eq(H.attr("Dinos"), 0, "очки динозавров")
	eq(data().get(p).cups, 1, "кубков у игрока")
end)

test("E8 Спам кнопками из чит-скрипта отсекается", function()
	local p = startRound({ "Читер" })[1]
	local served = 0
	for _ = 1, 100 do
		local r = H.invoke(p, "getData")
		if r and not r.busy then
			served += 1
		end
	end
	eq(served, 15, "сколько запросов обработано за одно мгновение")
	H.run(1)
	truthy(H.invoke(p, "getData").coins ~= nil, "через секунду кнопки снова работают")
end)

-- ---------- экран игрока + сервер вместе ----------

local UI = require("./ui_loader")

-- экран игрока (Vide), подключённый к настоящему серверу на стенде
local function connectClient(player)
	local seen = #H.sent
	local app
	local function pump()
		while seen < #H.sent do
			seen += 1
			local ev = H.sent[seen]
			if ev.player == nil or ev.player == player then
				if ev.kind == "data" then
					app.setData(ev.payload)
				elseif ev.kind == "toast" then
					app.toast(ev.payload)
				elseif ev.kind == "big" then
					app.big(ev.payload.text, ev.payload.seconds)
				end
			end
		end
	end
	app = UI.App.new({
		ask = function(action, arg)
			local res = H.invoke(player, action, arg)
			pump()
			return res
		end,
		delay = function() end,
	})
	app.setData(H.invoke(player, "getData"))
	local client = { app = app }
	function client.sync()
		pump()
		app.setHud({
			humans = H.attr("Humans") or 0,
			dinos = H.attr("Dinos") or 0,
			timeLeft = H.attr("TimeLeft") or -1,
			status = H.attr("Status") or "",
			map = H.attr("Map") or "",
			dinoPlayer = H.attr("DinoPlayer") or "",
			boss = H.attr("Boss") == true,
		})
		app.tick(H.clock)
	end
	function client.find(text, exact)
		return UI.byText(app.gui, text, exact)
	end
	function client.named(name)
		return UI.byName(app.gui, name)
	end
	return client
end

test("E9 Экран: унёс яйцо, монетки на табло, вылупил питомца в окне", function()
	local p = startRound({ "Аня" })[1]
	local client = connectClient(p)
	eggRun(p)
	client.sync()
	eq(client.named("Coins").Text, "🪙 5", "монетки на табло")
	eq(client.named("Humans").Text, "👫 Люди 1", "очки людей на табло")
	client.app.open("pets")
	UI.press(client.find("Вылупить", true))
	client.sync()
	truthy(client.named("Hatch"), "окно вылупления")
	eq(#data().get(p).pets, 1, "питомец появился на сервере")
	truthy(client.find("динозаврик"), "питомец в списке на экране")
	truthy(client.find("Снять", true), "питомец сразу надет")
end)

test("E10 Экран: секретный код, потом покупка шапки", function()
	local p = startRound({ "Аня" })[1]
	local client = connectClient(p)
	client.app.open("codes")
	client.named("CodeBox").Text = "DINO"
	UI.press(client.find("Проверить", true))
	client.sync()
	eq(client.named("Coins").Text, "🪙 50", "монетки за код")
	client.app.open("shop")
	UI.press(UI.byText(client.named("Panel"), "🪙 50", true)) -- кнопка в магазине, а не табло с монетками
	client.sync()
	eq(data().get(p).owned.hat_dino, true, "шапка куплена на сервере")
	eq(data().get(p).equipped.hat, "hat_dino", "шапка надета на сервере")
	eq(client.named("Coins").Text, "🪙 0", "монетки на табло")
	truthy(client.find("Снять", true), "на кнопке «Снять»")
end)

test("E11 Экран: подарок дня", function()
	local p = startRound({ "Аня" })[1]
	local client = connectClient(p)
	client.app.open("daily")
	UI.press(client.find("Открыть подарок 🎁", true))
	client.sync()
	eq(client.named("Coins").Text, "🪙 20", "монетки за первый день")
	truthy(client.find("Следующий подарок через"), "на экране — сколько ждать")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
