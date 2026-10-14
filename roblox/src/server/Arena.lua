-- Строит поле на каждый тайм: 4 карты, круги из камней, гнёзда, флажки, динозавры, яйца, кусты и украшения.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Models = require(script.Parent.Models)
local Graphics = require(script.Parent.Graphics)

local Arena = {}

local R, ZONE, G = Config.CIRCLE_RADIUS, Config.ZONE_RADIUS, Config.GROUND_Y
local FX, FZ = Config.FIELD_X, Config.FIELD_Z

local THEMES = {
	field = {
		floor = Color3.fromRGB(106, 190, 70), material = Enum.Material.Grass,
		straw = Color3.fromRGB(225, 200, 130), stone = Color3.fromRGB(235, 232, 220), bush = Color3.fromRGB(55, 140, 45),
		fence = Color3.fromRGB(250, 248, 240), flags = { Color3.fromRGB(255, 95, 95), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 210, 60) },
	},
	jungle = {
		floor = Color3.fromRGB(70, 140, 50), material = Enum.Material.LeafyGrass,
		straw = Color3.fromRGB(150, 120, 70), stone = Color3.fromRGB(150, 160, 130), bush = Color3.fromRGB(40, 115, 40),
		fence = Color3.fromRGB(120, 85, 50), flags = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(240, 70, 120), Color3.fromRGB(80, 220, 160) },
	},
	volcano = {
		floor = Color3.fromRGB(70, 60, 58), material = Enum.Material.Basalt,
		straw = Color3.fromRGB(110, 80, 60), stone = Color3.fromRGB(60, 55, 55), bush = Color3.fromRGB(95, 110, 50),
		fence = Color3.fromRGB(60, 50, 45), flags = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 60, 40) },
	},
	ice = {
		floor = Color3.fromRGB(170, 215, 245), material = Enum.Material.Ice,
		straw = Color3.fromRGB(235, 245, 255), stone = Color3.fromRGB(80, 140, 210), bush = Color3.fromRGB(220, 238, 250),
		fence = Color3.fromRGB(170, 210, 240), flags = { Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 120, 255) },
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

-- деревянный забор вокруг поля и невидимая высокая стена, чтобы никто не убежал
local function buildFence(folder: Instance, color: Color3)
	local function side(from: Vector3, to: Vector3)
		local len = (to - from).Magnitude
		local dir = (to - from).Unit
		local cf = CFrame.lookAt((from + to) / 2, to)
		for _, y in ipairs({ 1.2, 2.6 }) do
			local rail = Models.part(folder, Vector3.new(0.4, 0.5, len), cf * CFrame.new(0, y, 0), color, Enum.Material.WoodPlanks)
			rail.CanCollide = true
		end
		local n = math.floor(len / 2.5)
		for i = 0, n do
			local p = from + dir * (i * len / n)
			local tall = i % 4 == 0
			local h = tall and 4 or 3.4
			local mid = p + Vector3.new(0, h / 2, 0)
			Models.part(folder, Vector3.new(tall and 0.8 or 0.6, h, tall and 0.8 or 0.35), CFrame.lookAt(mid, mid + dir), color, Enum.Material.WoodPlanks)
			if tall then
				Models.ball(folder, Vector3.new(0.8, 0.8, 0.8), CFrame.new(p + Vector3.new(0, 4.2, 0)), color)
			end
		end
		local wall = Models.part(folder, Vector3.new(1, 60, len), cf * CFrame.new(0, 30, 0), color)
		wall.Transparency = 1
		wall.CanCollide = true
	end
	local x, z = FX / 2, FZ / 2
	side(Vector3.new(-x, G, -z), Vector3.new(x, G, -z))
	side(Vector3.new(x, G, -z), Vector3.new(x, G, z))
	side(Vector3.new(x, G, z), Vector3.new(-x, G, z))
	side(Vector3.new(-x, G, z), Vector3.new(-x, G, -z))
end

-- ---------- поле на один тайм ----------

local current: Folder? = nil

