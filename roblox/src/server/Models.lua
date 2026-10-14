-- Все модели собираются из простых деталей, поэтому игре не нужны чужие ассеты.
local CollectionService = game:GetService("CollectionService")

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
-- Круглый милый динозавр со «скелетом»: шея, челюсть, хвост из 3 частей, 4 лапы и ручки
-- двигаются (их анимирует экран игрока). Главная деталь Body закреплена, остальное приклеено к ней.
-- Собирается стоящим на земле в точке (0,0,0), смотрит вперёд (-Z).
-- Возвращает модель, детали основного цвета (первая — туловище, вторая — голова) и высоту центра туловища.
function Models.dino(color: Color3, dark: Color3, scale: number, opts: any?)
	opts = opts or {}
	local s = scale
	local model = Instance.new("Model")
	model.Name = opts.name or "Dino"
	local belly = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local white = Color3.new(1, 1, 1)
	local pink = Color3.fromRGB(255, 150, 170)
	local colorParts = {}

	local current: BasePart? = nil -- к какой детали приклеивать новые
	local attachTo: { [BasePart]: BasePart } = {}
	local joints = {}
	local function add(p: BasePart): BasePart
		if current then
			attachTo[p] = current
		end
		return p
	end
	local function E(size: Vector3, pos: Vector3, c: Color3, rot: CFrame?, mat: Enum.Material?): BasePart
		return add(ball(model, size * s, CFrame.new(pos * s) * (rot or CFrame.identity), c, mat))
	end
	local function B(size: Vector3, pos: Vector3, c: Color3, rot: CFrame?): BasePart
		return add(part(model, size * s, CFrame.new(pos * s) * (rot or CFrame.identity), c))
	end
	local function motor(name: string, p0: BasePart, p1: BasePart, pivot: Vector3)
		attachTo[p1] = nil
		table.insert(joints, { name = name, p0 = p0, p1 = p1, pivot = CFrame.new(pivot * s) })
	end
	local V = Vector3.new
	local plateRot = CFrame.Angles(math.rad(45), 0, 0)

	-- туловище
	local body = E(V(6, 5, 8), V(0, 5, 0), color)
	body.Name = "Body"
	current = body
	E(V(4.6, 3.8, 6.4), V(0, 4.3, -0.6), belly)
	for _, x in ipairs({ -1, 1 }) do
		E(V(0.3, 1.3, 1.6), V(x * 2.85, 5.6, 0.6), dark)
		E(V(0.3, 0.9, 1.1), V(x * 2.65, 6.4, -1.6), dark)
		E(V(0.3, 0.8, 1.0), V(x * 2.8, 4.6, 2.3), dark)
	end
	local neck = E(V(3, 3.6, 3), V(0, 7, -3.4), color, CFrame.Angles(math.rad(-30), 0, 0))
	for i = 0, 4 do
		local h = 1.7 - math.abs(i - 2) * 0.3
		B(V(0.4, h, h), V(0, 7.3, -2.6 + i * 1.4), dark, plateRot)
	end

	-- голова
	local head = E(V(4, 3.4, 4.6), V(0, 8.6, -5.2), color)
	head.Name = "Head"
	motor("Neck", body, head, V(0, 7.4, -3.8))
	current = head
	local snout = E(V(3.2, 2.2, 3.2), V(0, 8.0, -7.1), color)
	for _, x in ipairs({ -1, 1 }) do
		E(V(0.35, 0.35, 0.35), V(x * 0.6, 8.6, -8.6), BLACK)
		E(V(1.3, 1.3, 1.3), V(x * 1.3, 9.4, -6.4), white)
		E(V(0.7, 0.75, 0.4), V(x * 1.35, 9.45, -7.0), BLACK)
		E(V(0.25, 0.25, 0.15), V(x * 1.2, 9.7, -7.2), white, nil, Enum.Material.Neon)
		local lid = E(V(1.42, 1.42, 1.42), V(x * 1.3, 9.4, -6.4), color)
		lid.Name = "Eyelid"
		lid.Transparency = 1
		B(V(1.0, 0.22, 0.3), V(x * 1.3, 10.25, -6.6), dark, CFrame.Angles(0, 0, math.rad(-12 * x)))
		E(V(0.25, 0.7, 0.9), V(x * 1.85, 8.5, -6.2), pink)
	end
	for i = 0, 2 do
		B(V(0.35, 0.9, 0.9), V(0, 10.3, -4.2 - i * 0.8), dark, plateRot)
	end
	for _, x in ipairs({ -0.9, -0.3, 0.3, 0.9 }) do
		B(V(0.3, 0.45, 0.3), V(x, 7.05, -8.2), white)
	end
	local jaw = E(V(2.8, 1.2, 3.2), V(0, 7.0, -6.8), color:Lerp(dark, 0.3))
	jaw.Name = "Jaw"
	motor("Jaw", head, jaw, V(0, 7.5, -5.4))
	current = jaw
	E(V(1.4, 0.35, 1.8), V(0, 7.45, -6.8), pink)

	-- хвост из трёх частей
	current = body
	local tailA = E(V(3.6, 3.2, 5), V(0, 5.0, 4.8), color)
	motor("TailA", body, tailA, V(0, 5.2, 3.0))
	current = tailA
	B(V(0.35, 1.2, 1.2), V(0, 6.6, 4.6), dark, plateRot)
	local tailB = E(V(2.6, 2.3, 4.4), V(0, 4.6, 8.2), color)
	motor("TailB", tailA, tailB, V(0, 4.8, 6.6))
	current = tailB
	B(V(0.3, 0.9, 0.9), V(0, 5.8, 8.0), dark, plateRot)
	local tailC = E(V(1.5, 1.4, 3.6), V(0, 4.2, 11.2), color)
	motor("TailC", tailB, tailC, V(0, 4.4, 9.8))

	-- лапы
	local limbs = {}
	for _, leg in ipairs({ { "HipFL", -1, -2.2 }, { "HipFR", 1, -2.2 }, { "HipBL", -1, 2.4 }, { "HipBR", 1, 2.4 } }) do
		local x, z = leg[2], leg[3]
		current = body
		local thigh = E(V(2.2, 3.2, 2.6), V(x * 2.1, 3.4, z), color)
		motor(leg[1], body, thigh, V(x * 2.1, 4.4, z))
		current = thigh
		local shin = E(V(1.7, 2.4, 1.7), V(x * 2.1, 1.6, z + 0.2), color)
		E(V(2, 0.9, 2.6), V(x * 2.1, 0.45, z - 0.4), dark)
		for _, cx in ipairs({ -0.6, 0, 0.6 }) do
			E(V(0.35, 0.35, 0.45), V(x * 2.1 + cx, 0.35, z - 1.7), white)
		end
		table.insert(limbs, thigh)
		table.insert(limbs, shin)
	end
	-- маленькие ручки
	for _, x in ipairs({ -1, 1 }) do
		current = body
		local arm = E(V(0.8, 1.8, 0.8), V(x * 2.3, 5.4, -3.6), color, CFrame.Angles(math.rad(-35), 0, 0))
		motor(x < 0 and "ArmL" or "ArmR", body, arm, V(x * 2.2, 6.2, -3.2))
		current = arm
		E(V(0.6, 0.6, 0.6), V(x * 2.3, 4.7, -4.3), color)
		table.insert(limbs, arm)
	end

	for _, p in ipairs({ body, head, neck, snout, jaw, tailA, tailB, tailC }) do
		table.insert(colorParts, p)
	end
	for _, p in ipairs(limbs) do
		table.insert(colorParts, p)
	end

	if opts.hat then
		local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 - 0.2 * s, 0.3 * s)
		for _, p in ipairs(Models.hat(opts.hat, model, top, 1.4 * s)) do
			attachTo[p] = head
		end
	end
	if opts.trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.7, 0) * s
		a0.Parent = tailC
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.7, 0) * s
		a1.Parent = tailC
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.8
		trail.LightEmission = 0.6
		trail.Color = Models.rainbowSequence()
		trail.Parent = tailC
	end
	if opts.label then
		Models.label(head, opts.label, 3 * s + 1.5, opts.labelColor or color)
	end

	-- соединяем всё в одно целое
	for _, j in ipairs(joints) do
		local m = Instance.new("Motor6D")
		m.Name = j.name
		m.Part0 = j.p0
		m.Part1 = j.p1
		m.C0 = j.p0.CFrame:Inverse() * j.pivot
		m.C1 = j.p1.CFrame:Inverse() * j.pivot
		m.Parent = j.p0
	end
	local jointed = {}
	for _, j in ipairs(joints) do
		jointed[j.p1] = true
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= body then
			if not jointed[d] then
				local w = Instance.new("WeldConstraint")
				w.Part0 = attachTo[d] or body
				w.Part1 = d
				w.Parent = d
			end
			d.Anchored = false
			d.Massless = true
		end
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.PrimaryPart = body
	CollectionService:AddTag(model, "DinoRig")
	model:SetAttribute("Scale", s)
	return model, colorParts, 5 * s
