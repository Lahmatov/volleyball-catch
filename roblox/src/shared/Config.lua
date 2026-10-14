-- Общие настройки игры. Их читают и сервер, и экран игрока.
local Config = {}

Config.ROUND_TIME = 120 -- один тайм, секунд
Config.INTERMISSION = 15 -- перерыв между таймами
Config.MAX_PLAYERS = 5
Config.CIRCLE_RADIUS = 14
Config.ZONE_RADIUS = 26 -- убежал за эту границу с яйцом — яйцо твоё
Config.CATCH_DISTANCE = 5
Config.DINO_REACTION = 0.8 -- динозавр сначала удивляется «❗», потом бежит
Config.EGG_RESPAWN = 10
Config.CAGE_TIME = 8 -- сколько сидишь в клетке, если друг не спас
Config.WALK_SPEED = 16
Config.GROUND_Y = 0.05
Config.FIELD_X = 330
Config.FIELD_Z = 170
Config.BOSS_AT = 60 -- Ти-Рекс приходит, когда до конца тайма осталось столько секунд
Config.BOSS_TIME = 20
Config.MAX_PETS = 40

-- "auto" — праздник по календарю; можно поставить "halloween", "newyear" или "none"
Config.EVENT = "auto"

-- Голос (Roblox Text-to-Speech). Если на сервере он недоступен, игра просто покажет надписи.
Config.VOICE_ENABLED = true

Config.DINOS = {
	gold = { name = "Золотой", color = Color3.fromRGB(242, 194, 48), dark = Color3.fromRGB(185, 134, 12), speed = 15, power = "Самый быстрый" },
	rainbow = { name = "Радужный", color = Color3.fromRGB(255, 80, 80), dark = Color3.fromRGB(90, 60, 160), speed = 14.5, power = "Оставляет радужный след" },
	green = { name = "Зелёный", color = Color3.fromRGB(108, 207, 69), dark = Color3.fromRGB(44, 107, 30), speed = 12.5, power = "Прячется в траве" },
	red = { name = "Красный", color = Color3.fromRGB(226, 81, 58), dark = Color3.fromRGB(140, 36, 22), speed = 13.5, power = "Делает рывок" },
}
Config.DINO_ORDER = { "gold", "rainbow", "green", "red" }

Config.RARITY_COLORS = {
	["Обычный"] = Color3.fromRGB(120, 190, 90),
	["Редкий"] = Color3.fromRGB(70, 130, 230),
	["Легендарный"] = Color3.fromRGB(242, 184, 34),
	["Мифический"] = Color3.fromRGB(230, 90, 200),
}

Config.PETS = {
	green = { name = "Зелёный динозаврик", rarity = "Обычный", power = "Ты бегаешь быстрее", release = 5 },
	red = { name = "Красный динозаврик", rarity = "Редкий", power = "Один раз за тайм спасает от динозавра", release = 15 },
	gold = { name = "Золотой динозаврик", rarity = "Легендарный", power = "Монетки x2", release = 40 },
	rainbow = { name = "Радужный динозаврик", rarity = "Мифический", power = "Быстрее, монетки x2 и радужный след", release = 100 },
}
Config.PET_ORDER = { "rainbow", "gold", "red", "green" }

Config.EGGS = {
	normal = { name = "Яйцо", icon = "🥚", odds = { green = 70, red = 25, gold = 5 } },
	gold = { name = "Золотое яйцо", icon = "🌟", odds = { green = 20, red = 30, gold = 50 } },
	rainbow = { name = "Радужное яйцо", icon = "🌈", odds = { gold = 40, rainbow = 60 } },
}
Config.EGG_ORDER = { "normal", "gold", "rainbow" }

Config.SHOP = {
	{ id = "egg_normal", slot = "egg", egg = "normal", name = "Яйцо", price = 40, icon = "🥚" },
	{ id = "egg_gold", slot = "egg", egg = "gold", name = "Золотое яйцо", price = 150, icon = "🌟" },
	{ id = "hat_dino", slot = "hat", name = "Шапка-динозавр", price = 50, icon = "🦖" },
	{ id = "hat_bunny", slot = "hat", name = "Ушки зайки", price = 80, icon = "🐰" },
	{ id = "hat_crown", slot = "hat", name = "Корона", price = 150, icon = "👑" },
	{ id = "hat_pumpkin", slot = "hat", name = "Шапка-тыква", price = 60, icon = "🎃", event = "halloween" },
	{ id = "hat_santa", slot = "hat", name = "Шапка Деда Мороза", price = 60, icon = "🎅", event = "newyear" },
	{ id = "back_egg", slot = "back", name = "Рюкзак-яйцо", price = 100, icon = "🎒" },
	{ id = "trail_fire", slot = "trail", name = "Огненный след", price = 120, icon = "🔥" },
	{ id = "trail_hearts", slot = "trail", name = "След из сердечек", price = 120, icon = "💖" },
	{ id = "trail_rainbow", slot = "trail", name = "Радужный след", price = 250, icon = "🌈" },
}

Config.DAILY = { 20, 30, 40, 50, 75, 100, 150 } -- на 7-й день ещё и яйцо в подарок

Config.WHEEL = {
	{ kind = "coins", amount = 10, label = "10", icon = "🪙", weight = 25 },
	{ kind = "coins", amount = 25, label = "25", icon = "🪙", weight = 22 },
	{ kind = "egg", egg = "normal", label = "Яйцо", icon = "🥚", weight = 16 },
	{ kind = "coins", amount = 50, label = "50", icon = "🪙", weight = 14 },
	{ kind = "item", item = "trail_hearts", label = "След", icon = "💖", weight = 8 },
	{ kind = "egg", egg = "gold", label = "Золотое", icon = "🌟", weight = 7 },
	{ kind = "coins", amount = 100, label = "100", icon = "💰", weight = 6 },
	{ kind = "egg", egg = "rainbow", label = "Радужное", icon = "🌈", weight = 2 },
}

