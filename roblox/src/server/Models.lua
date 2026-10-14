-- Все модели собираются из простых деталей, поэтому игре не нужны чужие ассеты.
local Models = {}

local WHITE = Color3.fromRGB(247, 243, 227)
local BLACK = Color3.fromRGB(25, 25, 25)

function Models.part(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local part = Models.part

local function ball(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
Models.ball = ball

-- вертикальный цилиндр (в Roblox цилиндр лежит вдоль X, поэтому поворачиваем)
local function cylinder(parent: Instance?, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Models.cylinder = cylinder

function Models.label(adornee: BasePart, text: string, offsetY: number, color: Color3, maxDistance: number?): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 180, 0, 36)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = maxDistance or 120
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

-- Облачко со словами над головой. Пустой текст — облачко спрятано.
function Models.bubble(adornee: BasePart, offsetY: number): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.new(0, 220, 0, 50)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Enabled = false
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.new(1, 1, 1)
	t.TextColor3 = Color3.fromRGB(31, 42, 23)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = ""
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = t
	bb.Parent = adornee
	t:GetPropertyChangedSignal("Text"):Connect(function()
		bb.Enabled = t.Text ~= ""
	end)
	return t
end

-- Приклеивает все детали модели к root: модель становится одним целым и не мешает ходить.
function Models.weldTo(model: Instance, root: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
			d.Anchored = false
		end
	end
end

function Models.setVisible(root: Instance, visible: boolean)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			d.Transparency = visible and 0 or 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Sparkles") then
			d.Enabled = visible
		end
	end
end

-- ---------- шапки ----------
-- top — CFrame макушки, k — размер (1 для человека)
function Models.hat(id: string, parent: Instance, top: CFrame, k: number): { BasePart }
	local parts = {}
	local function add(p)
		table.insert(parts, p)
		return p
	end
	if id == "hat_dino" then
		local green = Color3.fromRGB(108, 207, 69)
		add(ball(parent, Vector3.new(2.3, 1.3, 2.3) * k, top * CFrame.new(0, 0.15 * k, 0), green))
		for i = -1, 1 do
			add(part(parent, Vector3.new(0.3, 0.8, 0.8) * k, top * CFrame.new(0, 0.8 * k, i * 0.6 * k) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(44, 107, 30)))
		end
	elseif id == "hat_crown" then
		local gold = Color3.fromRGB(242, 194, 48)
		add(cylinder(parent, 0.6 * k, 2.1 * k, top * CFrame.new(0, 0.3 * k, 0), gold, Enum.Material.Foil))
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			add(part(parent, Vector3.new(0.35, 0.7, 0.35) * k, top * CFrame.new(math.cos(a) * 0.85 * k, 0.85 * k, math.sin(a) * 0.85 * k), gold, Enum.Material.Foil))
		end
		add(ball(parent, Vector3.new(0.4, 0.4, 0.4) * k, top * CFrame.new(0, 0.35 * k, -1 * k), Color3.fromRGB(230, 60, 90), Enum.Material.Neon))
	elseif id == "hat_bunny" then
		for _, x in ipairs({ -0.45, 0.45 }) do
			local cf = top * CFrame.new(x * k, 1.1 * k, 0) * CFrame.Angles(0, 0, math.rad(x > 0 and -10 or 10))
			add(ball(parent, Vector3.new(0.6, 2.2, 0.35) * k, cf, Color3.new(1, 1, 1)))
			add(ball(parent, Vector3.new(0.35, 1.7, 0.2) * k, cf * CFrame.new(0, 0, -0.1 * k), Color3.fromRGB(255, 170, 200)))
		end
	elseif id == "hat_pumpkin" then
		add(ball(parent, Vector3.new(2.5, 2, 2.5) * k, top * CFrame.new(0, 0.5 * k, 0), Color3.fromRGB(240, 130, 30)))
		add(part(parent, Vector3.new(0.3, 0.6, 0.3) * k, top * CFrame.new(0, 1.6 * k, 0), Color3.fromRGB(60, 120, 40)))
	elseif id == "hat_santa" then
		local red = Color3.fromRGB(210, 40, 40)
		add(cylinder(parent, 0.45 * k, 2.3 * k, top * CFrame.new(0, 0.15 * k, 0), Color3.new(1, 1, 1)))
		add(cylinder(parent, 0.6 * k, 1.9 * k, top * CFrame.new(0, 0.6 * k, 0.05 * k), red))
		add(cylinder(parent, 0.6 * k, 1.35 * k, top * CFrame.new(0, 1.15 * k, 0.2 * k), red))
		add(cylinder(parent, 0.6 * k, 0.8 * k, top * CFrame.new(0, 1.65 * k, 0.4 * k), red))
		add(ball(parent, Vector3.new(0.6, 0.6, 0.6) * k, top * CFrame.new(0, 2.05 * k, 0.6 * k), Color3.new(1, 1, 1)))
	end
	return parts
end

-- ---------- динозавр ----------
-- Собирается стоящим на земле в точке (0,0,0), смотрит вперёд (-Z).
-- Возвращает модель, детали основного цвета и высоту центра туловища.
function Models.dino(color: Color3, dark: Color3, scale: number, opts: any?)
	opts = opts or {}
	local s = scale
	local model = Instance.new("Model")
	model.Name = opts.name or "Dino"
	local colorParts = {}
	local function P(size: Vector3, pos: Vector3, c: Color3, rot: CFrame?)
		local p = part(model, size * s, CFrame.new(pos * s) * (rot or CFrame.identity), c)
		return p
	end

	local body = P(Vector3.new(5, 4, 7), Vector3.new(0, 4.5, 0), color)
	local head = P(Vector3.new(3.5, 3, 4.5), Vector3.new(0, 7, -5), color)
	local tail = P(Vector3.new(2, 2, 7), Vector3.new(0, 4, 6.5), color, CFrame.Angles(math.rad(-12), 0, 0))
	table.insert(colorParts, body)
	table.insert(colorParts, head)
	table.insert(colorParts, tail)
	P(Vector3.new(3, 1, 3.5), Vector3.new(0, 5.3, -5.6), dark)
	for _, x in ipairs({ -1.3, 1.3 }) do
		local eye = P(Vector3.new(1, 1, 1), Vector3.new(x, 7.8, -6.8), Color3.new(1, 1, 1))
		eye.Shape = Enum.PartType.Ball
		local pupil = P(Vector3.new(0.5, 0.5, 0.5), Vector3.new(x, 7.8, -7.25), BLACK)
		pupil.Shape = Enum.PartType.Ball
	end
	-- зубки
	for _, x in ipairs({ -0.8, 0, 0.8 }) do
		P(Vector3.new(0.3, 0.4, 0.3), Vector3.new(x, 5.6, -7.2), Color3.new(1, 1, 1))
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		for _, z in ipairs({ -2, 2 }) do
			P(Vector3.new(1.6, 3, 1.6), Vector3.new(x, 1.5, z), dark)
		end
	end
	for i = 0, 3 do
		P(Vector3.new(0.4, 1.6, 1.6), Vector3.new(0, 6.8, -2.5 + i * 1.8), dark, CFrame.Angles(math.rad(45), 0, 0))
	end

	if opts.hat then
		local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0.3 * s)
		Models.hat(opts.hat, model, top, 1.4 * s)
	end
	if opts.trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1, 2) * s
		a0.Parent = tail
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1, 2) * s
		a1.Parent = tail
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.8
		trail.LightEmission = 0.6
		trail.Color = Models.rainbowSequence()
		trail.Parent = tail
	end
	if opts.label then
		Models.label(head, opts.label, 3 * s + 1.5, opts.labelColor or color)
	end

	model.PrimaryPart = body
	return model, colorParts, 4.5 * s