end

-- Приклеить динозавра к игроку (превращение): туловище больше не закреплено, а приварено к root.
function Models.attachRig(model: Model, root: BasePart)
	local body = model.PrimaryPart :: BasePart
	body.Anchored = false
	body.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = body
	w.Parent = body
end

-- передвинуть динозавра: двигаем только туловище, остальное едет следом
function Models.moveRig(model: Model, cf: CFrame)
	local body = model.PrimaryPart
	if body then
		body.CFrame = cf
	end
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
local SPOTS = { Vector3.new(0.6, 0.35, 0.5), Vector3.new(-0.6, -0.1, 0.45), Vector3.new(0.1, -0.55, -0.7), Vector3.new(-0.2, 0.6, -0.5) }
local function weldSmall(egg: BasePart, p: BasePart)
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = egg, p, p
end

function Models.egg(kind: string, cframe: CFrame, parent: Instance, event: string): Part
	local egg: Part
	if event == "newyear" and kind ~= "rainbow" then
		local color = kind == "gold" and Color3.fromRGB(242, 194, 48) or Color3.fromRGB(210, 40, 40)
		egg = part(parent, Vector3.new(1.6, 1.6, 1.6), cframe * CFrame.new(0, -0.15, 0), color)
		local ribbonColor = kind == "gold" and Color3.fromRGB(210, 40, 40) or Color3.fromRGB(250, 220, 90)
		weldSmall(egg, part(egg, Vector3.new(1.7, 1.7, 0.3), egg.CFrame, ribbonColor))
		weldSmall(egg, part(egg, Vector3.new(0.3, 1.7, 1.7), egg.CFrame, ribbonColor))
		weldSmall(egg, ball(egg, Vector3.new(0.8, 0.5, 0.8), egg.CFrame * CFrame.new(0, 0.9, 0), ribbonColor))
	else
		local color = Color3.fromRGB(251, 246, 230)
		local spot = Color3.fromRGB(150, 200, 120)
		local isGold = kind == "gold"
		if isGold then
			color = Color3.fromRGB(255, 216, 74)
			spot = Color3.fromRGB(255, 245, 190)
		elseif event == "halloween" then
			color = Color3.fromRGB(245, 150, 50)
			spot = Color3.fromRGB(60, 40, 40)
		end
		local size = Vector3.new(1.4, 1.9, 1.4) * (kind == "rainbow" and 1.3 or 1)
		egg = ball(parent, size, cframe, color, (kind == "rainbow" or isGold) and Enum.Material.Neon or nil)
		if isGold then
			egg.Material = Enum.Material.Foil
		end
		if kind ~= "rainbow" then
			-- пятнышки на скорлупе
			for _, d in ipairs(SPOTS) do
				local r = size / 2
				local n = d / math.sqrt((d.X / r.X) ^ 2 + (d.Y / r.Y) ^ 2 + (d.Z / r.Z) ^ 2)
				weldSmall(egg, ball(egg, Vector3.new(0.38, 0.38, 0.38), cframe * CFrame.new(n * 0.95), spot))
			end
		end
	end
	if kind == "rainbow" then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 255, 255)
		sp.Parent = egg
	end
	egg.Name = "Egg"
	CollectionService:AddTag(egg, "Egg")
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
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local r = i == 7 and 0 or 2.4
		local size = i == 7 and 6 or math.random(40, 55) / 10
		local shade = color:Lerp(i % 2 == 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), 0.08 + math.random() * 0.06)
		ball(m, Vector3.new(size, size * 0.8, size), CFrame.new(pos + Vector3.new(math.cos(a) * r, 2 + (i == 7 and 1 or 0.3), math.sin(a) * r)), shade, Enum.Material.LeafyGrass)
	end
	-- ягодки или цветочки
	local berry = ({ Color3.fromRGB(230, 50, 70), Color3.fromRGB(255, 240, 120), Color3.fromRGB(150, 110, 255) })[math.random(3)]
	for i = 1, 8 do
		local a = math.random() * math.pi * 2
		local h = 1.5 + math.random() * 2.5
		ball(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos + Vector3.new(math.cos(a) * 3.2, h, math.sin(a) * 3.2)), berry)
	end
	m.Parent = parent
	return m
