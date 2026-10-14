--[[
	Проверки внутри НАСТОЯЩЕГО Roblox (Open Cloud Luau Execution).
	Сервер игры запускается как обычно, этот скрипт ждёт, пока он построит мир,
	и проверяет то, чего не видят заглушки в Lune: настоящие свойства и классы,
	ландшафт, скелеты динозавров, пакеты, экран на настоящих Instance.
	Запуск: python3 tests/cloud/run_in_roblox.py (нужны ключ и id места, см. README).
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS  " .. name)
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local arena = workspace:WaitForChild("DinoArena", 60)
local park = workspace:WaitForChild("DinoPark", 60)
task.wait(3) -- пусть сервер поживёт несколько кадров

check("C1 Сервер игры запустился без ошибок", function()
	local errors = {}
	for _, entry in ipairs(LogService:GetLogHistory()) do
		if entry.messageType == Enum.MessageType.MessageError then
			table.insert(errors, entry.message)
		end
	end
	assert(#errors == 0, "ошибки в логе:\n" .. table.concat(errors, "\n"))
end)

check("C2 Поле и Динопарк построены", function()
	assert(arena and park, "нет DinoArena или DinoPark")
	assert(park:FindFirstChildOfClass("SpawnLocation"), "нет точки появления")
	assert(#CollectionService:GetTagged("Trampoline") == 3, "батутов не 3")
	assert(#CollectionService:GetTagged("Egg") >= 50, "яиц меньше 50")
end)

check("C3 У каждого динозавра настоящий скелет", function()
	local rigs = CollectionService:GetTagged("DinoRig")
	assert(#rigs >= 11, "динозавров меньше 11 (10 на поле + статуя): " .. #rigs)
	for _, rig in ipairs(rigs) do
		local motors = 0
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("Motor6D") then
				motors += 1
				assert(d.Part0 and d.Part1, rig.Name .. ": сустав без деталей")
			end
		end
		assert(motors == 11, rig.Name .. ": суставов " .. motors .. ", а нужно 11")
		assert(rig.PrimaryPart and rig.PrimaryPart.Anchored, rig.Name .. ": туловище не закреплено")
	end
end)

check("C4 Свет и атмосфера", function()
	assert(Lighting.Technology == Enum.Technology.Future, "освещение не Future")
	assert(Lighting:FindFirstChildOfClass("Atmosphere"), "нет атмосферы")
	assert(workspace.Terrain:FindFirstChildOfClass("Clouds"), "нет облаков")
end)

local function materialAt(pos: Vector3): Enum.Material
	local region = Region3.new(pos - Vector3.new(2, 2, 2), pos + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4)
	return materials[1][1][1]
end

check("C5 Ландшафт: поле травяное, вершины гор ледяные и не меняются от карты", function()
	assert(materialAt(Vector3.new(0, -2, 0)) == Enum.Material.Grass, "поле не трава")
	local Graphics = require(ServerScriptService.DinoServer.Graphics)
	Graphics.applyTheme("ice", "none")
	assert(materialAt(Vector3.new(0, -2, 0)) == Enum.Material.Ice, "на «Льду» поле не ледяное")
	Graphics.applyTheme("field", "none")
	assert(materialAt(Vector3.new(0, -2, 0)) == Enum.Material.Grass, "поле не вернулось в траву")
end)

check("C6 ProfileStore работает в движке (песочница Mock)", function()
	local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
	local store = ProfileStore.New("CloudTest", { coins = 0 }).Mock
	local profile = store:StartSessionAsync("test")
	assert(profile, "профиль не открылся")
	profile.Data.coins = 5
	profile:EndSession()
	local again = store:StartSessionAsync("test")
	assert(again and again.Data.coins == 5, "монетки не сохранились")
	again:EndSession()
end)

check("C7 Экран на Vide собирается из настоящих Instance", function()
	local App = require(StarterPlayer.StarterPlayerScripts.DinoClient.UI.App)
	local app = App.new({
		ask = function(action)
			if action == "hatch" then
				return { ok = true, pet = "rainbow" }
			end
			return { ok = false }
		end,
	})
	app.setData({
		coins = 7, eggs = { normal = 1, gold = 0, rainbow = 0 }, pets = { { id = 1, kind = "gold" } }, equippedPet = 1,
		owned = {}, equipped = { hat = "", back = "", trail = "" }, badges = {}, cups = 0,
		dailyReady = true, dailyDay = 1, dailyWait = 0, wheelReady = true, wheelWait = 0, saving = true, event = "none",
	})
	for _, name in ipairs({ "pets", "shop", "daily", "wheel", "badges", "codes", "emotes" }) do
		app.open(name)
		app.tick(os.clock())
		assert(app.gui:FindFirstChild("Panel", true), "окно " .. name .. " не открылось")
	end
	app.hatch("normal")
	app.setDino(true)
	app.tick(os.clock() + 2)
	assert(app.gui:FindFirstChild("HatchCard", true), "карточка питомца не появилась")
	assert(app.gui:FindFirstChild("DinoPad", true), "нет кнопок динозавра")
	app.destroy()
end)

check("C8 Пакеты на месте", function()
	assert(require(ReplicatedStorage.Packages.vide).version, "Vide не загрузился")
	assert(ReplicatedStorage.Packages:FindFirstChild("TopbarPlus"), "нет TopbarPlus")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error(failed .. " проверок не прошло")
end
return passed
