-- Связка экрана с Roblox: кнопки в верхней панели (TopbarPlus), музыка, звуки, голос,
-- шалости в Динопарке, лёд, тряска. Сам экран — UI/App.luau (Vide).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Icon = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("TopbarPlus"))
local App = require(script.Parent:WaitForChild("UI"):WaitForChild("App"))
local Logic = require(script.Parent.UI:WaitForChild("Logic"))
local remotes = ReplicatedStorage:WaitForChild("DinoRemotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent

local playJingle: () -> ()
local musicOn = true

local function playSound(name: string)
	if name == "win" then
		playJingle()
		return
	end
	local def = Config.SOUNDS[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.PlaybackSpeed = def.speed or 1
	s.Volume = 0.6
	s.Parent = SoundService
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
end

local function ask(action: string, arg: any?): any
	local ok, res = pcall(Request.InvokeServer, Request, action, arg)
	if ok and type(res) == "table" then
		return res
	end
	return { ok = false }
end

-- Голос: Roblox Text-to-Speech. Если не поддерживается — молча пропускаем, надписи всё равно есть.
local function speak(line: string)
	if not Config.VOICE_ENABLED then
		return
	end
	task.spawn(function()
		local tts, out
		local ok = pcall(function()
			tts = Instance.new("AudioTextToSpeech")
			tts.Text = line
			out = Instance.new("AudioDeviceOutput")
			local wire = Instance.new("Wire")
			tts.Parent = SoundService
			out.Parent = SoundService
			wire.SourceInstance = tts
			wire.TargetInstance = out
			wire.Parent = tts
			tts:Play()
		end)
		task.wait(ok and 8 or 0)
		if tts then
			tts:Destroy()
		end
		if out then
			out:Destroy()
		end
	end)
end

local function playEmote(emote)
	if emote.id == "tongue" or emote.id == "fart" then
		ask(emote.id)
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (hum and animator) then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = emote.anim
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = emote.id == "dance"
	track:Play()
	task.spawn(function()
		local start = os.clock()
		task.wait(0.3)
		while track.IsPlaying and os.clock() - start < 6 do
			if hum.MoveDirection.Magnitude > 0.1 then
				break
			end
			task.wait(0.1)
		end
		track:Stop()
	end)
end

-- ---------- экран ----------

local app = App.new({
	ask = ask,
	sound = playSound,
	speak = speak,
	emote = playEmote,
})
app.gui.Parent = player:WaitForChild("PlayerGui")

-- размер экрана: на телефоне экран компактнее (и при повороте тоже)
local function updateViewport()
	local size = workspace.CurrentCamera.ViewportSize
	app.setViewport(size.X, size.Y)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewport)
updateViewport()

-- ---------- кнопки в верхней панели Roblox (TopbarPlus) ----------

local icons = {}
local function menuIcon(panelName: string, label: string, order: number)
	local icon = Icon.new()
	icon:setLabel(label)
	icon:setOrder(order)
	icon:oneClick(true)
	icon:bindEvent("selected", function()
		app.open(panelName)
	end)
	icons[panelName] = icon
	return icon
end
menuIcon("pets", "🐣 Питомцы", 1)
menuIcon("shop", "🛒 Магазин", 2)
menuIcon("daily", "🎁 Подарок", 3)
menuIcon("wheel", "🎡 Колесо", 4)
menuIcon("badges", "🏅 Значки", 5)
menuIcon("codes", "🔑 Коды", 6)
menuIcon("emotes", "😀 Эмоции", 7)
local musicIcon = Icon.new()
musicIcon:setLabel("🎵")
musicIcon:align("Right")
musicIcon:oneClick(true)
musicIcon:bindEvent("selected", function()
	musicOn = not musicOn
	musicIcon:setLabel(musicOn and "🎵" or "🔇")
	app.toast(musicOn and "🎵 Музыка включена" or "🔇 Музыка выключена")
end)

-- красные точки: подарок, колесо, яйца
local shownDots = {}
local function updateDots(view)
	for name, on in pairs(Logic.dots(view)) do
		if on ~= shownDots[name] then
			shownDots[name] = on
			if on then
				icons[name]:notify()
			else
				icons[name]:clearNotices()
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		app.dinoAction("roar")
	elseif input.KeyCode == Enum.KeyCode.F then
		app.dinoAction("dash")
	end
end)

-- ---------- музыка ----------
-- Мелодии играются нотами из встроенного звука Roblox, поэтому чужие аудио не нужны.

