-- Тестовый стенд: запускает настоящие модули игры из roblox/src в Lune,
-- а Roblox (сервисы, Instance, DataStore, Terrain) заменяет маленькими заглушками.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local H = {}

local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		-- как в Roblox: каждый обработчик в своём потоке, ему можно ждать
		for _, f in self.handlers do
			H.task.spawn(f, ...)
		end
	end
	return s
end

-- ---------- заглушка Instance ----------

local Methods = {}
local meta = {}
local SIGNALS = { Changed = true, Triggered = true, PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, CharacterAdded = true, Died = true, Activated = true }

meta.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	if Methods[k] then
		return Methods[k]
	end
	for _, c in rawget(self, "_children") do
		if c.Name == k then
			return c
		end
	end
	if SIGNALS[k] then
		local s = Signal()
		props[k] = s
		return s
	end
	return nil
end
meta.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		if v then
			table.insert(rawget(v, "_children"), self)
		end
	end
	props[k] = v
end

local function new(className: string)
	local self = setmetatable({ _props = { ClassName = className, Name = className }, _children = {}, _attrs = {} }, meta)
	if className == "IntValue" or className == "NumberValue" then
		self.Value = 0
	end
	return self
end
H.new = new

function Methods:FindFirstChild(name)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function Methods:WaitForChild(name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild: no " .. tostring(name) .. " in " .. self.Name)
	return c
end
function Methods:FindFirstChildOfClass(cls)
	for _, c in rawget(self, "_children") do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function Methods:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Methods:GetDescendants()
	local out = {}
	for _, c in rawget(self, "_children") do
		table.insert(out, c)
		for _, d in c:GetDescendants() do
			table.insert(out, d)
		end
	end
	return out
end
local BASE_PARTS = { Part = true, SpawnLocation = true, TrussPart = true, WedgePart = true, MeshPart = true }
function Methods:IsA(cls)
	return self.ClassName == cls or (cls == "BasePart" and BASE_PARTS[self.ClassName] == true)
end
local function parts(self)
	local out = {}
	if self:IsA("BasePart") then
		table.insert(out, self)
	end
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function Methods:GetPivot()
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local primary = self.PrimaryPart or parts(self)[1]
	return primary and primary.CFrame or roblox.CFrame.identity
end
-- двигаем модель целиком, как в Roblox
function Methods:PivotTo(cf)
	local offset = cf * self:GetPivot():Inverse()
	for _, p in parts(self) do
		if p.CFrame then
			p.CFrame = offset * p.CFrame
		end
	end
end
function Methods:Clone()
	local copy = new(self.ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" and type(v) ~= "table" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for t in (H.tags[self] or {}) do
		H.tags[copy] = H.tags[copy] or {}
		H.tags[copy][t] = true
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = copy
	end
	return copy
end
function Methods:AddTag(inst, tag)
	H.tags[inst] = H.tags[inst] or {}
	H.tags[inst][tag] = true
end
function Methods:HasTag(inst, tag)
	return H.tags[inst] ~= nil and H.tags[inst][tag] == true
end
function Methods:GetTagged(tag)
	local out = {}
	for inst, tags in H.tags do
		if tags[tag] then
			table.insert(out, inst)
		end
	end
	return out
end
function Methods:GetPlayerFromCharacter(char)
	for _, p in self:GetPlayers() do
		if p.Character == char then
			return p
		end
	end
	return nil
end
function Methods:LoadCharacter()
	H.loadCharacter(self)
end
function Methods:Kick(msg)
	self.Kicked = msg or true
	self.Parent = nil
end
function Methods:Play() end
function Methods:Stop() end
function Methods:Emit() end
function Methods:Destroy()
	self.Parent = nil
end
function Methods:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Methods:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Methods:GetPropertyChangedSignal()
	return Signal()
end
function Methods:FireClient(player, kind, payload)
	table.insert(H.sent, { player = player, kind = kind, payload = payload })
end
function Methods:FireAllClients(kind, payload)
	table.insert(H.sent, { kind = kind, payload = payload })
end
function Methods:GetService(name)
	local s = self:FindFirstChild(name)
	if not s then
		s = new(name)
		s.Name = name
		s.Parent = self
	end
	return s
end
function Methods:BindToClose() end
function Methods:GetPlayers()
	local out = {}
	for _, c in rawget(self, "_children") do
		if c.ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
-- ---------- DataStore: как настоящий, данные копируются при записи и чтении ----------

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end
H.deepCopy = deepCopy

local function newStore(name)
	local store = { name = name, data = {}, versions = {} }
	local function keyInfo(key)
		local version = store.versions[key] or 0
		return {
			Version = "v" .. version,
			CreatedTime = 0,
			UpdatedTime = H.now * 1000,
			GetMetadata = function()
				return {}
			end,
			GetUserIds = function()
				return {}
			end,
		}
	end
	function store:GetAsync(key)
		return deepCopy(self.data[key]), keyInfo(key)
	end
	function store:SetAsync(key, value)
		self.data[key] = deepCopy(value)
		self.versions[key] = (self.versions[key] or 0) + 1
	end
	function store:RemoveAsync(key)
		local old = self.data[key]
		self.data[key] = nil
		return old
	end
	function store:UpdateAsync(key, transform)
		local new = transform(deepCopy(self.data[key]), keyInfo(key))
		if new ~= nil then
			self:SetAsync(key, new)
		end
		return deepCopy(self.data[key]), keyInfo(key)
	end
	return store
end
function Methods:GetDataStore(name)
	H.stores[name] = H.stores[name] or newStore(name)
	return H.stores[name]
end
function Methods:SetExperimentalFeatures() end
function Methods:IsStudio()
	return true
end
local guid = 0
function Methods:GenerateGUID()
	guid += 1
	return "guid-" .. guid
end
function Methods:SubscribeAsync()
	return { Disconnect = function() end }
end
function Methods:PublishAsync() end
function Methods:AwardBadge() end
-- ландшафт: запоминаем, чем и что залито
function Methods:Clear()
	H.fills = {}
end
function Methods:SetMaterialColor() end
local function fill(kind)
	return function(_, a, b, c, d)
		local material = d or c
		local where = typeof(a) == "CFrame" and a.Position or a
		table.insert(H.fills, { kind = kind, pos = where, size = b, material = material })
	end
end
Methods.FillBlock = fill("block")
Methods.FillBall = fill("ball")
Methods.FillCylinder = function(_, cf, height, radius, material)
	table.insert(H.fills, { kind = "cylinder", pos = cf.Position, size = radius, material = material })
end
function Methods:ReplaceMaterial(_region, _res, from, to)
	-- для теста весь мир попадает в регион; повторы по кусочкам ничего не меняют
	for _, f in H.fills do
		if f.material == from then
			f.material = to
		end
	end
end

-- ---------- загрузка модулей игры ----------

local cache = {}
local nextId = 1
local function makeEnv(scriptObj)
	local env = {
		script = scriptObj,
		game = H.game,
		workspace = H.game:GetService("Workspace"),
		Instance = { new = new },
		task = H.task,
		os = setmetatable({
			time = function()
				return H.now
			end,
			clock = function()
				return H.clock
			end,
			date = function(fmt, t)
				if H.month and fmt == "!*t" then
					return { month = H.month }
				end
				return os.date(fmt, t)
			end,
		}, { __index = os }),
		require = function(m)
			return H.require(m)
		end,
	}
	for _, name in { "Vector3", "Vector2", "Color3", "CFrame", "Region3", "Enum", "UDim", "UDim2", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "PhysicalProperties" } do
		env[name] = (roblox :: any)[name]
	end
	return setmetatable(env, { __index = _G })
end

function H.require(m)
	if cache[m] then
		return cache[m]
	end
	local path = m._path
	assert(path, "require: not a game module")
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = makeEnv(m) })
	local result = fn()
	cache[m] = result
	return result
