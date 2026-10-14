--[[
	Dino Egg Catch — игра для Roblox.

	Положи этот Script в ServerScriptService и нажми Play.
	Скрипт сам строит поле: 10 кругов, в каждом динозавр
	(золотой, радужный, зелёный или красный) и 5 яиц на полу.

	Правила:
	  * Забеги в круг, возьми яйцо и убеги подальше — яйцо твоё (+1 людям).
	  * Если динозавр поймает человека — динозаврам 1 поинт.
	  * В круге может быть только один человек. Если второй лезет,
	    круг ломается и выталкивает его.
	  * Играют максимум 5 человек, один тайм — 2 минуты.
	  * Кто набрал больше, получает кубок.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	ROUND_TIME = 120,
	INTERMISSION = 10,
	MAX_PLAYERS = 5,
	CIRCLE_RADIUS = 14,
	ZONE_RADIUS = 26, -- динозавр может выйти из круга до сюда; убежал дальше с яйцом — яйцо твоё
	CATCH_DISTANCE = 5,
	EGG_RESPAWN = 10,
	STUN_TIME = 1.5,
	WALK_SPEED = 16,
	GROUND_Y = 0.05,
}

local WHITE = Color3.fromRGB(247, 243, 227)
local DINO_TYPES = {
	{ kind = "gold", name = "Золотой", color = Color3.fromRGB(242, 194, 48), dark = Color3.fromRGB(185, 134, 12), speed = 15 },
	{ kind = "rainbow", name = "Радужный", color = Color3.fromRGB(255, 80, 80), dark = Color3.fromRGB(90, 60, 160), speed = 14.5 },
	{ kind = "green", name = "Зелёный", color = Color3.fromRGB(108, 207, 69), dark = Color3.fromRGB(44, 107, 30), speed = 12.5 },
	{ kind = "red", name = "Красный", color = Color3.fromRGB(226, 81, 58), dark = Color3.fromRGB(140, 36, 22), speed = 13.5 },
}

-- ---------- helpers ----------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDist(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addLabel(adornee: BasePart, text: string, offsetY: number, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 36)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Parent = bb
	bb.Parent = adornee
	return t
end

-- ---------- арена ----------

local old = Workspace:FindFirstChild("DinoArena")
if old then
	old:Destroy()
end
local arena = Instance.new("Folder")
arena.Name = "DinoArena"
arena.Parent = Workspace

local FIELD_X, FIELD_Z = 330, 170
local floor = newPart(arena, Vector3.new(FIELD_X, 1, FIELD_Z), CFrame.new(0, CONFIG.GROUND_Y - 0.5, 0), Color3.fromRGB(79, 154, 60), Enum.Material.Grass)
floor.CanCollide = true
floor.Name = "Field"

-- низкие бортики вокруг поля
for _, w in ipairs({
	{ Vector3.new(FIELD_X, 3, 2), Vector3.new(0, 1.5, FIELD_Z / 2) },
	{ Vector3.new(FIELD_X, 3, 2), Vector3.new(0, 1.5, -FIELD_Z / 2) },
	{ Vector3.new(2, 3, FIELD_Z), Vector3.new(FIELD_X / 2, 1.5, 0) },
	{ Vector3.new(2, 3, FIELD_Z), Vector3.new(-FIELD_X / 2, 1.5, 0) },
}) do
	local wall = newPart(arena, w[1], CFrame.new(w[2]), WHITE, Enum.Material.WoodPlanks)
	wall.CanCollide = true
end

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.CFrame = CFrame.new(0, CONFIG.GROUND_Y, 0)
spawn.Color = Color3.fromRGB(47, 111, 216)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Duration = 0
spawn.Parent = arena

-- ---------- круги, яйца, динозавры ----------

type Egg = { part: Part, home: CFrame, taken: any, respawnAt: number }
type Circle = {
	center: Vector3,
	dinoType: any,
	eggs: { Egg },
	ring: { Part },
	occupant: Player?,
	crackUntil: number,
	cracked: boolean,
	dino: Model,
	dinoPos: Vector3,
	dinoFace: Vector3,
	colorParts: { BasePart },
}

local function buildDino(dinoType, center: Vector3)
	local model = Instance.new("Model")
	model.Name = dinoType.name .. " динозавр"
	local c, d = dinoType.color, dinoType.dark
	local colorParts = {}

	local body = newPart(model, Vector3.new(5, 4, 7), CFrame.new(0, 4.5, 0), c)
	local head = newPart(model, Vector3.new(3.5, 3, 4.5), CFrame.new(0, 7, -5), c)
	local tail = newPart(model, Vector3.new(2, 2, 7), CFrame.new(0, 4, 6.5) * CFrame.Angles(math.rad(-12), 0, 0), c)
	table.insert(colorParts, body)
	table.insert(colorParts, head)
	table.insert(colorParts, tail)
	newPart(model, Vector3.new(3, 1, 3.5), CFrame.new(0, 5.3, -5.6), d)
	for _, x in ipairs({ -1.3, 1.3 }) do
		local eye = newPart(model, Vector3.new(1, 1, 1), CFrame.new(x, 7.8, -6.8), Color3.new(1, 1, 1))
		eye.Shape = Enum.PartType.Ball
		local pupil = newPart(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, 7.8, -7.25), Color3.new(0, 0, 0))
		pupil.Shape = Enum.PartType.Ball
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		for _, z in ipairs({ -2, 2 }) do
			newPart(model, Vector3.new(1.6, 3, 1.6), CFrame.new(x, 1.5, z), d)
		end
	end
	for i = 0, 3 do
		newPart(model, Vector3.new(0.4, 1.6, 1.6), CFrame.new(0, 6.8, -2.5 + i * 1.8) * CFrame.Angles(math.rad(45), 0, 0), d)
	end

	model.PrimaryPart = body
	addLabel(head, dinoType.name, 4, c)
	model:PivotTo(CFrame.new(center + Vector3.new(0, 4.5, 0)))
	model.Parent = arena
	return model, colorParts
end

local function makeEgg(parent: Instance, cframe: CFrame, gold: boolean): Part
	local egg = newPart(parent, Vector3.new(1.4, 1.9, 1.4), cframe, gold and Color3.fromRGB(255, 216, 74) or Color3.fromRGB(251, 246, 230))
	egg.Name = "Egg"
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	return egg
end

local circles: { Circle } = {}
local R, ZONE = CONFIG.CIRCLE_RADIUS, CONFIG.ZONE_RADIUS

for i = 1, 10 do
	local col = (i - 1) % 5
	local row = (i - 1) // 5
	local center = Vector3.new(-128 + col * 64 + (row == 0 and -8 or 8), CONFIG.GROUND_Y, row == 0 and -40 or 40)
	local dinoType = DINO_TYPES[(i - 1) % 4 + 1]

	local disc = newPart(arena, Vector3.new(0.1, R * 2, R * 2), CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(63, 132, 48))
	disc.Shape = Enum.PartType.Cylinder

	-- круг из мела: 24 кусочка, чтобы его можно было «сломать»
	local ring = {}
	local N = 24
	local segLen = 2 * math.pi * R / N * 0.9
	for s = 0, N - 1 do
		local a = s / N * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * R, 0.15, math.sin(a) * R)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		table.insert(ring, newPart(arena, Vector3.new(0.8, 0.3, segLen), CFrame.lookAt(pos, pos + tangent), WHITE))
	end
	-- точки на границе, за которую надо убежать
	for s = 0, 15 do
		local a = s / 16 * math.pi * 2
		local dot = newPart(arena, Vector3.new(0.6, 0.2, 0.6), CFrame.new(center + Vector3.new(math.cos(a) * ZONE, 0.1, math.sin(a) * ZONE)), WHITE)
		dot.Transparency = 0.5
	end

	local eggs = {}
	for e = 0, 4 do
		local a = -math.pi / 2 + e * (math.pi * 2 / 5)
		local home = CFrame.new(center + Vector3.new(math.cos(a) * R * 0.6, 0.95, math.sin(a) * R * 0.6))
		table.insert(eggs, { part = makeEgg(arena, home, dinoType.kind == "gold"), home = home, taken = false, respawnAt = 0 })
	end

	local dino, colorParts = buildDino(dinoType, center)
	table.insert(circles, {
		center = center,
		dinoType = dinoType,
		eggs = eggs,
		ring = ring,
		occupant = nil,
		crackUntil = 0,
		cracked = false,
		dino = dino,
		dinoPos = center,
		dinoFace = Vector3.new(0, 0, -1),
		colorParts = colorParts,
	})
