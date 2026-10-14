-- Строит поле на каждый тайм: 4 карты, круги, динозавры, яйца, кусты.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Models = require(script.Parent.Models)

local Arena = {}

local R, ZONE, G = Config.CIRCLE_RADIUS, Config.ZONE_RADIUS, Config.GROUND_Y
local FX, FZ = Config.FIELD_X, Config.FIELD_Z
local WHITE = Color3.fromRGB(247, 243, 227)

local THEMES = {
	field = {
		floor = Color3.fromRGB(79, 154, 60), material = Enum.Material.Grass,
		disc = Color3.fromRGB(63, 132, 48), ring = WHITE, bush = Color3.fromRGB(55, 135, 45),
		wall = Enum.Material.WoodPlanks, wallColor = WHITE,
		light = { ClockTime = 14, OutdoorAmbient = Color3.fromRGB(128, 128, 128), FogEnd = 100000, FogColor = Color3.fromRGB(192, 192, 192) },
	},
	jungle = {
		floor = Color3.fromRGB(58, 118, 44), material = Enum.Material.LeafyGrass,
		disc = Color3.fromRGB(80, 140, 60), ring = Color3.fromRGB(250, 235, 170), bush = Color3.fromRGB(40, 110, 40),
		wall = Enum.Material.Wood, wallColor = Color3.fromRGB(110, 75, 45),
		light = { ClockTime = 13, OutdoorAmbient = Color3.fromRGB(110, 140, 110), FogEnd = 700, FogColor = Color3.fromRGB(150, 190, 140) },
	},
	volcano = {
		floor = Color3.fromRGB(75, 62, 56), material = Enum.Material.Basalt,
		disc = Color3.fromRGB(100, 80, 68), ring = Color3.fromRGB(255, 200, 120), bush = Color3.fromRGB(95, 110, 50),
		wall = Enum.Material.Slate, wallColor = Color3.fromRGB(60, 50, 45),
		light = { ClockTime = 17.8, OutdoorAmbient = Color3.fromRGB(160, 100, 80), FogEnd = 600, FogColor = Color3.fromRGB(110, 60, 45) },
	},
	ice = {
		floor = Color3.fromRGB(205, 232, 245), material = Enum.Material.Ice,
		disc = Color3.fromRGB(175, 212, 236), ring = Color3.fromRGB(60, 120, 200), bush = Color3.fromRGB(225, 240, 250),
		wall = Enum.Material.Ice, wallColor = Color3.fromRGB(170, 210, 240),
		light = { ClockTime = 12, OutdoorAmbient = Color3.fromRGB(170, 190, 220), FogEnd = 600, FogColor = Color3.fromRGB(225, 238, 250) },
	},
}

function Arena.circleCenters(): { Vector3 }
	local list = {}
	for i = 1, 10 do
		local col = (i - 1) % 5
		local row = (i - 1) // 5
		table.insert(list, Vector3.new(-128 + col * 64 + (row == 0 and -8 or 8), G, row == 0 and -40 or 40))
	end
	return list
end
local CENTERS = Arena.circleCenters()

-- случайное место на поле, где нет кругов и спавна
function Arena.freePos(margin: number?): Vector3
	margin = margin or 3
	for _ = 1, 60 do
		local p = Vector3.new(math.random(-FX / 2 + 8, FX / 2 - 8), G, math.random(-FZ / 2 + 8, FZ / 2 - 8))
		local ok = p.Magnitude > 22
		for _, c in ipairs(CENTERS) do
			if (p - c).Magnitude < ZONE + (margin :: number) then
				ok = false
				break
			end
		end
		if ok then
			return p
		end
	end
	return Vector3.new(math.random(-120, 120), G, 75)
end

-- ---------- поле на один тайм ----------

local current: Folder? = nil

local function applyLighting(theme, event: string)
	for k, v in pairs(theme.light) do
		(Lighting :: any)[k] = v
	end
	Lighting.Ambient = Color3.fromRGB(90, 90, 90)
	if event == "halloween" then
		Lighting.ClockTime = 18.2
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 110, 150)
	end
end