end

local LEAVES = { Color3.fromRGB(60, 150, 50), Color3.fromRGB(80, 170, 60), Color3.fromRGB(45, 125, 45), Color3.fromRGB(100, 180, 70) }

function Models.tree(parent: Instance, pos: Vector3, palm: boolean)
	local m = Instance.new("Model")
	m.Name = palm and "Palm" or "Tree"
	local bark = Color3.fromRGB(115, 78, 48)
	if palm then
		-- изогнутый ствол из колец
		local top = pos
		local lean = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
		for i = 0, 7 do
			local p = pos + Vector3.new(0, i * 1.7 + 0.85, 0) + lean * (i * i) * 0.06
			local c = cylinder(m, 1.8, 1.9 - i * 0.08, CFrame.new(p), i % 2 == 0 and bark or bark:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Wood)
			c.CanCollide = i < 3
			top = p
		end
		for i = 0, 2 do
			ball(m, Vector3.new(0.9, 0.9, 0.9), CFrame.new(top + Vector3.new(math.cos(i * 2.1) * 0.6, -0.4, math.sin(i * 2.1) * 0.6)), Color3.fromRGB(110, 75, 40))
		end
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			local base = CFrame.new(top + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0)
			for k = 0, 2 do
				local seg = base * CFrame.Angles(math.rad(-15 - k * 18), 0, 0) * CFrame.new(0, 0, -1.6 - k * 2.7)
				part(m, Vector3.new(2.2 - k * 0.5, 0.25, 3), seg, LEAVES[(i + k) % 4 + 1], Enum.Material.LeafyGrass)
				base = base * CFrame.new(0, -k * 0.8, -2.6)
			end
		end
	else
		local h = math.random(9, 13)
		local trunk = cylinder(m, h * 0.6, 2.2, CFrame.new(pos + Vector3.new(0, h * 0.3, 0)), bark, Enum.Material.Wood)
		trunk.CanCollide = true
		cylinder(m, h * 0.5, 1.6, CFrame.new(pos + Vector3.new(0, h * 0.8, 0)), bark, Enum.Material.Wood)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			part(m, Vector3.new(0.6, 0.6, 3), CFrame.new(pos + Vector3.new(math.cos(a) * 1.3, 0.3, math.sin(a) * 1.3)) * CFrame.Angles(0, -a + math.pi / 2, math.rad(15)), bark, Enum.Material.Wood)
		end
		local crown = pos + Vector3.new(0, h + 1.5, 0)
		ball(m, Vector3.new(9, 7.5, 9), CFrame.new(crown), LEAVES[math.random(4)], Enum.Material.LeafyGrass)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local sz = math.random(50, 70) / 10
			ball(m, Vector3.new(sz, sz * 0.85, sz), CFrame.new(crown + Vector3.new(math.cos(a) * 3.6, math.random(-15, 15) / 10, math.sin(a) * 3.6)), LEAVES[(i % 4) + 1], Enum.Material.LeafyGrass)
		end
		ball(m, Vector3.new(6, 5, 6), CFrame.new(crown + Vector3.new(0, 3.5, 0)), LEAVES[math.random(4)], Enum.Material.LeafyGrass)
		if math.random() < 0.5 then
			for i = 1, 6 do
				local a = math.random() * math.pi * 2
				ball(m, Vector3.new(0.7, 0.7, 0.7), CFrame.new(crown + Vector3.new(math.cos(a) * 4.6, math.random(-20, 10) / 10, math.sin(a) * 4.6)), Color3.fromRGB(230, 50, 50))
			end
		end
	end
	m.Parent = parent
	return m