end

function Models.rainbowSequence(): ColorSequence
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 0.8, 1)))
	end
	return ColorSequence.new(keys)
end

-- ---------- яйца ----------
-- kind: normal / gold / rainbow; event меняет вид (тыквы на Хэллоуин, подарки на Новый год)
function Models.egg(kind: string, cframe: CFrame, parent: Instance, event: string): Part
	local egg: Part
	if event == "newyear" and kind ~= "rainbow" then
		local color = kind == "gold" and Color3.fromRGB(242, 194, 48) or Color3.fromRGB(210, 40, 40)
		egg = part(parent, Vector3.new(1.6, 1.6, 1.6), cframe * CFrame.new(0, -0.15, 0), color)
		local ribbonColor = kind == "gold" and Color3.fromRGB(210, 40, 40) or Color3.fromRGB(250, 220, 90)
		local r1 = part(egg, Vector3.new(1.7, 1.7, 0.3), egg.CFrame, ribbonColor)
		local r2 = part(egg, Vector3.new(0.3, 1.7, 1.7), egg.CFrame, ribbonColor)
		local w1 = Instance.new("WeldConstraint")
		w1.Part0, w1.Part1, w1.Parent = egg, r1, r1
		local w2 = Instance.new("WeldConstraint")
		w2.Part0, w2.Part1, w2.Parent = egg, r2, r2
		r1.Anchored, r2.Anchored = false, false
	else
		local color = Color3.fromRGB(251, 246, 230)
		local isGold = kind == "gold"
		if isGold then
			color = Color3.fromRGB(255, 216, 74)
		elseif event == "halloween" then
			color = Color3.fromRGB(245, 150, 50)
		end
		egg = ball(parent, Vector3.new(1.4, 1.9, 1.4), cframe, color, kind == "rainbow" and Enum.Material.Neon or nil)
	end
	if kind == "rainbow" then
		egg.Size = egg.Size * 1.3
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 255, 255)
		sp.Parent = egg
	end
	egg.Name = "Egg"
	return egg