function Arena.buildRound(themeId: string, event: string)
	local theme = THEMES[themeId] or THEMES.field
	local folder = Instance.new("Folder")
	folder.Name = "DinoArena"

	local floor = Models.part(folder, Vector3.new(FX, 1, FZ), CFrame.new(0, G - 0.5, 0), theme.floor, theme.material)
	floor.CanCollide = true
	floor.Name = "Field"
	for _, w in ipairs({
		{ Vector3.new(FX, 3, 2), Vector3.new(0, 1.5, FZ / 2) },
		{ Vector3.new(FX, 3, 2), Vector3.new(0, 1.5, -FZ / 2) },
		{ Vector3.new(2, 3, FZ), Vector3.new(FX / 2, 1.5, 0) },
		{ Vector3.new(2, 3, FZ), Vector3.new(-FX / 2, 1.5, 0) },
	}) do
		local wall = Models.part(folder, w[1], CFrame.new(w[2]), theme.wallColor, theme.wall)
		wall.CanCollide = true
	end

	local circles = {}
	local rainbowCircle = math.random(1, 10)
	for i, center in ipairs(CENTERS) do
		local kind = Config.DINO_ORDER[(i - 1) % 4 + 1]
		local def = Config.DINOS[kind]

		local disc = Models.cylinder(folder, 0.1, R * 2, CFrame.new(center + Vector3.new(0, 0.06, 0)), theme.disc)
		disc.Name = "Circle"
		local ring = {}
		local N = 24
		local segLen = 2 * math.pi * R / N * 0.9
		for s = 0, N - 1 do
			local a = s / N * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * R, 0.15, math.sin(a) * R)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			table.insert(ring, Models.part(folder, Vector3.new(0.8, 0.3, segLen), CFrame.lookAt(pos, pos + tangent), theme.ring))
		end
		for s = 0, 15 do
			local a = s / 16 * math.pi * 2
			local dot = Models.part(folder, Vector3.new(0.6, 0.2, 0.6), CFrame.new(center + Vector3.new(math.cos(a) * ZONE, 0.1, math.sin(a) * ZONE)), theme.ring)
			dot.Transparency = 0.5
		end

		local circle = {
			index = i,
			center = center,
			kind = kind,
			def = def,
			ring = ring,
			ringColor = theme.ring,
			eggs = {},
			occupant = nil,
			crackUntil = 0,
			cracked = false,
			dinoPos = center,
			dinoFace = Vector3.new(0, 0, -1),
			dashUntil = 0,
			nextDash = 0,
			chasing = false,
			camo = false,
		}

		for e = 0, 4 do
			local a = -math.pi / 2 + e * (math.pi * 2 / 5)
			local home = CFrame.new(center + Vector3.new(math.cos(a) * R * 0.6, 0.95, math.sin(a) * R * 0.6))
			local eggKind = kind == "gold" and "gold" or "normal"
			if i == rainbowCircle and e == 0 then
				eggKind = "rainbow"
			end
			table.insert(circle.eggs, {
				part = Models.egg(eggKind, home, folder, event),
				home = home,
				kind = eggKind,
				baseKind = kind == "gold" and "gold" or "normal",
				taken = false,
				respawnAt = 0,
				circle = circle,
			})
		end

		local hat = (event == "halloween" and "hat_pumpkin") or (event == "newyear" and "hat_santa") or nil
		local model, colorParts, height = Models.dino(def.color, def.dark, 1, {
			name = def.name .. " динозавр",
			label = def.name,
			hat = hat,
			trail = kind == "rainbow",
		})
		model:PivotTo(CFrame.new(center + Vector3.new(0, height, 0)))
		model.Parent = folder
		circle.dino = model
		circle.colorParts = colorParts
		circle.bubble = Models.bubble(colorParts[2], 5)
		circle.nextChat = os.clock() + math.random(2, 12)
		circle.chatUntil = 0
		circle.height = height
		circle.allParts = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(circle.allParts, d)
			end
		end

		-- куст, где можно спрятаться, между кругом и границей
		local a = math.random() * math.pi * 2
		circle.bushPos = center + Vector3.new(math.cos(a) * (R + ZONE) / 2, 0, math.sin(a) * (R + ZONE) / 2)
		table.insert(circles, circle)
	end

	local bushes = {}
	for _, c in ipairs(circles) do
		Models.bush(folder, c.bushPos, theme.bush)
		table.insert(bushes, c.bushPos)
	end

	local lava = {}
	if themeId == "field" then
		for _ = 1, 50 do
			Models.flower(folder, Arena.freePos(1))
		end
		for _ = 1, 6 do
			Models.tree(folder, Arena.freePos(6), false)
		end
	elseif themeId == "jungle" then
		for _ = 1, 14 do
			Models.tree(folder, Arena.freePos(6), true)
		end
		for _ = 1, 6 do
			Models.tree(folder, Arena.freePos(6), false)
		end
		for _ = 1, 6 do
			local p = Arena.freePos(4)
			Models.bush(folder, p, theme.bush)
			table.insert(bushes, p)
		end
	elseif themeId == "volcano" then
		Models.volcano(folder, Vector3.new(0, G, -FZ / 2 - 45))
		for _ = 1, 6 do
			local p = Arena.freePos(6)
			Models.lava(folder, p, 4)
			table.insert(lava, { pos = p, radius = 4 })
		end
	elseif themeId == "ice" then
		for _ = 1, 8 do
			Models.snowman(folder, Arena.freePos(4))
		end
	end

	if event == "halloween" then
		for _ = 1, 12 do
			Models.pumpkin(folder, Arena.freePos(3))
		end
	elseif event == "newyear" then
		local sky = Models.part(folder, Vector3.new(FX, 1, FZ), CFrame.new(0, 70, 0), WHITE)
		sky.Transparency = 1
		local snow = Instance.new("ParticleEmitter")
		snow.EmissionDirection = Enum.NormalId.Bottom
		snow.Rate = 150
		snow.Lifetime = NumberRange.new(10)
		snow.Speed = NumberRange.new(6, 9)
		snow.Size = NumberSequence.new(0.4)
		snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
		snow.SpreadAngle = Vector2.new(10, 10)
		snow.Parent = sky
		for _ = 1, 4 do
			Models.snowman(folder, Arena.freePos(4))
		end
	end

	applyLighting(theme, event)

	-- новое поле ставим раньше, чем убираем старое, чтобы никто не провалился
	folder.Parent = Workspace
	if current then
		current:Destroy()
	end
	current = folder

	return { folder = folder, circles = circles, bushes = bushes, lava = lava, theme = themeId, event = event }
end

-- заменить яйцо на яйцо другого вида (например, иногда появляется радужное)
function Arena.remakeEgg(egg, kind: string, event: string, folder: Instance)
	egg.part:Destroy()
	egg.kind = kind
	egg.part = Models.egg(kind, egg.home, folder, event)
end

return Arena