function Arena.buildRound(themeId: string, event: string)
	local theme = THEMES[themeId] or THEMES.field
	local folder = Instance.new("Folder")
	folder.Name = "DinoArena"

	if not Graphics.hasTerrain then
		local floor = Models.part(folder, Vector3.new(FX, 1, FZ), CFrame.new(0, G - 0.5, 0), theme.floor, theme.material)
		floor.CanCollide = true
	end
	buildFence(folder, theme.fence)

	local circles = {}
	local rainbowCircle = math.random(1, 10)
	for i, center in ipairs(CENTERS) do
		local kind = Config.DINO_ORDER[(i - 1) % 4 + 1]
		local def = Config.DINOS[kind]

		-- соломенное гнездо внутри круга
		local straw = Models.cylinder(folder, 0.12, R * 2 - 1, CFrame.new(center + Vector3.new(0, 0.06, 0)), theme.straw, Enum.Material.Sand)
		straw.Name = "Circle"
		for t = 1, 28 do
			local a = t / 28 * math.pi * 2
			local r = R * 0.6 + (t % 3 - 1) * 0.9
			Models.part(folder, Vector3.new(0.25, 0.25, 2.6), CFrame.new(center + Vector3.new(math.cos(a) * r, 0.3 + (t % 2) * 0.15, math.sin(a) * r)) * CFrame.Angles(0, -a + math.rad(math.random(60, 120)), math.rad(math.random(-15, 15))), theme.straw:Lerp(Color3.fromRGB(120, 80, 40), 0.35 + (t % 3) * 0.1), Enum.Material.Wood)
		end

		-- круг из камушков (может «сломаться»)
		local ring = {}
		local N = 24
		for s = 0, N - 1 do
			local a = s / N * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * R, 0.45, math.sin(a) * R)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			table.insert(ring, Models.ball(folder, Vector3.new(2.4, 1.1, 3.3), CFrame.lookAt(pos, pos + tangent), theme.stone, Enum.Material.Slate))
		end
		-- флажки на границе, за которую надо убежать
		for s = 0, 11 do
			local a = s / 12 * math.pi * 2
			Models.flag(folder, center + Vector3.new(math.cos(a) * ZONE, 0, math.sin(a) * ZONE), theme.flags[s % 3 + 1])
		end

		local circle = {
			index = i,
			center = center,
			kind = kind,
			def = def,
			ring = ring,
			ringColor = theme.stone,
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
			local home = CFrame.new(center + Vector3.new(math.cos(a) * R * 0.6, 1.1, math.sin(a) * R * 0.6))
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
		circle.root = model.PrimaryPart
		circle.colorParts = colorParts
		circle.bubble = Models.bubble(colorParts[2], 5)
		circle.nextChat = os.clock() + math.random(2, 12)
		circle.chatUntil = 0
		circle.height = height
		circle.allParts = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Eyelid" then
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

	-- украшения своей карты
	local lava = {}
	if themeId == "field" then
		for _ = 1, 45 do
			Models.flower(folder, Arena.freePos(1))
		end
		for _ = 1, 7 do
			Models.tree(folder, Arena.freePos(6), false)
		end
		for _ = 1, 6 do
			Models.rock(folder, Arena.freePos(3), math.random(2, 4))
		end
		for _ = 1, 3 do
			Models.log(folder, Arena.freePos(4))
		end
		for _ = 1, 10 do
			Models.mushroom(folder, Arena.freePos(1))
		end
	elseif themeId == "jungle" then
		for _ = 1, 14 do
			Models.tree(folder, Arena.freePos(6), true)
		end
		for _ = 1, 6 do
			Models.tree(folder, Arena.freePos(6), false)
		end
		for _ = 1, 20 do
			Models.fern(folder, Arena.freePos(2))
		end
		for _ = 1, 6 do
			local p = Arena.freePos(4)
			Models.bush(folder, p, theme.bush)
			table.insert(bushes, p)
		end
		for _ = 1, 4 do
			Models.log(folder, Arena.freePos(4))
		end
	elseif themeId == "volcano" then
		for _ = 1, 6 do
			local p = Arena.freePos(6)
			Models.lava(folder, p, 4)
			Graphics.lavaPatch(p, 7)
			table.insert(lava, { pos = p, radius = 4 })
		end
		for _ = 1, 12 do
			Models.rock(folder, Arena.freePos(3), math.random(2, 5))
		end
		for _ = 1, 5 do
			local vent = Models.part(folder, Vector3.new(1, 1, 1), CFrame.new(Arena.freePos(3)), Color3.new(0, 0, 0))
			vent.Transparency = 1
			local smoke = Instance.new("Smoke")
			smoke.Size = 3
			smoke.RiseVelocity = 6
			smoke.Opacity = 0.15
			smoke.Parent = vent
		end
	elseif themeId == "ice" then
		for _ = 1, 8 do
			Models.snowman(folder, Arena.freePos(4))
		end
		for _ = 1, 10 do
			Models.pine(folder, Arena.freePos(6), true)
		end
		for _ = 1, 8 do
			Models.crystal(folder, Arena.freePos(3))
		end
	end

	if event == "halloween" then
		for _ = 1, 12 do
			Models.pumpkin(folder, Arena.freePos(3))
		end
	elseif event == "newyear" then
		for _ = 1, 4 do
			Models.snowman(folder, Arena.freePos(4))
		end
		for _ = 1, 4 do
			Models.pine(folder, Arena.freePos(6), true)
		end
	end

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
