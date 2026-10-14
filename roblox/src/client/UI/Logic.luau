-- Правила экрана без самого экрана: что показать в магазине, питомцах, подарках, колесе.
-- Чистые функции — их проверяют юнит-тесты (tests/roblox/run.luau).
local Logic = {}

function Logic.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Logic.formatWait(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if h > 0 then
		return h .. " ч " .. m .. " мин"
	end
	return m .. " мин"
end

-- строка над табло: карта, кто динозавр, Ти-Рекс; между таймами — отсчёт
function Logic.statusLine(hud): string
	if hud.timeLeft < 0 then
		return hud.status or ""
	end
	local line = "🗺 " .. (hud.map or "")
	if hud.dinoPlayer and hud.dinoPlayer ~= "" then
		line ..= "   🦖 " .. hud.dinoPlayer
	end
	if hud.boss then
		line ..= "   ⚠️ Ти-Рекс!"
	end
	return line
end

-- яйца в рюкзаке
function Logic.eggRows(data, Config)
	local rows = {}
	for _, kind in ipairs(Config.EGG_ORDER) do
		local egg = Config.EGGS[kind]
		local count = data.eggs[kind] or 0
		table.insert(rows, { kind = kind, icon = egg.icon, text = egg.name .. "  ×" .. count, canHatch = count > 0 })
	end
	return rows
end

-- питомцы: сначала самые редкие, надетый подсвечен
function Logic.petRows(data, Config)
	local rank = {}
	for i, k in ipairs(Config.PET_ORDER) do
		rank[k] = i
	end
	local list = table.clone(data.pets)
	table.sort(list, function(a, b)
		if rank[a.kind] ~= rank[b.kind] then
			return rank[a.kind] < rank[b.kind]
		end
		return a.id < b.id
	end)
	local rows = {}
	for _, pet in ipairs(list) do
		local def = Config.PETS[pet.kind]
		table.insert(rows, {
			id = pet.id,
			kind = pet.kind,
			name = def.name,
			info = def.rarity .. " · " .. def.power,
			rarity = def.rarity,
			worn = data.equippedPet == pet.id,
			release = def.release,
		})
	end
	return rows
end

-- магазин: что на кнопке и что она делает
function Logic.shopRows(data, Config)
	local rows = {}
	for _, item in ipairs(Config.SHOP) do
		if not item.event or item.event == data.event then
			local owned = item.slot ~= "egg" and data.owned[item.id] == true
			local wearing = owned and data.equipped[item.slot] == item.id
			table.insert(rows, {
				id = item.id,
				icon = item.icon,
				name = item.name .. (item.event and " (праздник!)" or ""),
				action = owned and "equip" or "buy",
				button = owned and (wearing and "Снять" or "Надеть") or ("🪙 " .. item.price),
				state = wearing and "wearing" or (owned and "owned" or "price"),
			})
		end
	end
	return rows
end

-- 7 коробок подарков: забрано / сегодня / потом
function Logic.dailyBoxes(data, Config)
	local boxes = {}
	for day, coins in ipairs(Config.DAILY) do
		local claimed = day < data.dailyDay or (day == data.dailyDay and not data.dailyReady)
		local today = day == data.dailyDay and data.dailyReady
		table.insert(boxes, {
			day = day,
			coins = coins,
			state = today and "today" or (claimed and "claimed" or "later"),
			icon = claimed and "✔" or (day == 7 and "🥚🪙" or "🪙"),
		})
	end
	return boxes
end

-- колесо: на сколько повернуть, чтобы сектор index оказался под стрелкой (5 полных оборотов)
function Logic.wheelFinal(index: number, count: number): number
	return 360 * 5 - (index - 1) * (360 / count)
end

-- плавное замедление колеса: t от 0 до 1
function Logic.wheelAngle(final: number, t: number): number
	t = math.clamp(t, 0, 1)
	return final * (1 - (1 - t) ^ 3)
end

-- положение фишки колеса (доли от размера колеса)
function Logic.wheelChip(i: number, count: number, angle: number): (number, number)
	local a = math.rad((i - 1) * (360 / count) + angle)
	return 0.5 + 0.36 * math.sin(a), 0.5 - 0.36 * math.cos(a)
end

function Logic.badgeCount(data, Config): number
	local got = 0
	for _, b in ipairs(Config.BADGES) do
		if data.badges[b.id] then
			got += 1
		end
	end
	return got
end

-- красные точки на кнопках: есть подарок, можно крутить, есть яйца
function Logic.dots(data)
	local eggs = 0
	for _, n in pairs(data.eggs) do
		eggs += n
	end
	return { daily = data.dailyReady == true, wheel = data.wheelReady == true, pets = eggs > 0 }
end

-- на чём играют: "touch" (телефон, планшет), "gamepad" (PlayStation, Xbox), "keyboard" (компьютер).
-- lastInputType — имя Enum.UserInputType (UserInputService:GetLastInputType().Name)
function Logic.inputKind(lastInputType: string): string
	if lastInputType == "Touch" then
		return "touch"
	elseif string.sub(lastInputType, 1, 7) == "Gamepad" then
		return "gamepad"
	end
	return "keyboard"
end

-- кнопки динозавра на клавиатуре и геймпаде (на PlayStation ButtonY — △, ButtonR1 — R1)
Logic.DINO_KEYS = {
	roar = { keyboard = "Q", gamepad = "ButtonY", name = "РЫК" },
	dash = { keyboard = "F", gamepad = "ButtonR1", name = "РЫВОК" },
}

-- подпись на кнопке: клавишу показываем только тем, у кого есть клавиатура
function Logic.actionCaption(action: string, input: string): string
	local key = Logic.DINO_KEYS[action]
	if input == "keyboard" then
		return key.name .. " (" .. key.keyboard .. ")"
	end
	return key.name
end

return Logic