local NOTE_INDEX = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local function parseLine(line: string): { number | boolean }
	local out = {}
	for tok in line:gmatch("%S+") do
		if tok == "-" then
			table.insert(out, false)
		else
			local letter, acc, octave = tok:match("^(%a)([#b]?)(%d)$")
			local n = 12 * (tonumber(octave) :: number + 1) + NOTE_INDEX[letter] + (acc == "#" and 1 or acc == "b" and -1 or 0)
			table.insert(out, n)
		end
	end
	return out
end

local SONGS = {
	-- весёлая прыгучая для Динопарка
	lobby = {
		bpm = 132,
		melody = parseLine("C5 - E5 G5 C6 - G5 E5 F5 - A5 F5 G5 - - - E5 - G5 E5 D5 - C5 D5 E5 - D5 B4 C5 - - -"),
		bass = parseLine("C3 - G3 - C3 - G3 - F3 - C4 - G3 - D3 - C3 - G3 - A3 - E3 - F3 - G3 - C3 - G3 -"),
	},
	-- быстрая приключенческая для игры
	round = {
		bpm = 152,
		melody = parseLine("A4 C5 E5 A5 G5 E5 C5 E5 F5 A5 C6 A5 G5 E5 D5 E5 A4 C5 E5 A5 B5 A5 G5 E5 F5 E5 D5 B4 A4 - - -"),
		bass = parseLine("A2 - A3 - A2 - A3 - F2 - F3 - F2 - F3 - C3 - C4 - G2 - G3 - E2 - E3 - A2 - A2 -"),
	},
	-- тревожная, когда приходит Ти-Рекс
	boss = {
		bpm = 176,
		melody = parseLine("E5 - E5 F5 E5 - D#5 - E5 - G5 - F5 - D#5 -"),
		bass = parseLine("E2 E3 E2 E3 E2 E3 F2 F3 E2 E3 E2 E3 G2 G3 F2 F3"),
	},
}
local JINGLE = parseLine("C5 E5 G5 C6 - G5 C6 C6")

local notePool = {}
for i = 1, 12 do
	local snd = Instance.new("Sound")
	snd.SoundId = Config.SOUNDS.note.id
	snd.Parent = SoundService
	notePool[i] = snd
end
local poolIndex = 0
local function playNote(midi: number, volume: number)
	poolIndex = poolIndex % #notePool + 1
	local snd = notePool[poolIndex]
	snd.PlaybackSpeed = 2 ^ ((midi - 72) / 12)
	snd.Volume = volume
	snd.TimePosition = 0
	snd:Play()
end

local jinglePlaying = false
playJingle = function()
	if jinglePlaying then
		return
	end
	jinglePlaying = true
	task.spawn(function()
		for _, n in ipairs(JINGLE) do
			if n then
				playNote(n :: number, Config.MUSIC_VOLUME * 1.6)
			end
			task.wait(0.15)
		end
		task.wait(0.4)
		jinglePlaying = false
	end)
end

local function songName(): string
	if remotes:GetAttribute("Boss") then
		return "boss"
	end
	return (remotes:GetAttribute("TimeLeft") or -1) >= 0 and "round" or "lobby"
end

