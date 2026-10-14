-- Монетки, яйца, питомцы, магазин, подарки, колесо удачи, коды и значки.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)

local Progress = {}
Progress.event = "none"
-- Main подставляет сюда функцию, которая заново надевает костюм и питомца
Progress.onLooksChanged = function(_player: Player) end

-- Если создашь настоящие значки Roblox (Creator Hub → Badges), впиши их номера сюда:
-- например first_egg = 1234567890. Без номеров значки всё равно работают внутри игры.
local ROBLOX_BADGE_IDS: { [string]: number } = {}

local DAY = 20 * 3600 -- подарок и колесо можно брать раз в 20 часов
local STREAK_BREAK = 48 * 3600

-- секретные коды; один код можно ввести один раз
local CODES = {}
local function code(names: { string }, reward)
	for _, n in ipairs(names) do
		CODES[n] = { id = names[1], reward = reward }
	end
end
code({ "DINO", "ДИНО", "Дино", "дино" }, { coins = 50 })
code({ "EGG", "ЯЙЦО", "Яйцо", "яйцо" }, { egg = "normal" })
code({ "RAINBOW", "РАДУГА", "Радуга", "радуга" }, { item = "trail_rainbow" })
code({ "ROAR", "РЫК", "Рык", "рык" }, { coins = 100 })
code({ "GOLD", "ЗОЛОТО", "Золото", "золото" }, { egg = "gold" })

