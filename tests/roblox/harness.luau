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
		for _, f in self.handlers do
			f(...)
		end
	end
	return s
end

-- ---------- заглушка Instance ----------

local Methods = {}
local meta = {}
local SIGNALS = { Triggered = true, PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, CharacterAdded = true, Died = true, Activated = true }

meta.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
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
function Methods:IsA(cls)
	return self.ClassName == cls or (cls == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
end
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
function Methods:GetDataStore()
	return H.store
end
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
		task = {
			spawn = function(f, ...)
				local co = coroutine.create(f)
				coroutine.resume(co, ...)
			end,
			wait = function()
				coroutine.yield()
			end,
			delay = function() end,
		},
		os = setmetatable({
			time = function()
				return H.now
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
	H.sent = {}
	H.fills = {}
	H.now = 1000000
	nextId = 1
	H.month = opts.month
	H.saved = opts.saved or {}
	H.store = {
		GetAsync = function(_, key)
			return H.saved[key]
		end,
		SetAsync = function(_, key, value)
			H.saved[key] = value
		end,
	}
	H.game = new("DataModel")
	local game = H.game
	local rs = game:GetService("ReplicatedStorage")
	local shared = new("Folder")
	shared.Name = "DinoShared"
	shared.Parent = rs
	H.modules = { Config = moduleScript(shared, "Config", "roblox/src/shared/Config.lua") }
	local server = new("Folder")
	server.Name = "DinoServer"
	server.Parent = game:GetService("ServerScriptService")
	for _, name in { "Net", "Data", "Progress", "Graphics" } do
		H.modules[name] = moduleScript(server, name, "roblox/src/server/" .. name .. ".lua")
	end
	local terrain = new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = game:GetService("Workspace")
	math.randomseed(opts.seed or 42)
	return H
end

function H.load(name)
	return H.require(H.modules[name])
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
