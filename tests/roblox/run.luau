-- Тесты Roblox-логики. Запуск из корня репозитория: lune run tests/roblox/run
local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum
local Vector3 = require("@lune/roblox").Vector3
local H = require("./harness")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS  " .. name)
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
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

-- свежий сервер с одним игроком и загруженным профилем
local function setup(opts)
	H.fresh(opts)
	local Data = H.load("Data")
	local Progress = H.load("Progress")
	local Config = H.load("Config")
	local player = H.addPlayer("Аня")
	Data.load(player)
	return Progress, Data, Config, player
end

test("T5 Подарок каждый день: +20, отказ, день 2, после перерыва снова день 1", function()
	local Progress, Data, _, p = setup()
	local r = Progress.handle(p, "daily")
	eq(r.ok, true, "первый подарок")
	eq(Data.get(p).coins, 20, "монетки после дня 1")
	eq(Progress.handle(p, "daily").ok, false, "второй подарок в тот же день")
	H.now += 21 * 3600
	r = Progress.handle(p, "daily")
	eq(r.day, 2, "день после 21 часа")
	eq(Data.get(p).coins, 50, "монетки после дня 2")
	H.now += 3 * 24 * 3600
	eq(Progress.handle(p, "daily").day, 1, "день после перерыва в 3 дня")
end)

test("T6 Магазин отказывает: мало монеток, праздничная вещь не в праздник", function()
	local Progress, Data, _, p = setup({ month = 5 })
	Progress.event = "none"
	Data.get(p).coins = 40
	local r = Progress.handle(p, "buy", "hat_crown")
	eq(r.ok, false, "корона за 150 при 40 монетках")
	Data.get(p).coins = 500
	r = Progress.handle(p, "buy", "hat_pumpkin")
	eq(r.ok, false, "шапка-тыква не в Хэллоуин")
	eq(Data.get(p).coins, 500, "монетки не изменились")
	eq(Data.get(p).owned.hat_crown, nil, "короны нет")
	eq(Data.get(p).owned.hat_pumpkin, nil, "тыквы нет")
end)

test("T7 Магазин продаёт: покупка, повторная покупка, снять", function()
	local Progress, Data, _, p = setup()
	Data.get(p).coins = 100
	eq(Progress.handle(p, "buy", "hat_dino").ok, true, "покупка шапки")
	local prof = Data.get(p)
	eq(prof.coins, 50, "монетки после покупки")
	eq(prof.owned.hat_dino, true, "шапка куплена")
	eq(prof.equipped.hat, "hat_dino", "шапка надета")
	eq(Progress.handle(p, "buy", "hat_dino").ok, false, "повторная покупка")
	eq(prof.coins, 50, "монетки после повторной покупки")
	Progress.handle(p, "equip", "hat_dino")
	eq(prof.equipped.hat, "", "шапка снята")
end)