local function pickWeighted(list: { any }, weightOf: (any) -> number)
	local total = 0
	for _, v in ipairs(list) do
		total += weightOf(v)
	end
	local r = math.random() * total
	for i, v in ipairs(list) do
		r -= weightOf(v)
		if r <= 0 then
			return v, i
		end
	end
	return list[#list], #list
end

function Progress.petKind(player: Player): string?
	local p = Data.get(player)
	if not p or p.equippedPet == 0 then
		return nil
	end
	for _, pet in ipairs(p.pets) do
		if pet.id == p.equippedPet then
			return pet.kind
		end
	end
	return nil
end

function Progress.view(player: Player)
	local p = Data.get(player)
	if not p then
		return nil
	end
	local now = os.time()
	local dailyReady = now - p.dailyLast >= DAY
	local nextStreak = (now - p.dailyLast < STREAK_BREAK) and p.dailyStreak + 1 or 1
	return {
		coins = p.coins,
		eggs = p.eggs,
		pets = p.pets,
		equippedPet = p.equippedPet,
		owned = p.owned,
		equipped = p.equipped,
		badges = p.badges,
		cups = p.cups,
		dailyReady = dailyReady,
		dailyDay = ((dailyReady and nextStreak or p.dailyStreak) - 1) % 7 + 1,
		dailyWait = math.max(0, DAY - (now - p.dailyLast)),
		wheelReady = now - p.wheelLast >= DAY,
		wheelWait = math.max(0, DAY - (now - p.wheelLast)),
		saving = Data.isSaving(player),
		event = Progress.event,
	}
end

function Progress.sync(player: Player)
	local view = Progress.view(player)
	if not view then
		return
	end
	Net.send(player, "data", view)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local coins = stats:FindFirstChild("Монетки") :: IntValue?
		local cups = stats:FindFirstChild("Кубки") :: IntValue?
		if coins then
			coins.Value = view.coins
		end
		if cups then
			cups.Value = view.cups
		end
	end
end

-- boosted: монетки за игру (их удваивают золотой и радужный питомцы)
function Progress.addCoins(player: Player, amount: number, boosted: boolean?): number
	local p = Data.get(player)
	if not p then
		return 0
	end
	if boosted then
		local pet = Progress.petKind(player)
		if pet == "gold" or pet == "rainbow" then
			amount *= 2
		end
	end
	p.coins += amount
	Progress.sync(player)
	return amount
end

function Progress.badge(player: Player, id: string)
	local p = Data.get(player)
	local b = Config.badge(id)
	if not p or not b or p.badges[id] then
		return
	end
	p.badges[id] = true
	Net.send(player, "badge", b)
	Net.sound(player, "win")
	local robloxId = ROBLOX_BADGE_IDS[id]
	if robloxId then
		task.spawn(pcall, BadgeService.AwardBadge, BadgeService, player.UserId, robloxId)
	end
	Progress.sync(player)
end

function Progress.addEgg(player: Player, kind: string, count: number?)
	local p = Data.get(player)
	if not p then
		return
	end
	p.eggs[kind] = (p.eggs[kind] or 0) + (count or 1)
	Progress.sync(player)
end

local function giveItem(player: Player, itemId: string): boolean
	local p = Data.get(player)
	if p.owned[itemId] then
		return false
	end
	p.owned[itemId] = true
	local item = Config.shopItem(itemId)
	if item and p.equipped[item.slot] ~= nil then
		p.equipped[item.slot] = itemId
		Progress.onLooksChanged(player)
	end
	return true
end

-- вещь в подарок; если она уже есть — +50 монеток вместо неё
local function giveItemOrCoins(player: Player, itemId: string, dupMsg: string): string
	if giveItem(player, itemId) then
		return Config.shopItem(itemId).name .. "!"
	end
	Data.get(player).coins += 50
	return dupMsg
end

-- ---------- действия с экрана игрока ----------

local handlers = {}

function handlers.hatch(player: Player, eggKind: any)
	local p = Data.get(player)
	local egg = Config.EGGS[eggKind]
	if not egg or (p.eggs[eggKind] or 0) <= 0 then
		return { ok = false, msg = "Нет такого яйца. Унеси яйцо с поля!" }
	end
	if #p.pets >= Config.MAX_PETS then
		return { ok = false, msg = "Слишком много питомцев. Отпусти кого-нибудь." }
	end
	local kinds = {}
	for kind, weight in pairs(egg.odds) do
		table.insert(kinds, { kind = kind, weight = weight })
	end
	local pick = pickWeighted(kinds, function(v)
		return v.weight
	end)
	p.eggs[eggKind] -= 1
	local pet = { id = p.nextPetId, kind = pick.kind }
	p.nextPetId += 1
	table.insert(p.pets, pet)
	if p.equippedPet == 0 then
		p.equippedPet = pet.id
		Progress.onLooksChanged(player)
	end
	Progress.badge(player, "first_pet")
	if pick.kind == "gold" or pick.kind == "rainbow" then
		Progress.badge(player, "legendary_pet")
	end
	Progress.sync(player)
	return { ok = true, pet = pick.kind }
end

function handlers.equipPet(player: Player, id: any)
	local p = Data.get(player)
	if id == 0 or p.equippedPet == id then
		p.equippedPet = 0
	else
		for _, pet in ipairs(p.pets) do
			if pet.id == id then
				p.equippedPet = id
			end
		end
	end
	Progress.onLooksChanged(player)
	Progress.sync(player)
	return { ok = true }
end

function handlers.releasePet(player: Player, id: any)
	local p = Data.get(player)
	for i, pet in ipairs(p.pets) do
		if pet.id == id then
			table.remove(p.pets, i)
			if p.equippedPet == id then
				p.equippedPet = 0
				Progress.onLooksChanged(player)
			end
			local coins = Config.PETS[pet.kind].release
			Progress.addCoins(player, coins)
			return { ok = true, msg = "Пока-пока! +" .. coins .. " 🪙" }
		end
	end
	return { ok = false }
end

function handlers.buy(player: Player, itemId: any)
	local p = Data.get(player)
	local item = Config.shopItem(itemId)
	if not item then
		return { ok = false }
	end
	if item.event and item.event ~= Progress.event then
		return { ok = false, msg = "Эта вещь бывает только на праздник" }
	end
	if item.slot ~= "egg" and p.owned[item.id] then
		return { ok = false, msg = "У тебя это уже есть" }
	end
	if p.coins < item.price then
		return { ok = false, msg = "Не хватает монеток. Нужно " .. item.price .. " 🪙" }
	end
	p.coins -= item.price
	if item.slot == "egg" then
		Progress.addEgg(player, item.egg)
	else
		giveItem(player, item.id)
	end
	Net.sound(player, "coin")
	Progress.sync(player)
	return { ok = true, msg = "Куплено: " .. item.name }
end

function handlers.equip(player: Player, itemId: any)
	local p = Data.get(player)
	local item = Config.shopItem(itemId)
	if not item or not p.owned[item.id] or p.equipped[item.slot] == nil then
		return { ok = false }
	end
	p.equipped[item.slot] = (p.equipped[item.slot] == item.id) and "" or item.id
	Progress.onLooksChanged(player)
	Progress.sync(player)
	return { ok = true }
end

function handlers.daily(player: Player)
	local p = Data.get(player)
	local now = os.time()
	if now - p.dailyLast < DAY then
		return { ok = false, msg = "Подарок уже открыт. Приходи завтра!" }
	end
	p.dailyStreak = (now - p.dailyLast < STREAK_BREAK) and p.dailyStreak + 1 or 1
	p.dailyLast = now
	local day = (p.dailyStreak - 1) % 7 + 1
	local coins = Config.DAILY[day]
	p.coins += coins
	local msg = "+" .. coins .. " 🪙"
	if day == 7 then
		p.eggs.normal += 1
		msg ..= " и яйцо 🥚"
	end
	if p.dailyStreak >= 7 then
		Progress.badge(player, "streak7")
	end
	Net.sound(player, "coin")
	Progress.sync(player)
	return { ok = true, day = day, msg = msg }
end

function handlers.spin(player: Player)
	local p = Data.get(player)
	local now = os.time()
	if now - p.wheelLast < DAY then
		return { ok = false, msg = "Колесо уже крутили. Приходи завтра!" }
	end
	p.wheelLast = now
	local seg, index = pickWeighted(Config.WHEEL, function(v)
		return v.weight
	end)
	local msg
	if seg.kind == "coins" then
		p.coins += seg.amount
		msg = "+" .. seg.amount .. " 🪙"
	elseif seg.kind == "egg" then
		p.eggs[seg.egg] += 1
		msg = Config.EGGS[seg.egg].name .. " " .. Config.EGGS[seg.egg].icon
		if seg.egg == "rainbow" then
			Progress.badge(player, "rainbow_egg")
		end
	else
		msg = giveItemOrCoins(player, seg.item, "У тебя это уже есть, держи +50 🪙")
	end
	Progress.sync(player)
	return { ok = true, index = index, msg = msg }
end

function handlers.code(player: Player, text: any)
	if type(text) ~= "string" then
		return { ok = false, msg = "Введи код" }
	end
	text = text:gsub("%s", "")
	local entry = CODES[text] or CODES[text:upper()]
	if not entry then
		return { ok = false, msg = "Такого кода нет 🤔" }
	end
	local p = Data.get(player)
	if p.codes[entry.id] then
		return { ok = false, msg = "Этот код ты уже вводил" }
	end
	p.codes[entry.id] = true
	local r = entry.reward
	local msg
	if r.coins then
		p.coins += r.coins
		msg = "+" .. r.coins .. " 🪙"
	elseif r.egg then
		p.eggs[r.egg] += 1
		msg = Config.EGGS[r.egg].name .. " " .. Config.EGGS[r.egg].icon
	elseif r.item then
		msg = giveItemOrCoins(player, r.item, "+50 🪙")
	end
	Net.sound(player, "coin")
	Progress.sync(player)
	return { ok = true, msg = "Код сработал: " .. msg }
end

function handlers.getData(player: Player)
	return Progress.view(player)
end

function Progress.handle(player: Player, action: any, arg: any)
	local h = handlers[action]
	if not h or not Data.get(player) then
		return { ok = false }
	end
	return h(player, arg)
end

Players.PlayerRemoving:Connect(function(player)
	Data.release(player)
end)

return Progress
