-- Оживляем картинку у игрока: динозавры шагают, виляют хвостом, моргают и открывают рот,
-- яйца покачиваются, летают бабочки, идёт снег, пепел, листья или светлячки.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("DinoRemotes")
local camera = Workspace.CurrentCamera

-- ---------- анимация динозавров ----------

local rigs: { [Model]: any } = {}

local function setupRig(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local motors = {}
	local lids = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		elseif d:IsA("BasePart") and d.Name == "Eyelid" then
			table.insert(lids, d)
		end
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local scale = model:GetAttribute("Scale") or 1
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 180, 150))
	dust.Size = NumberSequence.new(0.6 * scale, 2 * scale)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Rate = 18
	dust.Enabled = false
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -4.5 * scale, 0)
	att.Parent = root
	dust.Parent = att
	rigs[model] = {
		root = root,
		motors = motors,
		lids = lids,
		scale = scale,
		last = root.Position,
		speed = 0,
		phase = math.random() * 6,
		seed = math.random() * 100,
		nextBlink = os.clock() + math.random() * 4,
		blinkUntil = 0,
		dust = dust,
	}
end

CollectionService:GetInstanceAddedSignal("DinoRig"):Connect(setupRig)
CollectionService:GetInstanceRemovedSignal("DinoRig"):Connect(function(model)
	rigs[model :: Model] = nil
end)
for _, m in ipairs(CollectionService:GetTagged("DinoRig")) do
	setupRig(m)
end

local function setT(motors, name: string, cf: CFrame)
	local m = motors[name]
	if m then
		m.Transform = cf
	end
end

local function animateRigs(dt: number)
	local camPos = camera.CFrame.Position
	local now = os.clock()
	for model, r in pairs(rigs) do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local pos = r.root.Position
		local v = (pos - r.last) / math.max(dt, 1 / 240)
		r.last = pos
		if (pos - camPos).Magnitude > 260 then
			continue -- далеко — не тратим силы
		end
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude / r.scale
		if speed > 200 then
			speed = 0 -- телепорт, а не бег
		end
		r.speed += (speed - r.speed) * math.min(1, dt * 8)
		local run = math.clamp(r.speed / 12, 0, 1)
		r.phase += dt * (3 + r.speed * 0.45)
		local swing = math.sin(r.phase) * 0.75 * run
		local t = now + r.seed
		local chasing = model:GetAttribute("Chasing") == true

		setT(r.motors, "HipFL", CFrame.Angles(swing, 0, 0))
		setT(r.motors, "HipBR", CFrame.Angles(swing, 0, 0))
		setT(r.motors, "HipFR", CFrame.Angles(-swing, 0, 0))
		setT(r.motors, "HipBL", CFrame.Angles(-swing, 0, 0))
		local wag = chasing and 6 or 2.5
		setT(r.motors, "TailA", CFrame.Angles(0, math.sin(t * wag) * 0.22, 0))
		setT(r.motors, "TailB", CFrame.Angles(0, math.sin(t * wag - 0.7) * 0.3, 0))
		setT(r.motors, "TailC", CFrame.Angles(math.sin(t * 1.3) * 0.08, math.sin(t * wag - 1.4) * 0.38, 0))
		setT(r.motors, "Neck", CFrame.Angles(math.sin(t * 2) * 0.06 + math.abs(math.sin(r.phase)) * 0.08 * run, math.sin(t * 0.6) * 0.18 * (1 - run), 0))
		local jaw = chasing and (0.25 + math.abs(math.sin(t * 9)) * 0.3) or math.max(0, math.sin(t * 0.8) - 0.95) * 6
		setT(r.motors, "Jaw", CFrame.Angles(jaw, 0, 0))
		local arm = math.sin(t * (chasing and 14 or 3)) * (chasing and 0.6 or 0.15)
		setT(r.motors, "ArmL", CFrame.Angles(arm, 0, 0))
		setT(r.motors, "ArmR", CFrame.Angles(-arm, 0, 0))

		-- моргание
		if now > r.nextBlink then
			r.nextBlink = now + 2 + math.random() * 4
			r.blinkUntil = now + 0.13
		end
		local closed = now < r.blinkUntil
		for _, lid in ipairs(r.lids) do
			lid.Transparency = closed and 0 or 1
		end
		r.dust.Enabled = r.speed > 8
	end
end

-- ---------- яйца покачиваются ----------

local homes: { [BasePart]: CFrame } = {}
local wobbling: { [BasePart]: number } = {}
local nextWobble = 0