end

-- ---------- виртуальное время: task.wait / task.delay / Heartbeat ----------

local queue = {}
local stepNo = 0
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)), 0)
	end
end
H.task = {
	spawn = function(f, ...)
		local co = type(f) == "thread" and f or coroutine.create(f)
		resume(co, ...)
		return co
	end,
	defer = function(f, ...)
		local co = type(f) == "thread" and f or coroutine.create(f)
		table.insert(queue, { at = H.clock, co = co, args = table.pack(...), step = stepNo })
		return co
	end,
	cancel = function(co)
		for i, item in queue do
			if item.co == co then
				table.remove(queue, i)
				break
			end
		end
		pcall(coroutine.close, co)
	end,
	wait = function(n)
		local co = coroutine.running()
		table.insert(queue, { at = H.clock + (n or 0), co = co, step = stepNo })
		return coroutine.yield()
	end,
	delay = function(n, f, ...)
		local co = type(f) == "thread" and f or coroutine.create(f)
		table.insert(queue, { at = H.clock + (n or 0), co = co, args = table.pack(...), step = stepNo })
		return co
	end,
}

-- прожить dt секунд игрового времени
function H.step(dt)
	H.clock += dt
	stepNo += 1
	while true do
		local due
		for i, item in queue do
			-- как в Roblox: то, что заснуло в этом кадре, проснётся не раньше следующего
			if item.at <= H.clock and item.step < stepNo then
				due = table.remove(queue, i)
				break
			end
		end
		if not due then
			break
		end
		if due.args then
			resume(due.co, table.unpack(due.args, 1, due.args.n))
		else
			resume(due.co, dt)
		end
	end
	H.game:GetService("RunService").Heartbeat:Fire(dt)
