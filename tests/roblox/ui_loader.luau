-- Загружает экран игры (roblox/src/client/UI) в Lune: Vide со своей заглушкой Roblox,
-- настоящие App.luau, Logic.luau и Config.lua. Кнопки нажимаются настоящими событиями.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

-- заглушка Vide; события кнопок делаем сигналами, как в Roblox
local mock = require("../../roblox/Packages/vide/test/mock")
local EVENTS = { "Activated", "MouseButton1Down", "MouseButton1Up", "MouseLeave", "FocusLost" }
if not (mock :: any).__patched then
	(mock :: any).__patched = true
	local newInstance = mock.Instance.new
	mock.Instance.new = function(class)
		local inst = newInstance(class)
		if class == "TextButton" or class == "ImageButton" or class == "TextBox" then
			for _, e in EVENTS do
				(inst :: any)[e] = mock.Signal.new()
			end
		end
		return inst
	end
end
local vide = require("../../roblox/Packages/vide/src/lib")

local UI = {}
UI.vide = vide
UI.mock = mock

local tokens = { vide = {}, Config = {}, Logic = {}, Packages = {}, DinoShared = {} }
local loaded = {}

local function load(path: string, scriptObj)
	local env = {
		script = scriptObj,
		game = {
			GetService = function()
				return {
					WaitForChild = function(_, name)
						return tokens[name]
					end,
				}
			end,
		},
		task = { delay = function() end, spawn = function(f, ...)
			f(...)
		end },
		require = function(t)
			return loaded[t]
		end,
	}
	for _, name in { "Vector3", "Vector2", "Color3", "CFrame", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence" } do
		env[name] = (roblox :: any)[name]
	end
	return luau.load(fs.readFile(path), { debugName = path, environment = setmetatable(env, { __index = _G }) })()
end

tokens.Packages.WaitForChild = function(_, name)
	return tokens[name]
end
tokens.DinoShared.WaitForChild = function(_, name)
	return tokens[name]
end
loaded[tokens.vide] = vide
loaded[tokens.Config] = load("roblox/src/shared/Config.lua", {})
loaded[tokens.Logic] = load("roblox/src/client/UI/Logic.luau", {})
UI.Config = loaded[tokens.Config]
UI.Logic = loaded[tokens.Logic]
UI.App = load("roblox/src/client/UI/App.luau", { Parent = { Logic = tokens.Logic } })

-- ---------- поиск на экране ----------

function UI.all(root)
	local out = {}
	local function walk(inst)
		for _, c in inst:GetChildren() do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(root)
	return out
end

function UI.byName(root, name: string)
	for _, inst in UI.all(root) do
		if inst.Name == name then
			return inst
		end
	end
	return nil
end

-- кнопка или надпись с таким текстом (или с текстом, где он встречается)
function UI.byText(root, text: string, exact: boolean?)
	for _, inst in UI.all(root) do
		local t = inst.Text
		if type(t) == "string" and (t == text or (not exact and string.find(t, text, 1, true))) then
			return inst
		end
	end
	return nil
end

function UI.press(button)
	assert(button, "кнопки нет на экране")
	button.MouseButton1Down:fire()
	button.MouseButton1Up:fire()
	button.Activated:fire()
end

-- новый экран с записью всех запросов к серверу и звуков
function UI.new(answers)
	local calls, sounds = {}, {}
	local t = 0
	local app = UI.App.new({
		ask = function(action, arg)
			table.insert(calls, { action = action, arg = arg })
			local a = answers and answers[action]
			if type(a) == "function" then
				return a(arg)
			end
			return a or { ok = false }
		end,
		sound = function(name)
			table.insert(sounds, name)
		end,
		speak = function() end,
		emote = function(e)
			table.insert(calls, { action = "emote", arg = e.id })
		end,
		delay = function() end,
	})
	local ui = { app = app, calls = calls, sounds = sounds }
	function ui.tick(dt)
		t += dt
		app.tick(t)
		vide.step(dt)
	end
	function ui.find(text, exact)
		return UI.byText(app.gui, text, exact)
	end
	function ui.named(name)
		return UI.byName(app.gui, name)
	end
	return ui
end

return UI
