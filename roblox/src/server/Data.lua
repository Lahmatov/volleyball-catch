-- Сохранение монеток, питомцев, костюмов и значков через ProfileStore.
-- ProfileStore «запирает» данные игрока на одном сервере: если игрок быстро
-- перейдёт на другой сервер, старый сервер не затрёт новый прогресс.
-- В Studio сохранение работает, только если включено
-- Game Settings → Security → Enable Studio Access to API Services.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

local Data = {}

local function defaults()
	return {
		coins = 0,
		eggs = { normal = 0, gold = 0, rainbow = 0 },
		pets = {}, -- { {id = 1, kind = "green"}, ... }
		nextPetId = 1,
		equippedPet = 0,
		owned = {},
		equipped = { hat = "", back = "", trail = "" },
		badges = {},
		dailyLast = 0,
		dailyStreak = 0,
		wheelLast = 0,
		codes = {},
		escapes = 0,
		cups = 0,
		migrated = false, -- старое сохранение (до ProfileStore) уже перенесено
	}
end

local Store = ProfileStore.New("DinoEggCatch_v2", defaults())

-- старое хранилище: только читаем, чтобы перенести прогресс
local legacy: DataStore? = nil
pcall(function()
	legacy = DataStoreService:GetDataStore("DinoEggCatch_v1")
end)

-- переносим старое сохранение поверх нового профиля (только поля, которые знает игра)
local function migrate(profileData, player: Player)
	if not legacy then
		return
	end
	local ok, saved = pcall(function()
		return (legacy :: DataStore):GetAsync("u" .. player.UserId)
	end)
	if not ok or type(saved) ~= "table" then
		return
	end
	for k, v in pairs(saved) do
		local d = profileData[k]
		if type(d) == "table" and type(v) == "table" and next(d) ~= nil then
			for k2, v2 in pairs(v) do
				d[k2] = v2
			end
		elseif d ~= nil and type(d) == type(v) then
			profileData[k] = v
		end
	end
end

local profiles: { [Player]: any } = {}
local releasing: { [any]: boolean } = {} -- профили, которые мы закрываем сами

local function key(player: Player): string
	return "u" .. player.UserId
end

-- Загружает профиль (ждёт). Вернёт nil, если игрок ушёл или данные не открылись.
function Data.load(player: Player)
	local profile = Store:StartSessionAsync(key(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Не получилось загрузить прогресс. Зайди в игру ещё раз 🙏")
		end
		return nil
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if releasing[profile] then
			releasing[profile] = nil
			return
		end
		-- профиль забрал другой сервер: этот игрок здесь больше не может играть
		if player.Parent == Players then
			player:Kick("Ты зашёл в игру в другом месте")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	if not profile.Data.migrated then
		migrate(profile.Data, player)
		profile.Data.migrated = true
	end
	profiles[player] = profile
	return profile.Data
end

function Data.get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function Data.isSaving(_player: Player): boolean
	return ProfileStore.DataStoreState == "Access"
end

-- игрок вышел: сохраняем и отпускаем профиль для других серверов
function Data.release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		releasing[profile] = true
		profile:EndSession()
	end
end

return Data