test("T8 Вылупление: без яйца отказ, с яйцом питомец надет и значок", function()
	local Progress, Data, _, p = setup()
	eq(Progress.handle(p, "hatch", "normal").ok, false, "вылупить без яйца")
	Progress.addEgg(p, "normal")
	local r = Progress.handle(p, "hatch", "normal")
	eq(r.ok, true, "вылупить с яйцом")
	local prof = Data.get(p)
	eq(#prof.pets, 1, "питомцев")
	eq(prof.equippedPet, prof.pets[1].id, "питомец надет")
	eq(prof.eggs.normal, 0, "яйцо потрачено")
	eq(prof.badges.first_pet, true, "значок «Первый питомец»")
end)

test("T9 Радужное яйцо даёт только золотых и радужных", function()
	local Progress, Data, _, p = setup()
	local seen = {}
	for _ = 1, 100 do
		Progress.addEgg(p, "rainbow")
		local r = Progress.handle(p, "hatch", "rainbow")
		eq(r.ok, true, "вылупление")
		seen[r.pet] = (seen[r.pet] or 0) + 1
		local prof = Data.get(p)
		Progress.handle(p, "releasePet", prof.pets[#prof.pets].id)
	end
	truthy(seen.gold and seen.rainbow, "должны встречаться и золотые, и радужные")
	eq(seen.green, nil, "зелёных")
	eq(seen.red, nil, "красных")
end)

test("T10 Лимит 40 питомцев и отпускание надетого", function()
	local Progress, Data, Config, p = setup()
	Progress.addEgg(p, "normal", 41)
	for i = 1, 40 do
		eq(Progress.handle(p, "hatch", "normal").ok, true, "вылупление №" .. i)
	end
	eq(Progress.handle(p, "hatch", "normal").ok, false, "41-й питомец")
	local prof = Data.get(p)
	local worn = prof.equippedPet
	local kind
	for _, pet in prof.pets do
		if pet.id == worn then
			kind = pet.kind
		end
	end
	local before = prof.coins
	eq(Progress.handle(p, "releasePet", worn).ok, true, "отпустить")
	eq(prof.coins - before, Config.PETS[kind].release, "монетки за отпускание")
	eq(prof.equippedPet, 0, "питомец снят")
	eq(#prof.pets, 39, "питомцев осталось")
end)

test("T11 Секретные коды", function()
	local Progress, Data, _, p = setup()
	eq(Progress.handle(p, "code", "  DINO ").ok, true, "код с пробелами")
	eq(Data.get(p).coins, 50, "монетки за DINO")
	eq(Progress.handle(p, "code", "DINO").ok, false, "тот же код снова")
	eq(Progress.handle(p, "code", "дино").ok, false, "тот же код по-русски")
	eq(Progress.handle(p, "code", "abc").ok, false, "неизвестный код")
	eq(Progress.handle(p, "code", 123).ok, false, "не строка")
	eq(Progress.handle(p, "code", "РАДУГА").ok, true, "код РАДУГА")
	eq(Data.get(p).owned.trail_rainbow, true, "радужный след получен")
end)

test("T12 Колесо удачи раз в день, награда совпадает с сектором", function()
	local Progress, Data, Config, p = setup({ seed = 7 })
	local prof = Data.get(p)
	local coins, eggs = prof.coins, table.clone(prof.eggs)
	local r = Progress.handle(p, "spin")
	eq(r.ok, true, "первое вращение")
	local seg = Config.WHEEL[r.index]
	truthy(seg, "сектор существует")
	if seg.kind == "coins" then
		eq(prof.coins - coins, seg.amount, "монетки с колеса")
	elseif seg.kind == "egg" then
		eq(prof.eggs[seg.egg] - eggs[seg.egg], 1, "яйцо с колеса")
	else
		eq(prof.owned[seg.item], true, "вещь с колеса")
	end
	eq(Progress.handle(p, "spin").ok, false, "второе вращение сразу")
	H.now += 21 * 3600
	eq(Progress.handle(p, "spin").ok, true, "вращение через 21 час")
end)

test("T13 Золотой питомец удваивает только монетки за игру", function()
	local Progress, Data, _, p = setup()
	local prof = Data.get(p)
	table.insert(prof.pets, { id = 99, kind = "gold" })
	prof.equippedPet = 99
	eq(Progress.addCoins(p, 5, true), 10, "монетки за игру")
	eq(Progress.addCoins(p, 5), 5, "монетки не за игру")
	eq(prof.coins, 15, "всего монеток")
end)

test("T14 Старое сохранение без новых полей", function()
	H.fresh({ saved = { u1 = { coins = 77, badges = { first_egg = true } } } })
	local Data = H.load("Data")
	H.load("Progress")
	local p = H.addPlayer("Миша")
	local prof = Data.load(p)
	eq(prof.coins, 77, "монетки из сохранения")
	eq(prof.badges.first_egg, true, "значок из сохранения")
	eq(prof.eggs.normal, 0, "новое поле eggs")
	eq(prof.equipped.trail, "", "новое поле equipped")
	eq(Data.isSaving(p), true, "сохранять можно")
end)

test("T15 Смена карт не портит горы и вулкан", function()
	H.fresh()
	local Graphics = H.load("Graphics")
	Graphics.setup()
	Graphics.buildWorld(H.new("Folder"))
	local caps, volcano = {}, {}
	for _, f in H.fills do
		if f.kind == "ball" and f.pos.Y > 0 then
			table.insert(caps, f)
		elseif f.kind == "cylinder" and math.abs(f.pos.Z + 330) < 1 and f.material ~= Enum.Material.CrackedLava then
			table.insert(volcano, f)
		end
	end
	truthy(#caps > 0 and #volcano > 0, "нашли вершины гор и вулкан")
	local capMaterial = caps[1].material
	local volcanoTop = volcano[#volcano].material
	for _, theme in { "ice", "volcano", "field" } do
		Graphics.applyTheme(theme, "none")
	end
	for _, f in caps do
		eq(f.material, capMaterial, "материал вершины горы после Лёд → Вулкан → Поле")
	end
	eq(volcano[#volcano].material, volcanoTop, "материал верхушки вулкана после Лёд → Вулкан → Поле")
end)

test("T16 Защита: честная ходьба и бег проходят проверку", function()
	H.fresh()
	local AC = H.load("AntiCheat")
	local anchor = {}
	local pos = Vector3.new(0, 3, 0)
	for i = 0, 100 do -- 5 секунд бегом 16 шагов/с с рывками сети
		local t = i * 0.05
		pos = Vector3.new(16 * t + (i % 3) * 0.5, 3, 0)
		eq(AC.check(anchor, pos, t, 16 * 1.25), true, "шаг " .. i)
	end
end)

test("T17 Защита: телепорт отклонён, после переноса сервером снова верим", function()
	H.fresh()
	local AC = H.load("AntiCheat")
	local anchor = {}
	AC.check(anchor, Vector3.new(0, 3, 0), 0, 20)
	eq(AC.check(anchor, Vector3.new(30, 3, 0), 0.05, 20), false, "прыжок на 30 шагов за 0.05 с")
	eq(anchor.pos, Vector3.new(0, 3, 0), "честная точка осталась прежней")
	AC.trust(anchor, 0.1)
	eq(AC.check(anchor, Vector3.new(200, 3, 0), 0.15, 20), true, "перенос сервером")
	eq(AC.check(anchor, Vector3.new(200, 3, 0), 1.5, 20), true, "стоит на новом месте")
	eq(AC.check(anchor, Vector3.new(260, 3, 0), 1.6, 20), false, "новый телепорт после доверия")
end)

test("T18 Защита: в клетке не уйти, спам кнопками отсекается", function()
	H.fresh()
	local AC = H.load("AntiCheat")
	local anchor = {}
	AC.check(anchor, Vector3.new(0, 3, 0), 0, 0, 1.5)
	eq(AC.check(anchor, Vector3.new(1, 3, 0), 0.5, 0, 1.5), true, "покачаться на месте")
	eq(AC.check(anchor, Vector3.new(4, 3, 0), 1, 0, 1.5), false, "уйти из клетки на 4 шага")
	local bucket, ok = {}, 0
	for _ = 1, 50 do
		if AC.allow(bucket, 10, 8, 15) then
			ok += 1
		end
	end
	eq(ok, 15, "запросов сразу")
	eq(AC.allow(bucket, 10.1, 8, 15), false, "через 0.1 с жетона ещё нет")
	eq(AC.allow(bucket, 10.2, 8, 15), true, "через 0.2 с один жетон есть")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