end

-- ёлка со снегом
function Models.pine(parent: Instance, pos: Vector3, snowy: boolean)
	local m = Instance.new("Model")
	m.Name = "Pine"
	local trunk = cylinder(m, 4, 1.4, CFrame.new(pos + Vector3.new(0, 2, 0)), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
	trunk.CanCollide = true
	for i = 0, 4 do
		local d = 9 - i * 1.7
		local y = 4 + i * 2.2
		ball(m, Vector3.new(d, 2.6, d), CFrame.new(pos + Vector3.new(0, y, 0)), Color3.fromRGB(35, 105, 60), Enum.Material.LeafyGrass)
		if snowy then
			ball(m, Vector3.new(d * 0.8, 1, d * 0.8), CFrame.new(pos + Vector3.new(0, y + 1.1, 0)), Color3.new(1, 1, 1), Enum.Material.Snow)
		end
	end
	ball(m, Vector3.new(1, 1.6, 1), CFrame.new(pos + Vector3.new(0, 15.6, 0)), snowy and Color3.new(1, 1, 1) or Color3.fromRGB(35, 105, 60))
	m.Parent = parent
	return m
end

function Models.flower(parent: Instance, pos: Vector3)
	local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 80), Color3.fromRGB(150, 130, 255), Color3.new(1, 1, 1), Color3.fromRGB(255, 140, 60) }
	local petal = colors[math.random(#colors)]
	local h = 1 + math.random() * 0.8
	part(parent, Vector3.new(0.18, h, 0.18), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(60, 140, 50))
	ball(parent, Vector3.new(0.9, 0.2, 0.45), CFrame.new(pos + Vector3.new(0.35, h * 0.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(70, 160, 60))
	local head = pos + Vector3.new(0, h, 0)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ball(parent, Vector3.new(0.55, 0.2, 0.55), CFrame.new(head + Vector3.new(math.cos(a) * 0.38, 0, math.sin(a) * 0.38)), petal)
	end
	ball(parent, Vector3.new(0.4, 0.3, 0.4), CFrame.new(head + Vector3.new(0, 0.08, 0)), Color3.fromRGB(255, 200, 40))
end

function Models.rock(parent: Instance, pos: Vector3, size: number)
	local m = Instance.new("Model")
	m.Name = "Rock"
	local grey = Color3.fromRGB(125, 125, 130)
	for i = 1, 3 do
		local sz = size * (1 - (i - 1) * 0.28)
		local p = part(m, Vector3.new(sz, sz * 0.7, sz * 0.9), CFrame.new(pos + Vector3.new((i - 2) * size * 0.4, sz * 0.25, (i % 2) * size * 0.3)) * CFrame.Angles(math.random() * 0.6, math.random() * 6, math.random() * 0.6), grey:Lerp(Color3.new(0, 0, 0), math.random() * 0.2), Enum.Material.Rock)
		p.CanCollide = true
	end
	if math.random() < 0.6 then
		ball(m, Vector3.new(size * 0.7, 0.3, size * 0.5), CFrame.new(pos + Vector3.new(0, size * 0.55, 0)), Color3.fromRGB(90, 150, 60), Enum.Material.Grass)
	end
	m.Parent = parent
	return m
end

function Models.log(parent: Instance, pos: Vector3)
	local a = math.random() * math.pi
	local cf = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, a, 0)
	local logPart = part(parent, Vector3.new(7, 1.8, 1.8), cf, Color3.fromRGB(115, 78, 48), Enum.Material.Wood)
	logPart.Shape = Enum.PartType.Cylinder
	logPart.CanCollide = true
	for _, x in ipairs({ -3.52, 3.52 }) do
		local cap = part(parent, Vector3.new(0.05, 1.6, 1.6), cf * CFrame.new(x, 0, 0), Color3.fromRGB(215, 180, 130), Enum.Material.Wood)
		cap.Shape = Enum.PartType.Cylinder
	end
	ball(parent, Vector3.new(1.2, 0.5, 1.2), cf * CFrame.new(1, 1, 0), Color3.fromRGB(230, 60, 50))
	ball(parent, Vector3.new(0.25, 0.25, 0.25), cf * CFrame.new(1.2, 1.25, 0.2), Color3.new(1, 1, 1))
end

function Models.mushroom(parent: Instance, pos: Vector3)
	local h = 0.6 + math.random() * 0.6
	cylinder(parent, h, 0.4, CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(250, 240, 220))
	ball(parent, Vector3.new(1.3, 0.7, 1.3), CFrame.new(pos + Vector3.new(0, h + 0.1, 0)), Color3.fromRGB(230, 60, 50))
	ball(parent, Vector3.new(0.25, 0.15, 0.25), CFrame.new(pos + Vector3.new(0.3, h + 0.42, 0.1)), Color3.new(1, 1, 1))
	ball(parent, Vector3.new(0.2, 0.12, 0.2), CFrame.new(pos + Vector3.new(-0.25, h + 0.4, -0.2)), Color3.new(1, 1, 1))
end

function Models.fern(parent: Instance, pos: Vector3)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part(parent, Vector3.new(0.9, 0.15, 3.2), CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.new(0, 0, -1.4), LEAVES[i % 4 + 1], Enum.Material.LeafyGrass)
	end
end

function Models.crystal(parent: Instance, pos: Vector3)
	for i = 1, 3 do
		local h = 4 - i
		part(parent, Vector3.new(0.9, h, 0.9), CFrame.new(pos + Vector3.new((i - 2) * 0.8, h / 2, (i % 2) * 0.5)) * CFrame.Angles(math.rad((i - 2) * 12), math.rad(45), math.rad((i - 2) * 10)), Color3.fromRGB(150, 220, 255), Enum.Material.Glass).Transparency = 0.2
	end
	local glow = part(parent, Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 220, 255)
	light.Range = 10
	light.Parent = glow
end

-- флажок на границе круга
function Models.flag(parent: Instance, pos: Vector3, color: Color3)
	part(parent, Vector3.new(0.2, 3, 0.2), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(240, 240, 240))
	part(parent, Vector3.new(0.08, 0.8, 1.2), CFrame.new(pos + Vector3.new(0, 2.6, 0.6)), color)
	ball(parent, Vector3.new(0.35, 0.35, 0.35), CFrame.new(pos + Vector3.new(0, 3.1, 0)), Color3.fromRGB(255, 220, 90))
end

function Models.lamp(parent: Instance, pos: Vector3)
	local dark = Color3.fromRGB(45, 50, 60)
	cylinder(parent, 0.6, 1.6, CFrame.new(pos + Vector3.new(0, 0.3, 0)), dark, Enum.Material.Metal)
	local pole = cylinder(parent, 9, 0.5, CFrame.new(pos + Vector3.new(0, 4.8, 0)), dark, Enum.Material.Metal)
	pole.CanCollide = true
	local bulb = ball(parent, Vector3.new(1.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 9.8, 0)), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
	part(parent, Vector3.new(1.9, 0.3, 1.9), CFrame.new(pos + Vector3.new(0, 10.7, 0)), dark, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Range = 22
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = bulb
end

function Models.bench(parent: Instance, cf: CFrame)
	local wood = Color3.fromRGB(160, 110, 65)
	for i = 0, 2 do
		part(parent, Vector3.new(6, 0.25, 0.55), cf * CFrame.new(0, 1.6, -0.6 + i * 0.62), wood, Enum.Material.Wood).CanCollide = true
	end
	for i = 0, 1 do
		part(parent, Vector3.new(6, 0.5, 0.25), cf * CFrame.new(0, 2.4 + i * 0.7, 0.85), wood, Enum.Material.Wood).CanCollide = true
	end
	for _, x in ipairs({ -2.6, 2.6 }) do
		part(parent, Vector3.new(0.3, 3.4, 2), cf * CFrame.new(x, 1.5, 0.1), Color3.fromRGB(45, 50, 60), Enum.Material.Metal)
	end
end

-- тележка со сладкой ватой
function Models.candyCart(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "CandyCart"
	local cart = part(m, Vector3.new(6, 3, 3.4), cf * CFrame.new(0, 2.2, 0), Color3.fromRGB(255, 160, 200))
	cart.CanCollide = true
	part(m, Vector3.new(6.2, 0.3, 3.6), cf * CFrame.new(0, 3.85, 0), Color3.new(1, 1, 1))
	for _, x in ipairs({ -2.2, 2.2 }) do
		local w = part(m, Vector3.new(0.4, 1.6, 1.6), cf * CFrame.new(x, 0.8, 1.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 60, 70))
		w.Shape = Enum.PartType.Cylinder
	end
	cylinder(m, 7, 0.3, cf * CFrame.new(0, 7.5, 0), Color3.new(1, 1, 1))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(m, Vector3.new(2.6, 0.2, 4.6), cf * CFrame.new(0, 10.6, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2) * CFrame.Angles(math.rad(-20), 0, 0), i % 2 == 0 and Color3.fromRGB(255, 120, 170) or Color3.new(1, 1, 1))
	end
	for i, c in ipairs({ Color3.fromRGB(255, 170, 210), Color3.fromRGB(170, 210, 255), Color3.fromRGB(255, 240, 160) }) do
		local x = (i - 2) * 1.8
		part(m, Vector3.new(0.15, 1.4, 0.15), cf * CFrame.new(x, 4.6, 0), Color3.new(1, 1, 1))
		ball(m, Vector3.new(1.4, 1.6, 1.4), cf * CFrame.new(x, 5.8, 0), c)
	end
	Models.label(cart, "🍭 Сладкая вата", 7, Color3.fromRGB(255, 190, 230), 60)
	m.Parent = parent
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