Config.BADGES = {
	{ id = "first_egg", name = "Первое яйцо", icon = "🥚", text = "Унеси первое яйцо" },
	{ id = "escape10", name = "Беглец", icon = "🏃", text = "Унеси 10 яиц" },
	{ id = "close_call", name = "Еле убежал", icon = "😅", text = "Убеги, когда динозавр совсем рядом" },
	{ id = "rainbow_egg", name = "Радуга", icon = "🌈", text = "Найди радужное яйцо" },
	{ id = "first_pet", name = "Первый питомец", icon = "🐣", text = "Вылупи питомца" },
	{ id = "legendary_pet", name = "Легенда", icon = "✨", text = "Вылупи золотого или радужного" },
	{ id = "rescuer", name = "Спасатель", icon = "🦸", text = "Спаси друга из клетки" },
	{ id = "was_dino", name = "Я динозавр", icon = "🦖", text = "Сыграй за динозавра" },
	{ id = "boss", name = "Быстрее Ти-Рекса", icon = "🦕", text = "Убеги от Ти-Рекса" },
	{ id = "winner", name = "Чемпион", icon = "🏆", text = "Получи кубок" },
	{ id = "obby", name = "Прыгун", icon = "🦘", text = "Пройди обби" },
	{ id = "streak7", name = "7 дней", icon = "📅", text = "Заходи 7 дней подряд" },
}

Config.THEMES = {
	{ id = "field", name = "Поле", icon = "🌼" },
	{ id = "jungle", name = "Джунгли", icon = "🌴" },
	{ id = "volcano", name = "Вулкан", icon = "🌋" },
	{ id = "ice", name = "Лёд", icon = "❄️" },
}

Config.POWERUPS = {
	banana = { name = "Банан", icon = "🍌", text = "Супер-скорость!", time = 5 },
	star = { name = "Звезда", icon = "⭐", text = "Динозавры тебя не поймают!", time = 5 },
	spring = { name = "Пружинка", icon = "🦘", text = "Супер-прыжок!", time = 8 },
}

Config.EMOTES = {
	{ id = "dance", name = "Танец", icon = "💃", anim = "rbxassetid://507771019" },
	{ id = "wave", name = "Привет", icon = "👋", anim = "rbxassetid://507770239" },
	{ id = "cheer", name = "Ура", icon = "🙌", anim = "rbxassetid://507770677" },
	{ id = "tongue", name = "Язык", icon = "😛" },
	{ id = "fart", name = "Пук", icon = "💨" },
}

-- Звуки встроены в Roblox. Любой можно заменить на свой "rbxassetid://...".
Config.SOUNDS = {
	pickup = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.2 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.6 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1 },
	roar = { id = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.55 },
	crack = { id = "rbxasset://sounds/snap.wav", speed = 0.8 },
	jump = { id = "rbxasset://sounds/action_jump.mp3", speed = 1 },
	swoosh = { id = "rbxasset://sounds/swoosh.wav", speed = 1 },
	win = { id = "rbxasset://sounds/victory.wav", speed = 1 },
	fart = { id = "rbxasset://sounds/uuhhh.mp3", speed = 0.35 },
	boing = { id = "rbxasset://sounds/action_jump.mp3", speed = 1.6 },
	slip = { id = "rbxasset://sounds/swoosh.wav", speed = 0.7 },
	note = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1 },
}

-- Музыка. По умолчанию играют встроенные мелодии (их «играет» сам скрипт нотами).
-- Можно вставить свою музыку из Creator Store: например lobby = "rbxassetid://1234567890".
Config.MUSIC = { lobby = "", round = "", boss = "" }
Config.MUSIC_VOLUME = 0.35

-- что болтают динозавры
Config.DINO_PHRASES = {
	idle = { "Где мои яйца?", "Скучно-о-о...", "Хочу обнимашки!", "Апчхи! 🤧", "Ик! 😳", "Я самый красивый 😎", "Мама, я голодный!", "Хр-р-р... 💤", "Кто съел мой бутерброд?", "Ля-ля-ля 🎵" },
	chase = { "Иди сюда!", "Отдай яйцо!", "Ам-ням-ням!", "Догоню-у-у!", "Стой! Я только понюхать!", "У меня лапки! 🐾" },
	catch = { "АМ! Попался! 😋", "Хе-хе-хе!", "Моё яйцо! 🥚", "Вкусненький! 😋" },
	boss = { "Я ТИ-РЕКС! РРР!", "Кто хочет обнимашки?!", "У меня маленькие ручки! 🦖", "Топ-топ-топ!" },
	statue = { "Апчхи! 🤧", "Мур-мур 🥰", "Ик! 😳", "Хи-хи, щекотно! 😆", "РРР! ...шучу 😜", "Буэ! Кто ел капусту? 🤢", "Пук! 💨 Ой, это не я!", "Я ем только брокколи 🥦" },
}

function Config.currentEvent(): string
	if Config.EVENT ~= "auto" then
		return Config.EVENT
	end
	local month = os.date("!*t").month
	if month == 10 then
		return "halloween"
	elseif month == 12 or month == 1 then
		return "newyear"
	end
	return "none"
end

function Config.shopItem(id: string)
	for _, item in ipairs(Config.SHOP) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function Config.badge(id: string)
	for _, b in ipairs(Config.BADGES) do
		if b.id == id then
			return b
		end
	end
	return nil
end

return Config