end

-- ---------- состояние игры ----------

local roundActive = false
local roundEnd = 0
local statusText = "Ждём игроков"
local humansScore, dinoScore = 0, 0
local message, messageUntil = "", 0
local carrying: { [Player]: { circle: Circle, egg: Egg, visual: BasePart } } = {}
local stunnedUntil: { [Player]: number } = {}
local guis = {}

local function announce(text: string, duration: number?)
	message = text
	messageUntil = os.clock() + (duration or 2.5)
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return nil, nil
	end
	return root :: BasePart, hum
end

local function dropEgg(player: Player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carry.egg.taken = false
	carry.egg.part.Transparency = 0
	carry.visual:Destroy()
	carrying[player] = nil
end

local function moveOut(root: BasePart, center: Vector3, radius: number)
	local dir = flat(root.Position - center)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = dir.Unit
	local x = math.clamp(center.X + dir.X * radius, -FIELD_X / 2 + 4, FIELD_X / 2 - 4)
	local z = math.clamp(center.Z + dir.Z * radius, -FIELD_Z / 2 + 4, FIELD_Z / 2 - 4)
	root.CFrame = CFrame.new(x, root.Position.Y, z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

local function crackCircle(c: Circle)
	if not c.cracked then
		announce("Круг сломан! Там уже есть человек", 1.5)
	end
	c.crackUntil = os.clock() + 1
	c.cracked = true
	for i, seg in ipairs(c.ring) do
		seg.Color = Color3.fromRGB(216, 69, 47)
		seg.Transparency = (i % 2 == 0) and 1 or 0
	end
end

local function resetArena()
	for player in pairs(carrying) do
		dropEgg(player)
	end
	for _, c in ipairs(circles) do
		c.occupant = nil
		c.dinoPos = c.center
		for _, egg in ipairs(c.eggs) do
			egg.taken = false
			egg.part.Transparency = 0
		end
	end
end

-- ---------- игроки ----------

local function makeGui(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoGui"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.new(0.9, 0, 0, 44)
	bar.BackgroundColor3 = WHITE
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 44)
	limit.Parent = bar
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar

	local function chip(order: number, width: number, bg: Color3?, fg: Color3)
		local t = Instance.new("TextLabel")
		t.LayoutOrder = order
		t.Size = UDim2.new(width, -8, 0, 34)
		t.BackgroundColor3 = bg or WHITE
		t.BackgroundTransparency = bg and 0 or 1
		t.TextColor3 = fg
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Parent = bar
		Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)
		return t
	end
	local h = chip(1, 0.36, Color3.fromRGB(47, 111, 216), WHITE)
	local t = chip(2, 0.26, nil, Color3.fromRGB(31, 42, 23))
	local d = chip(3, 0.36, Color3.fromRGB(216, 69, 47), WHITE)

	local msg = Instance.new("TextLabel")
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.25, 0)
	msg.Size = UDim2.new(0.8, 0, 0, 56)
	msg.BackgroundTransparency = 1
	msg.TextColor3 = WHITE
	msg.TextStrokeTransparency = 0
	msg.Font = Enum.Font.FredokaOne
	msg.TextScaled = true
	msg.Text = ""
	msg.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	guis[player] = { h = h, t = t, d = d, msg = msg }
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.WalkSpeed = CONFIG.WALK_SPEED
	hum.Died:Connect(function()
		dropEgg(player)
	end)
