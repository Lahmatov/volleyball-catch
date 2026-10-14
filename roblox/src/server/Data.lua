-- Сохранение монеток, питомцев, костюмов и значков.
-- В Studio сохранение работает, только если включено
-- Game Settings → Security → Enable Studio Access to API Services.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Data = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("DinoEggCatch_v1")
end)

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

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
	}
end

local function fill(saved: any)
	local p = defaults()
	if type(saved) ~= "table" then
		return p
	end
	for k, v in pairs(saved) do
		local d = p[k]
		if type(d) == "table" and type(v) == "table" and next(d) ~= nil then
			for k2, v2 in pairs(v) do
				d[k2] = v2
			end
		elseif d ~= nil and type(d) == type(v) then
			p[k] = v
		end
	end
	return p
end

local function key(player: Player): string
	return "u" .. player.UserId
end

function Data.load(player: Player)
	local saved = nil
	local ok = false
	if store then
		for _ = 1, 3 do
			ok = pcall(function()
				saved = (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end
	if not player.Parent then
		-- игрок ушёл, пока грузились данные: PlayerRemoving уже прошёл, профиль не нужен
		return nil
	end
	profiles[player] = fill(saved)
	canSave[player] = ok
	return profiles[player]
end

function Data.get(player: Player)
	return profiles[player]
end

function Data.isSaving(player: Player): boolean
	return canSave[player] == true
end

function Data.save(player: Player)
	local p = profiles[player]
	if not (store and p and canSave[player]) then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync(key(player), p)
	end)
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
	canSave[player] = nil
end

task.spawn(function()
	while true do
		task.wait(90)
		for _, player in ipairs(Players:GetPlayers()) do
			Data.save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Data.save(player)
	end
end)

return Data