local function wobbleEggs(now: number)
	if now >= nextWobble then
		nextWobble = now + 0.4
		local eggs = CollectionService:GetTagged("Egg")
		if #eggs > 0 then
			local egg = eggs[math.random(#eggs)] :: BasePart
			if egg.Anchored and egg.Transparency < 1 and not wobbling[egg] then
				homes[egg] = egg.CFrame
				wobbling[egg] = now
			end
		end
	end
	for egg, start in pairs(wobbling) do
		local k = now - start
		local home = homes[egg]
		if not egg.Parent or k > 0.9 then
			if egg.Parent and home then
				egg.CFrame = home
			end
			wobbling[egg] = nil
			homes[egg] = nil
		elseif home then
			egg.CFrame = home * CFrame.Angles(0, 0, math.sin(k * 25) * 0.25 * (1 - k / 0.9))
		end
	end
end

-- ---------- бабочки ----------

local localFolder = Instance.new("Folder")
localFolder.Name = "DinoLocalFX"
localFolder.Parent = Workspace

local WING_COLORS = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 230, 90), Color3.fromRGB(180, 130, 255) }
local butterflies = {}
local function newPart(size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = localFolder
	return p
end
local HOMES = {
	Vector3.new(0, 4, 210), Vector3.new(-30, 4, 200), Vector3.new(30, 4, 230), Vector3.new(-50, 4, 240),
	Vector3.new(50, 4, 180), Vector3.new(0, 4, 100), Vector3.new(-100, 4, 110), Vector3.new(100, 4, 110),
	Vector3.new(-120, 4, -100), Vector3.new(120, 4, -100), Vector3.new(0, 4, -110), Vector3.new(-60, 4, 0),
}
for i, home in ipairs(HOMES) do
	local c = WING_COLORS[(i - 1) % #WING_COLORS + 1]
	table.insert(butterflies, {
		home = home,
		body = newPart(Vector3.new(0.12, 0.12, 0.5), Color3.fromRGB(40, 30, 30)),
		left = newPart(Vector3.new(0.7, 0.05, 0.6), c),
		right = newPart(Vector3.new(0.7, 0.05, 0.6), c),
		seed = math.random() * 50,
	})
end

local function flyButterflies(now: number)
	local hidden = remotes:GetAttribute("Theme") == "ice" or remotes:GetAttribute("Theme") == "volcano"
	for _, b in ipairs(butterflies) do
		local t = now * 0.6 + b.seed
		local pos = b.home + Vector3.new(math.sin(t) * 8 + math.sin(t * 2.3) * 3, math.sin(t * 1.7) * 1.5 + 1, math.cos(t * 0.8) * 8)
		local ahead = b.home + Vector3.new(math.sin(t + 0.05) * 8 + math.sin((t + 0.05) * 2.3) * 3, math.sin((t + 0.05) * 1.7) * 1.5 + 1, math.cos((t + 0.05) * 0.8) * 8)
		local cf = CFrame.lookAt(pos, ahead)
		local flap = math.sin(now * 22 + b.seed) * 0.9
		b.body.CFrame = cf
		b.left.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.38, 0, 0)
		b.right.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.38, 0, 0)
		local tr = hidden and 1 or 0
		b.body.Transparency, b.left.Transparency, b.right.Transparency = tr, tr, tr
	end
end

-- ---------- погода вокруг камеры ----------

local sky = newPart(Vector3.new(90, 1, 90), Color3.new(1, 1, 1))
sky.Transparency = 1
local weather = Instance.new("ParticleEmitter")
weather.EmissionDirection = Enum.NormalId.Bottom
weather.Enabled = false
weather.Parent = sky
local currentWeather = ""

local function setWeather(kind: string)
	if kind == currentWeather then
		return
	end
	currentWeather = kind
	weather.Enabled = kind ~= "none" and kind ~= ""
	weather.LightEmission = 0
	weather.Acceleration = Vector3.zero
	weather.RotSpeed = NumberRange.new(0)
	if kind == "snow" then
		weather.Color = ColorSequence.new(Color3.new(1, 1, 1))
		weather.Size = NumberSequence.new(0.35)
		weather.Rate = 220
		weather.Lifetime = NumberRange.new(6, 8)
		weather.Speed = NumberRange.new(5, 8)
		weather.SpreadAngle = Vector2.new(15, 15)
	elseif kind == "ash" then
		weather.Color = ColorSequence.new(Color3.fromRGB(255, 140, 60), Color3.fromRGB(80, 80, 80))
		weather.LightEmission = 0.6
		weather.Size = NumberSequence.new(0.25)
		weather.Rate = 120
		weather.Lifetime = NumberRange.new(6, 9)
		weather.Speed = NumberRange.new(2, 4)
		weather.SpreadAngle = Vector2.new(40, 40)
	elseif kind == "leaves" then
		weather.Color = ColorSequence.new(Color3.fromRGB(90, 170, 60), Color3.fromRGB(200, 170, 60))
		weather.Size = NumberSequence.new(0.5)
		weather.Rate = 30
		weather.Lifetime = NumberRange.new(8, 10)
		weather.Speed = NumberRange.new(2, 4)
		weather.SpreadAngle = Vector2.new(50, 50)
		weather.RotSpeed = NumberRange.new(-120, 120)
	elseif kind == "pollen" then
		weather.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200))
		weather.LightEmission = 1
		weather.Size = NumberSequence.new(0.18)
		weather.Rate = 40
		weather.Lifetime = NumberRange.new(8, 12)
		weather.Speed = NumberRange.new(0.5, 1.5)
		weather.SpreadAngle = Vector2.new(80, 80)
	elseif kind == "fireflies" then
		weather.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120))
		weather.LightEmission = 1
		weather.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
		weather.Rate = 40
		weather.Lifetime = NumberRange.new(4, 6)
		weather.Speed = NumberRange.new(0.5, 1.5)
		weather.SpreadAngle = Vector2.new(90, 90)
		weather.Acceleration = Vector3.new(0, 0.4, 0)
	end
end

-- ---------- каждый кадр ----------

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	animateRigs(dt)
	wobbleEggs(now)
	flyButterflies(now)
	setWeather(remotes:GetAttribute("Weather") or "none")
	local high = (currentWeather == "pollen" or currentWeather == "fireflies") and 12 or 30
	sky.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, high, 0))
end)

Players.LocalPlayer.CharacterAdded:Connect(function()
	camera = Workspace.CurrentCamera
end)