task.spawn(function()
	local playing: string? = nil
	local custom: Sound? = nil
	local step = 0
	local nextT = os.clock()
	while true do
		local name = musicOn and songName() or nil
		if name ~= playing then
			playing = name
			step = 0
			if custom then
				custom:Destroy()
				custom = nil
			end
			local id = name and Config.MUSIC[name] or ""
			if id ~= "" then
				local snd = Instance.new("Sound")
				snd.SoundId = id
				snd.Looped = true
				snd.Volume = Config.MUSIC_VOLUME
				snd.Parent = SoundService
				snd:Play()
				custom = snd
			end
		end
		local song = name and SONGS[name]
		if song and not custom and not jinglePlaying then
			step += 1
			local m = song.melody[(step - 1) % #song.melody + 1]
			local b = song.bass[(step - 1) % #song.bass + 1]
			if m then
				playNote(m :: number, Config.MUSIC_VOLUME)
			end
			if b then
				playNote(b :: number, Config.MUSIC_VOLUME * 0.8)
			end
		end
		nextT += song and 60 / song.bpm / 2 or 0.25
		local wait = nextT - os.clock()
		if wait < -0.5 then
			nextT = os.clock()
			wait = 0
		end
		task.wait(math.max(0, wait))
	end
end)

-- ---------- шалости в Динопарке: батуты, бананы, горка, пукалки, грибы ----------

local BOUNCE_WORDS = { "Уиии! 🤸", "Выше неба! ☁️", "Я птица! 🐦", "Йу-ху! 🚀" }
local cool = { bounce = 0, slip = 0, fart = 0, mushroom = 0, slide = 0 }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function near(root: BasePart, p: BasePart, radius: number, height: number): boolean
	local d = Vector3.new(root.Position.X - p.Position.X, 0, root.Position.Z - p.Position.Z).Magnitude
	return d < radius and math.abs(root.Position.Y - p.Position.Y) < height
end

local function slip(hum: Humanoid, root: BasePart)
	cool.slip = os.clock() + 3
	playSound("slip")
	app.toast("Ой! Банан! 🍌😂")
	hum.PlatformStand = true
	root.AssemblyLinearVelocity = root.CFrame.LookVector * 25 + Vector3.new(0, 18, 0)
	root.AssemblyAngularVelocity = root.CFrame.RightVector * 10
	task.delay(1.3, function()
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	for _, p in ipairs(CollectionService:GetTagged("Trampoline")) do
		if now > cool.bounce and near(root, p, 3.4, 5) then
			cool.bounce = now + 0.5
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, 95, v.Z)
			playSound("boing")
			if math.random() < 0.3 then
				app.toast(BOUNCE_WORDS[math.random(#BOUNCE_WORDS)])
			end
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Banana")) do
		if now > cool.slip and near(root, p, 1.8, 4) then
			slip(hum, root)
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Fart")) do
		if now > cool.fart and near(root, p, 2.4, 4) then
			cool.fart = now + 2.5
			task.spawn(ask, "fart")
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Mushroom")) do
		if now > cool.mushroom and near(root, p, 3, 5) then
			cool.mushroom = now + 5
			task.spawn(ask, "mushroom", p:GetAttribute("Kind"))
		end
	end
	rayParams.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), rayParams)
	if hit and CollectionService:HasTag(hit.Instance, "Slide") then
		local dir = hit.Instance:GetAttribute("Dir")
		if typeof(dir) == "Vector3" then
			root.AssemblyLinearVelocity = dir * 55
		end
		if now > cool.slide then
			cool.slide = now + 3
			app.toast("Уииии! 🛝")
			playSound("swoosh")
		end
	end
end)

-- ---------- данные и события с сервера ----------

local shakeUntil = 0
Notify.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "data" then
		app.setData(payload)
		updateDots(payload)
	elseif kind == "toast" then
		app.toast(payload)
	elseif kind == "big" then
		app.big(payload.text, payload.seconds or 2.5)
	elseif kind == "voice" then
		speak(payload)
	elseif kind == "sound" then
		playSound(payload)
	elseif kind == "badge" then
		app.big("🏅 Новый значок: " .. payload.icon .. " " .. payload.name, 3)
	elseif kind == "panel" then
		app.open(payload)
	elseif kind == "role" then
		app.setDino(payload.dino)
	elseif kind == "shake" then
		shakeUntil = os.clock() + 0.6 * (payload or 1)
	end
end)

task.spawn(function()
	local view = ask("getData")
	if view and view.coins then
		app.setData(view)
		updateDots(view)
	end
end)

-- ---------- табло, время экрана, лёд, тряска ----------

task.spawn(function()
	while true do
		app.setHud({
			humans = remotes:GetAttribute("Humans") or 0,
			dinos = remotes:GetAttribute("Dinos") or 0,
			timeLeft = remotes:GetAttribute("TimeLeft") or -1,
			status = remotes:GetAttribute("Status") or "",
			map = remotes:GetAttribute("Map") or "",
			dinoPlayer = remotes:GetAttribute("DinoPlayer") or "",
			boss = remotes:GetAttribute("Boss") == true,
		})
		task.wait(0.2)
	end
end)

local slide = Vector3.zero
RunService.RenderStepped:Connect(function(dt)
	app.tick(os.clock())
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hum and root) then
		return
	end

	-- на льду скользишь
	if remotes:GetAttribute("Theme") == "ice" and hum.FloorMaterial == Enum.Material.Ice then
		local want = hum.MoveDirection * hum.WalkSpeed
		slide = slide:Lerp(want, math.min(1, dt * 2.2))
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(slide.X, v.Y, slide.Z)
	else
		local v = root.AssemblyLinearVelocity
		slide = Vector3.new(v.X, 0, v.Z)
	end

	-- тряска экрана от Ти-Рекса и рыка
	if os.clock() < shakeUntil then
		hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.8
	elseif hum.CameraOffset.Magnitude > 0 then
		hum.CameraOffset = Vector3.zero
	end
end)