end

-- выполнить функцию, которой можно ждать (как в своём потоке Roblox), и прожить время, пока она не закончит
function H.await(fn, ...)
	local results
	local co = coroutine.create(function(...)
		results = table.pack(fn(...))
	end)
	resume(co, ...)
	local guard = 0
	while coroutine.status(co) ~= "dead" do
		guard += 1
		assert(guard < 6000, "H.await: функция не закончилась за 100 секунд игрового времени")
		H.step(1 / 60)
	end
	return table.unpack(results, 1, results.n)
end

function H.run(seconds, dt)
	dt = dt or 1 / 20
	for _ = 1, math.ceil(seconds / dt) do
		H.step(dt)
	end
end

local function moduleScript(parent, name, path)
	local m = new("ModuleScript")
	m.Name = name
	rawset(m, "_path", path)
	m.Parent = parent
	return m
end

-- Новый чистый «сервер»: свежие модули, без игроков, время = 1 000 000.
function H.fresh(opts)
	opts = opts or {}
	table.clear(cache)
	table.clear(queue)
	H.clock = 0
	H.tags = setmetatable({}, { __mode = "k" })
	H.sent = {}
	H.fills = {}
	H.now = 1000000
	nextId = 1
	H.month = opts.month
	H.stores = {}
	H.game = new("DataModel")
	local game = H.game
	game.PlaceId = 1
	game.JobId = "test-server"
	-- старые сохранения (до ProfileStore)
	game:GetService("DataStoreService"):GetDataStore("DinoEggCatch_v1").data = deepCopy(opts.saved or {})
	local rs = game:GetService("ReplicatedStorage")
	local shared = new("Folder")
	shared.Name = "DinoShared"
	shared.Parent = rs
	H.modules = { Config = moduleScript(shared, "Config", "roblox/src/shared/Config.lua") }
	local server = new("Folder")
	server.Name = "DinoServer"
	server.Parent = game:GetService("ServerScriptService")
	for _, name in { "Net", "Data", "Progress", "Graphics", "Models", "Arena", "Looks", "Lobby", "AntiCheat" } do
		H.modules[name] = moduleScript(server, name, "roblox/src/server/" .. name .. ".lua")
	end
	H.modules.Main = moduleScript(server, "Main", "roblox/src/server/Main.server.lua")
	local serverPackages = new("Folder")
	serverPackages.Name = "ServerPackages"
	serverPackages.Parent = game:GetService("ServerScriptService")
	H.modules.ProfileStore = moduleScript(serverPackages, "ProfileStore", "roblox/Packages/ProfileStore/ProfileStore.luau")
	local terrain = new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = game:GetService("Workspace")
	math.randomseed(opts.seed or 42)
	return H