end

-- ---------- клетка для пойманного ----------
function Models.cage(position: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Cage"
	local base = CFrame.new(position)
	local color = Color3.fromRGB(120, 90, 60)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(m, Vector3.new(0.4, 7, 0.4), base * CFrame.new(math.cos(a) * 3, 3.5, math.sin(a) * 3), color, Enum.Material.Wood)
	end
	cylinder(m, 0.6, 7, base * CFrame.new(0, 7.2, 0), color, Enum.Material.Wood)
	m.Parent = parent
	return m
end

-- ---------- природа ----------
function Models.bush(parent: Instance, pos: Vector3, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Bush"
	ball(m, Vector3.new(7, 5, 7), CFrame.new(pos + Vector3.new(0, 2, 0)), color, Enum.Material.Grass)
	ball(m, Vector3.new(5, 4, 5), CFrame.new(pos + Vector3.new(2.2, 2.6, 1)), color:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Grass)
	ball(m, Vector3.new(5, 4, 5), CFrame.new(pos + Vector3.new(-2, 2.4, -1.2)), color:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.Grass)
	for _, d in ipairs(m:GetChildren()) do
		(d :: BasePart).Transparency = 0.1
	end
	m.Parent = parent
	return m
end

function Models.tree(parent: Instance, pos: Vector3, palm: boolean)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local trunk = cylinder(m, 12, 1.6, CFrame.new(pos + Vector3.new(0, 6, 0)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	trunk.CanCollide = true
	if palm then
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			part(m, Vector3.new(1.2, 0.3, 7), CFrame.new(pos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(60, 150, 50), Enum.Material.Grass)
		end
	else
		ball(m, Vector3.new(9, 8, 9), CFrame.new(pos + Vector3.new(0, 13, 0)), Color3.fromRGB(50, 130, 45), Enum.Material.Grass)
	end
	m.Parent = parent
	return m
end

function Models.flower(parent: Instance, pos: Vector3)
	local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 80), Color3.fromRGB(150, 130, 255), Color3.new(1, 1, 1) }
	part(parent, Vector3.new(0.2, 1.2, 0.2), CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color3.fromRGB(60, 140, 50))
	ball(parent, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 1.3, 0)), colors[math.random(#colors)])
end

function Models.snowman(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Snowman"
	ball(m, Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 2, 0)), Color3.new(1, 1, 1))
	ball(m, Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 5, 0)), Color3.new(1, 1, 1))
	ball(m, Vector3.new(2.2, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 7.3, 0)), Color3.new(1, 1, 1))
	part(m, Vector3.new(0.3, 0.3, 1.2), CFrame.new(pos + Vector3.new(0, 7.3, -1.3)), Color3.fromRGB(245, 140, 40))
	m.Parent = parent
end

function Models.pumpkin(parent: Instance, pos: Vector3)
	local p = ball(parent, Vector3.new(3, 2.4, 3), CFrame.new(pos + Vector3.new(0, 1.2, 0)), Color3.fromRGB(240, 130, 30))
	part(parent, Vector3.new(0.4, 0.8, 0.4), CFrame.new(pos + Vector3.new(0, 2.6, 0)), Color3.fromRGB(60, 120, 40))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 10
	light.Parent = p
end