end

local function onPlayerAdded(player: Player)
	if #Players:GetPlayers() > CONFIG.MAX_PLAYERS then
		player:Kick("Игра полная: играть можно только 5 человек")
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local eggs = Instance.new("IntValue")
	eggs.Name = "Яйца"
	eggs.Parent = stats
	local cups = Instance.new("IntValue")
	cups.Name = "Кубки"
	cups.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	makeGui(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	dropEgg(player)
	stunnedUntil[player] = nil
	guis[player] = nil
	for _, c in ipairs(circles) do
		if c.occupant == player then
			c.occupant = nil
		end
	end
end)

local function addStat(player: Player, name: string, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	if v then
		(v :: IntValue).Value += amount
	end
end

-- ---------- игровой цикл каждый кадр ----------

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()

	for _, c in ipairs(circles) do
		if c.dinoType.kind == "rainbow" then
			local col = Color3.fromHSV((now * 0.25 + c.center.X / 300) % 1, 0.8, 1)
			for _, p in ipairs(c.colorParts) do
				p.Color = col
			end
		end
		if c.cracked and now > c.crackUntil then
			c.cracked = false
			for _, seg in ipairs(c.ring) do
				seg.Color = WHITE
				seg.Transparency = 0
			end
		end
		for _, egg in ipairs(c.eggs) do
			if egg.taken == "gone" and now >= egg.respawnAt then
				egg.taken = false
				egg.part.Transparency = 0
			end
		end
	end

	if not roundActive then
		return
	end

	-- кто в каком круге
	local inside: { [Player]: Circle } = {}
	local roots: { [Player]: BasePart } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRoot(player)
		if root then
			roots[player] = root
			for _, c in ipairs(circles) do
				if flatDist(root.Position, c.center) < R then
					inside[player] = c
					break
				end
			end
		end
	end

	-- в круге только один человек
	for _, c in ipairs(circles) do
		if c.occupant and inside[c.occupant] ~= c then
			c.occupant = nil
		end
	end
	for player, c in pairs(inside) do
		if c.occupant == nil then
			c.occupant = player
		elseif c.occupant ~= player then
			moveOut(roots[player], c.center, R + 4)
			crackCircle(c)
			inside[player] = nil
		end
	end

	-- взять яйцо и убежать с ним
	for player, root in pairs(roots) do
		local stunned = (stunnedUntil[player] or 0) > now
		local c = inside[player]
		if c and not carrying[player] and not stunned then
			for _, egg in ipairs(c.eggs) do
				if not egg.taken and flatDist(root.Position, egg.part.Position) < 3.5 then
					egg.taken = "carried"
					egg.part.Transparency = 1
					local visual = egg.part:Clone()
					visual.Transparency = 0
					visual.Anchored = false
					visual.Massless = true
					visual.CFrame = root.CFrame * CFrame.new(1.6, 0.4, -1)
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = visual
					weld.Parent = visual
					visual.Parent = player.Character
					carrying[player] = { circle = c, egg = egg, visual = visual }
					break
				end
			end
		end

		local carry = carrying[player]
		if carry and flatDist(root.Position, carry.circle.center) > ZONE + 2 then
			carry.egg.taken = "gone"
			carry.egg.respawnAt = now + CONFIG.EGG_RESPAWN
			carry.visual:Destroy()
			carrying[player] = nil
			humansScore += 1
			addStat(player, "Яйца", 1)
			announce(player.DisplayName .. " унёс яйцо! +1 людям", 2)
		end
	end

	-- динозавры
	for _, c in ipairs(circles) do
		local prey: Player? = nil
		for player, carry in pairs(carrying) do
			if carry.circle == c and roots[player] and (stunnedUntil[player] or 0) <= now then
				prey = player
				break
			end
		end
		if not prey and c.occupant and roots[c.occupant] and (stunnedUntil[c.occupant] or 0) <= now then
			prey = c.occupant
		end

		local target = prey and flat(roots[prey].Position) + Vector3.new(0, c.center.Y, 0) or c.center
		local speed = prey and c.dinoType.speed or c.dinoType.speed * 0.6
		local delta = flat(target - c.dinoPos)
		local moving = delta.Magnitude > 0.2
		if moving then
			local step = math.min(delta.Magnitude, speed * dt)
			c.dinoPos += delta.Unit * step
			c.dinoFace = delta.Unit
		end
		local fromHome = flat(c.dinoPos - c.center)
		if fromHome.Magnitude > ZONE then
			c.dinoPos = c.center + fromHome.Unit * ZONE
		end
		local bob = moving and math.abs(math.sin(now * 12)) * 0.5 or 0
		local bodyPos = c.dinoPos + Vector3.new(0, 4.5 + bob, 0)
		c.dino:PivotTo(CFrame.lookAt(bodyPos, bodyPos + c.dinoFace))

		if prey and flatDist(roots[prey].Position, c.dinoPos) < CONFIG.CATCH_DISTANCE then
			local root = roots[prey]
			dropEgg(prey)
			dinoScore += 1
			stunnedUntil[prey] = now + CONFIG.STUN_TIME
			if c.occupant == prey then
				c.occupant = nil
			end
			moveOut(root, c.center, ZONE + 6)
			local _, hum = getRoot(prey)
			if hum then
				hum.WalkSpeed = 0
				task.delay(CONFIG.STUN_TIME, function()
					if hum.Parent then
						hum.WalkSpeed = CONFIG.WALK_SPEED
					end
				end)
			end
			announce(c.dinoType.name .. " динозавр поймал " .. prey.DisplayName .. "! +1 динозаврам", 2)
		end
	end
end)