end

function H.load(name)
	return H.require(H.modules[name])
end

-- ---------- игроки и персонажи ----------

local function part(parent, name, size, cf)
	local p = new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

function H.loadCharacter(player)
	if player.Character then
		player.Character:Destroy()
	end
	local ws = H.game:GetService("Workspace")
	local spawnCF = roblox.CFrame.new(0, 4, 0)
	local lobby = ws:FindFirstChild("DinoPark")
	local spawn = lobby and lobby:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawnCF = spawn.CFrame + roblox.Vector3.new(0, 3.5, 0)
	end
	local char = new("Model")
	char.Name = player.Name
	local hum = new("Humanoid")
	hum.Name = "Humanoid"
	hum.Health = 100
	hum.HipHeight = 2
	hum.WalkSpeed = 16
	hum.JumpHeight = 7.2
	hum.MoveDirection = roblox.Vector3.zero
	hum.CameraOffset = roblox.Vector3.zero
	hum.Parent = char
	local root = part(char, "HumanoidRootPart", roblox.Vector3.new(2, 2, 1), spawnCF)
	part(char, "Head", roblox.Vector3.new(1.2, 1.2, 1.2), spawnCF * roblox.CFrame.new(0, 1.6, 0))
	part(char, "UpperTorso", roblox.Vector3.new(2, 1.6, 1), spawnCF * roblox.CFrame.new(0, 0.3, 0))
	char.PrimaryPart = root
	char.Parent = ws
	player.Character = char
	player.CharacterAdded:Fire(char)
	return char
end

-- игрок честно идёт к точке со своей скоростью WalkSpeed, сервер живёт каждый шаг
function H.walkTo(player, target, timeout)
	local dt = 1 / 20
	local t = 0
	while t < (timeout or 20) do
		local char = player.Character
		local root = char.HumanoidRootPart
		local hum = char.Humanoid
		local here = root.Position
		local flat = roblox.Vector3.new(target.X - here.X, 0, target.Z - here.Z)
		if flat.Magnitude < 0.5 then
			return true
		end
		local stepLen = math.min(flat.Magnitude, hum.WalkSpeed * dt)
		if stepLen > 0 then
			root.CFrame = roblox.CFrame.new(here + flat.Unit * stepLen)
		end
		H.step(dt)
		t += dt
	end
	return false
end

function H.root(player)
	return player.Character.HumanoidRootPart
end

function H.invoke(player, action, arg)
	local request = H.game:GetService("ReplicatedStorage").DinoRemotes.Request
	return request.OnServerInvoke(player, action, arg)
end

function H.attr(name)
	return H.game:GetService("ReplicatedStorage").DinoRemotes:GetAttribute(name)
end

-- запустить весь сервер игры (Main) и подключить игроков
function H.startServer()
	H.require(H.modules.Main)
end

function H.join(name)
	local p = H.addPlayer(name)
	H.game:GetService("Players").PlayerAdded:Fire(p)
	H.loadCharacter(p)
	return p
end

function H.addPlayer(name)
	local p = new("Player")
	p.Name = name or ("Player" .. nextId)
	p.DisplayName = p.Name
	p.UserId = nextId
	nextId += 1
	p.Parent = H.game:GetService("Players")
	return p
end

return H