function Models.volcano(parent: Instance, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Volcano"
	local rock = Color3.fromRGB(80, 55, 45)
	for i = 0, 5 do
		cylinder(m, 6, 60 - i * 9, CFrame.new(pos + Vector3.new(0, 3 + i * 6, 0)), rock:Lerp(Color3.new(0, 0, 0), i * 0.05), Enum.Material.Basalt)
	end
	local top = cylinder(m, 1, 8, CFrame.new(pos + Vector3.new(0, 36.5, 0)), Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 20
	fire.Parent = top
	local smoke = Instance.new("Smoke")
	smoke.RiseVelocity = 12
	smoke.Size = 10
	smoke.Opacity = 0.2
	smoke.Parent = top
	m.Parent = parent
end

function Models.lava(parent: Instance, pos: Vector3, radius: number): Part
	local p = cylinder(parent, 0.3, radius * 2, CFrame.new(pos + Vector3.new(0, 0.12, 0)), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = radius * 2
	light.Parent = p
	return p
end

-- ---------- бонусы на поле ----------
function Models.powerup(kind: string, pos: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "PowerUp_" .. kind
	local main: Part
	if kind == "banana" then
		local yellow = Color3.fromRGB(250, 220, 60)
		main = ball(m, Vector3.new(0.9, 0.9, 3), CFrame.new(pos), yellow)
		ball(m, Vector3.new(0.8, 0.8, 1.6), CFrame.new(pos + Vector3.new(0, 0.5, -1.4)) * CFrame.Angles(math.rad(-30), 0, 0), yellow)
		ball(m, Vector3.new(0.8, 0.8, 1.6), CFrame.new(pos + Vector3.new(0, 0.5, 1.4)) * CFrame.Angles(math.rad(30), 0, 0), yellow)
	elseif kind == "star" then
		main = part(m, Vector3.new(2, 2, 2), CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(255, 215, 40), Enum.Material.Neon)
		local sp = Instance.new("Sparkles")
		sp.Parent = main
	else
		main = cylinder(m, 0.5, 2.6, CFrame.new(pos + Vector3.new(0, 0.9, 0)), Color3.fromRGB(230, 60, 60))
		for i = 0, 3 do
			cylinder(m, 0.2, 1.8, CFrame.new(pos + Vector3.new(0, -0.6 + i * 0.4, 0)), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
		end
	end
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Parent = main
	m.PrimaryPart = main
	m.Parent = parent
	return m
end

-- ---------- гнездо, кубок ----------
function Models.nest(parent: Instance, pos: Vector3): (Model, ProximityPrompt)
	local m = Instance.new("Model")
	m.Name = "Nest"
	local brown = Color3.fromRGB(140, 100, 55)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = part(m, Vector3.new(1, 1, 2.6), CFrame.new(pos + Vector3.new(math.cos(a) * 3, 0.6, math.sin(a) * 3)) * CFrame.Angles(0, -a, math.rad(20)), brown, Enum.Material.Wood)
		p.CanCollide = true
	end
	local center = cylinder(m, 0.4, 5, CFrame.new(pos + Vector3.new(0, 0.3, 0)), brown:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
	ball(m, Vector3.new(1.4, 1.9, 1.4), CFrame.new(pos + Vector3.new(0, 1.3, 0)), WHITE)
	Models.label(center, "🐣 Гнездо", 4, Color3.fromRGB(255, 230, 120), 80)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Вылупить яйцо"
	prompt.ObjectText = "Гнездо"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = center
	m.Parent = parent
	return m, prompt
end

function Models.trophy(parent: Instance, text: string): Model
	local gold = Color3.fromRGB(242, 184, 34)
	local cup = Instance.new("Model")
	cup.Name = "Trophy"
	local base = part(cup, Vector3.new(6, 1, 6), CFrame.new(0, 10, 0), Color3.fromRGB(31, 42, 23))
	cylinder(cup, 4, 1.2, CFrame.new(0, 12.5, 0), gold, Enum.Material.Foil)
	local bowl = cylinder(cup, 5, 6, CFrame.new(0, 17, 0), gold, Enum.Material.Foil)
	for _, x in ipairs({ -3.6, 3.6 }) do
		part(cup, Vector3.new(1, 3, 1), CFrame.new(x, 17, 0), gold, Enum.Material.Foil)
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 30
	light.Brightness = 3
	light.Parent = bowl
	Models.label(bowl, text, 6, gold, 300)
	cup.PrimaryPart = base
	cup.Parent = parent
	return cup
end

return Models