-- ---------- экран ----------

task.spawn(function()
	while true do
		local timeText
		if roundActive then
			local s = math.max(0, math.ceil(roundEnd - os.clock()))
			timeText = string.format("%d:%02d", s // 60, s % 60)
		else
			timeText = statusText
		end
		local msg = os.clock() < messageUntil and message or ""
		for _, g in pairs(guis) do
			g.h.Text = "Люди: " .. humansScore
			g.d.Text = "Динозавры: " .. dinoScore
			g.t.Text = timeText
			g.msg.Text = msg
		end
		task.wait(0.2)
	end
end)

-- ---------- кубок ----------

local function showTrophy(text: string, seconds: number)
	local gold = Color3.fromRGB(242, 184, 34)
	local cup = Instance.new("Model")
	cup.Name = "Кубок"
	local base = newPart(cup, Vector3.new(6, 1, 6), CFrame.new(0, 10, 0), Color3.fromRGB(31, 42, 23))
	local stem = newPart(cup, Vector3.new(4, 1.2, 1.2), CFrame.new(0, 12.5, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Foil)
	stem.Shape = Enum.PartType.Cylinder
	local bowl = newPart(cup, Vector3.new(5, 6, 6), CFrame.new(0, 17, 0) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Foil)
	bowl.Shape = Enum.PartType.Cylinder
	for _, x in ipairs({ -3.6, 3.6 }) do
		newPart(cup, Vector3.new(1, 3, 1), CFrame.new(x, 17, 0), gold, Enum.Material.Foil)
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 30
	light.Brightness = 3
	light.Parent = bowl
	addLabel(bowl, text, 6, gold)
	cup.PrimaryPart = base
	cup.Parent = arena

	local start = os.clock()
	while os.clock() - start < seconds do
		cup:PivotTo(CFrame.new(0, 10, 0) * CFrame.Angles(0, (os.clock() - start) * 2, 0))
		task.wait()
	end
	cup:Destroy()
end

-- ---------- раунды ----------

task.spawn(function()
	while true do
		roundActive = false
		while #Players:GetPlayers() == 0 do
			statusText = "Ждём игроков"
			task.wait(1)
		end
		for i = CONFIG.INTERMISSION, 1, -1 do
			statusText = "Старт: " .. i
			task.wait(1)
		end

		resetArena()
		humansScore, dinoScore = 0, 0
		table.clear(stunnedUntil)
		for _, player in ipairs(Players:GetPlayers()) do
			local stats = player:FindFirstChild("leaderstats")
			local eggs = stats and stats:FindFirstChild("Яйца")
			if eggs then
				(eggs :: IntValue).Value = 0
			end
			player:LoadCharacter()
		end
		task.wait(0.5)
		announce("Хватай яйца и убегай от динозавров!", 3)
		roundEnd = os.clock() + CONFIG.ROUND_TIME
		roundActive = true

		while os.clock() < roundEnd do
			task.wait(0.2)
		end

		roundActive = false
		resetArena()
		statusText = "Конец!"
		local text
		if humansScore > dinoScore then
			text = "Кубок у людей!"
			for _, player in ipairs(Players:GetPlayers()) do
				addStat(player, "Кубки", 1)
			end
		elseif dinoScore > humansScore then
			text = "Кубок у динозавров!"
		else
			text = "Ничья!"
		end
		announce(string.format("%s  Люди %d : %d Динозавры", text, humansScore, dinoScore), 8)
		showTrophy(text, 8)
	end
end)
