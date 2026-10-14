-- Комната ожидания «Динопарк»: батуты, горка, бассейн с шариками, грибы-великаны,
-- банановые шкурки, подушки-пукалки, дискотека, говорящая статуя динозавра, гнездо и вход в обби.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Models = require(script.Parent.Models)
local Graphics = require(script.Parent.Graphics)

local Lobby = {}

local G = Config.GROUND_Y
local L = Vector3.new(0, G, 210) -- центр Динопарка (к югу от поля)
local LX, LZ = 130, 100

local BRIGHT = {
	Color3.fromRGB(255, 95, 95),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(255, 240, 90),
	Color3.fromRGB(110, 210, 90),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 130, 200),
}
local function bright(i: number): Color3
	return BRIGHT[(i - 1) % #BRIGHT + 1]
end

local function at(x: number, y: number, z: number): Vector3
	return L + Vector3.new(x, y, z)
end

local function tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

local function solid(p: BasePart): BasePart
	p.CanCollide = true
	return p
end

function Lobby.build()
	local folder = Instance.new("Folder")
	folder.Name = "DinoPark"

	-- пол и забор
	if not Graphics.hasTerrain then
		solid(Models.part(folder, Vector3.new(LX, 1, LZ), CFrame.new(at(0, -0.5, 0)), Color3.fromRGB(125, 205, 95), Enum.Material.Grass))
	end
	-- дорожки из плитки
	for i = -6, 6 do
		Models.part(folder, Vector3.new(4.4, 0.15, 3.6), CFrame.new(at(0, 0.07, i * 4 + 6)), i % 2 == 0 and Color3.fromRGB(240, 225, 200) or Color3.fromRGB(225, 205, 175), Enum.Material.Pavement)
	end
	for i = -14, 14 do
		Models.part(folder, Vector3.new(3.6, 0.15, 4.4), CFrame.new(at(i * 4, 0.07, 6)), i % 2 == 0 and Color3.fromRGB(240, 225, 200) or Color3.fromRGB(225, 205, 175), Enum.Material.Pavement)
	end
	-- фонари, скамейки, сладкая вата, деревья, клумбы
	for _, p in ipairs({ { -8, -10 }, { 8, -10 }, { -8, 22 }, { 8, 22 }, { -30, 10 }, { 30, 10 }, { -55, 10 }, { 55, 10 } }) do
		Models.lamp(folder, at(p[1], 0, p[2]))
	end
	for _, b in ipairs({ { -20, 10, 0 }, { 20, 10, 180 }, { -4, -40, 0 }, { 30, 40, 90 } }) do
		Models.bench(folder, CFrame.new(at(b[1], 0, b[2] - 3)) * CFrame.Angles(0, math.rad(b[3]), 0))
	end
	Models.candyCart(folder, CFrame.new(at(-6, 0, 40)) * CFrame.Angles(0, math.rad(200), 0))
	for _, p in ipairs({ { -58, -42 }, { 58, -42 }, { -58, 40 }, { 58, 40 }, { -30, -44 }, { 22, 44 }, { 60, -10 } }) do
		Models.tree(folder, at(p[1], 0, p[2]), false)
	end
	for _ = 1, 40 do
		local x, z = math.random(-60, 60), math.random(-45, 45)
		if math.abs(x) > 8 and math.abs(z - 6) > 4 then
			Models.flower(folder, at(x, 0, z))
		end
	end
	for i = 1, 14 do
		local spot = Models.cylinder(folder, 0.1, math.random(6, 12), CFrame.new(at(math.random(-55, 55), 0.06, math.random(-40, 40))), bright(i))
		spot.Transparency = 0.55
	end
	local sides = {
		{ Vector3.new(LX, 80, 2), at(0, 40, LZ / 2) },
		{ Vector3.new(LX, 80, 2), at(0, 40, -LZ / 2) },
		{ Vector3.new(2, 80, LZ), at(LX / 2, 40, 0) },
		{ Vector3.new(2, 80, LZ), at(-LX / 2, 40, 0) },
	}
	for _, w in ipairs(sides) do
		local wall = solid(Models.part(folder, w[1], CFrame.new(w[2]), Color3.new(1, 1, 1)))
		wall.Transparency = 1
	end
	local n = 0
	for x = -LX / 2, LX / 2 - 5, 5 do
		for _, z in ipairs({ -LZ / 2, LZ / 2 }) do
			n += 1
			Models.part(folder, Vector3.new(4.6, 3, 0.6), CFrame.new(at(x + 2.5, 1.5, z)), bright(n))
		end
	end
	for z = -LZ / 2, LZ / 2 - 5, 5 do
		for _, x in ipairs({ -LX / 2, LX / 2 }) do
			n += 1
			Models.part(folder, Vector3.new(0.6, 3, 4.6), CFrame.new(at(x, 1.5, z + 2.5)), bright(n))
		end
	end
	-- воздушные шарики по углам
	for i, c in ipairs({ { -60, -45 }, { 60, -45 }, { -60, 45 }, { 60, 45 } }) do
		for k = 0, 2 do
			local top = at(c[1] + k * 1.5 - 1.5, 14 + k, c[2])
			Models.part(folder, Vector3.new(0.1, 11 + k, 0.1), CFrame.new(top - Vector3.new(0, (11 + k) / 2, 0)), Color3.new(1, 1, 1))
			Models.ball(folder, Vector3.new(3, 3.6, 3), CFrame.new(top + Vector3.new(0, 1.8, 0)), bright(i * 3 + k), Enum.Material.SmoothPlastic)
		end
	end

	-- спавн
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(at(0, 0, 30))
	spawn.Color = Color3.fromRGB(47, 111, 216)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = folder

	-- табло
	local board = solid(Models.part(folder, Vector3.new(44, 14, 1), CFrame.new(at(0, 9, -48)), Color3.fromRGB(31, 42, 23)))
	for _, x in ipairs({ -20, 20 }) do
		solid(Models.part(folder, Vector3.new(1.5, 9, 1.5), CFrame.new(at(x, 1, -48)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood))
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(880, 280)
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Text = "🦖 ДИНОПАРК 🦖"
	title.Parent = sg
	local boardStatus = Instance.new("TextLabel")
	boardStatus.Position = UDim2.fromScale(0.05, 0.55)
	boardStatus.Size = UDim2.fromScale(0.9, 0.38)
	boardStatus.BackgroundTransparency = 1
	boardStatus.Font = Enum.Font.FredokaOne
	boardStatus.TextScaled = true
	boardStatus.TextColor3 = Color3.new(1, 1, 1)
	boardStatus.Text = "Ждём игроков"
	boardStatus.Parent = sg

	-- портал в игру
	local gamePortalPos = at(0, 0, 44)
	local portal = Models.cylinder(folder, 0.4, 8, CFrame.new(gamePortalPos + Vector3.new(0, 0.2, 0)), Color3.fromRGB(80, 220, 90), Enum.Material.Neon)
	Models.label(portal, "▶ В ИГРУ", 4, Color3.fromRGB(170, 255, 170), 80)

	-- вход в обби
	local padPos = at(-22, 0, -30)
	local pad = Models.cylinder(folder, 0.4, 6, CFrame.new(padPos + Vector3.new(0, 0.2, 0)), Color3.fromRGB(150, 90, 230), Enum.Material.Neon)
	Models.label(pad, "🏃 ОББИ", 4, Color3.fromRGB(220, 190, 255), 80)

	-- гнездо
	local nestPos = at(24, 0, -12)
	local _, nestPrompt = Models.nest(folder, nestPos)

	-- дискотека
	local disco = {}
	for i = 0, 5 do
		for j = 0, 5 do
			local tile = Models.part(folder, Vector3.new(3.8, 0.2, 3.8), CFrame.new(at(-10 + i * 4, 0.1, -32 + j * 4)), bright(i + j + 1), Enum.Material.Neon)
			table.insert(disco, tile)
		end
	end
	local discoSign = Models.part(folder, Vector3.new(1, 1, 1), CFrame.new(at(0, 0.5, -21)), Color3.new(1, 1, 1))
	discoSign.Transparency = 1
	Models.label(discoSign, "💃 Дискотека", 5, Color3.fromRGB(255, 200, 255), 60)

	-- батуты
	for i, z in ipairs({ -10, 6, 22 }) do
		local pos = at(-48, 0, z)
		Models.cylinder(folder, 0.8, 9, CFrame.new(pos + Vector3.new(0, 0.4, 0)), bright(i + 3))
		local mat = Models.cylinder(folder, 0.9, 7, CFrame.new(pos + Vector3.new(0, 0.45, 0)), Color3.fromRGB(40, 40, 50))
		tag(mat, "Trampoline")
		if i == 2 then
			Models.label(mat, "🤸 Батуты", 6, Color3.fromRGB(180, 230, 255), 60)
		end
	end

	-- банановые шкурки
	for _, p in ipairs({ { -12, -2 }, { 14, -4 }, { 28, 32 }, { -26, 14 } }) do
		local pos = at(p[1], 0.15, p[2])
		local peel = Models.ball(folder, Vector3.new(2, 0.3, 1.2), CFrame.new(pos), Color3.fromRGB(250, 220, 60))
		for k = -1, 1 do
			Models.ball(folder, Vector3.new(1.6, 0.25, 0.6), CFrame.new(pos + Vector3.new(1.1, 0, k * 0.6)) * CFrame.Angles(0, math.rad(k * 35), 0), Color3.fromRGB(240, 200, 50))
		end
		tag(peel, "Banana")
	end

	-- подушки-пукалки
	for _, p in ipairs({ { 6, 8 }, { -30, 32 } }) do
		local cushion = Models.ball(folder, Vector3.new(3.4, 0.9, 3.4), CFrame.new(at(p[1], 0.4, p[2])), Color3.fromRGB(255, 120, 190))
		Models.ball(folder, Vector3.new(0.8, 0.5, 0.8), CFrame.new(at(p[1] + 1.8, 0.4, p[2])), Color3.fromRGB(255, 120, 190))
		Models.label(cushion, "Не наступай! 😏", 3, Color3.fromRGB(255, 180, 220), 40)
		tag(cushion, "Fart")
	end

	-- грибы: красный делает великаном, синий — малышом
	for _, m in ipairs({ { -15, "big", Color3.fromRGB(230, 50, 50), "🍄 Великан" }, { 15, "small", Color3.fromRGB(70, 130, 240), "🍄 Малыш" } }) do
		local pos = at(m[1], 0, 22)
		local stem = solid(Models.cylinder(folder, 3.5, 2.4, CFrame.new(pos + Vector3.new(0, 1.75, 0)), Color3.fromRGB(250, 240, 220)))
		local cap = Models.ball(folder, Vector3.new(8, 4, 8), CFrame.new(pos + Vector3.new(0, 4.5, 0)), m[3])
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Models.ball(folder, Vector3.new(1.2, 0.6, 1.2), CFrame.new(pos + Vector3.new(math.cos(a) * 2.6, 5.8, math.sin(a) * 2.6)), Color3.new(1, 1, 1))
		end
		stem:SetAttribute("Kind", m[2])
		tag(stem, "Mushroom")
		Models.label(cap, m[4], 4, m[3]:Lerp(Color3.new(1, 1, 1), 0.4), 60)
	end

	-- горка: башня с лестницей, длинный скат прямо в бассейн с шариками
	local towerPos = at(46, 0, -34)
	for _, o in ipairs({ { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 } }) do
		solid(Models.part(folder, Vector3.new(1, 16, 1), CFrame.new(towerPos + Vector3.new(o[1], 8, o[2])), Color3.fromRGB(255, 190, 60)))
	end
	solid(Models.part(folder, Vector3.new(8, 1, 8), CFrame.new(towerPos + Vector3.new(0, 16, 0)), Color3.fromRGB(255, 95, 95)))
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 16, 2)
	ladder.CFrame = CFrame.new(towerPos + Vector3.new(0, 8, -5))
	ladder.Color = Color3.fromRGB(80, 170, 255)
	ladder.Parent = folder
	local top = towerPos + Vector3.new(0, 16.5, 4)
	local bottom = at(46, 0.5, 6)
	local along = bottom - top
	local mid = (top + bottom) / 2
	local slideCF = CFrame.lookAt(mid, bottom)
	local slide = solid(Models.part(folder, Vector3.new(6, 1, along.Magnitude), slideCF, Color3.fromRGB(110, 210, 90)))
	slide.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	slide:SetAttribute("Dir", along.Unit)
	tag(slide, "Slide")
	for _, x in ipairs({ -3.2, 3.2 }) do
		solid(Models.part(folder, Vector3.new(0.5, 1.6, along.Magnitude), slideCF * CFrame.new(x, 1, 0), Color3.fromRGB(255, 240, 90)))
	end
	Models.label(slide, "🛝 Горка", 8, Color3.fromRGB(200, 255, 180), 60)

	-- бассейн с шариками
	local pit = at(46, 0, 13)
	for _, w in ipairs({
		{ Vector3.new(18, 2.5, 1), Vector3.new(0, 1.25, -9) },
		{ Vector3.new(18, 2.5, 1), Vector3.new(0, 1.25, 9) },
		{ Vector3.new(1, 2.5, 18), Vector3.new(-9, 1.25, 0) },
		{ Vector3.new(1, 2.5, 18), Vector3.new(9, 1.25, 0) },
	}) do
		solid(Models.part(folder, w[1], CFrame.new(pit + w[2]), Color3.fromRGB(80, 170, 255)))
	end
	for i = 1, 90 do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(1.8, 1.8, 1.8)
		b.Color = bright(i)
		b.Material = Enum.Material.SmoothPlastic
		b.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.5)
		b.CFrame = CFrame.new(pit + Vector3.new(math.random(-7, 7), 1 + (i % 5) * 1.8, math.random(-7, 7)))
		b.Parent = folder
	end

	-- статуя динозавра: если погладить, говорит смешное
	local statuePos = at(-40, 0, -36)
	local statue, colorParts, height = Models.dino(Color3.fromRGB(190, 150, 255), Color3.fromRGB(120, 80, 200), 1.6, {
		name = "Дино Добряк",
		label = "Дино Добряк",
	})
	local body = statuePos + Vector3.new(0, height, 0)
	statue:PivotTo(CFrame.lookAt(body, body + Vector3.new(0.4, 0, 1)))
	statue.Parent = folder
	local head = colorParts[2]
	local statueBubble = Models.bubble(head, 6)
	local statuePrompt = Instance.new("ProximityPrompt")
	statuePrompt.ActionText = "Погладить"
	statuePrompt.ObjectText = "Дино Добряк"
	statuePrompt.HoldDuration = 0
	statuePrompt.MaxActivationDistance = 16
	statuePrompt.RequiresLineOfSight = false
	statuePrompt.Parent = colorParts[1]

	-- обби (за западной стеной поля, над голубой «водой»)
	local FX, FZ = Config.FIELD_X, Config.FIELD_Z
	local ox = -FX / 2 - 45
	if not Graphics.hasTerrain then
		local water = Models.part(folder, Vector3.new(70, 1, FZ + 40), CFrame.new(ox, -12, 0), Color3.fromRGB(70, 180, 230), Enum.Material.Neon)
		water.Transparency = 0.3
	end
	local start = solid(Models.part(folder, Vector3.new(12, 1, 12), CFrame.new(ox, 2, -75), Color3.fromRGB(150, 90, 230)))
	Models.label(start, "Прыгай по островкам!", 6, Color3.fromRGB(220, 190, 255), 80)
	local last = Vector3.new(ox, 2, -75)
	for i = 1, 14 do
		local pos = Vector3.new(ox + ((i % 3) - 1) * 4, 2 + i * 1.2, -75 + i * 8)
		local size = i % 4 == 0 and Vector3.new(3.5, 1, 3.5) or Vector3.new(5, 1, 5)
		solid(Models.part(folder, size, CFrame.new(pos), Color3.fromHSV(i / 14, 0.6, 1)))
		last = pos
	end
	local finishPos = last + Vector3.new(0, 1, 10)
	local finish = solid(Models.part(folder, Vector3.new(12, 1, 12), CFrame.new(finishPos), Color3.fromRGB(242, 194, 48), Enum.Material.Foil))
	Models.label(finish, "🏁 ФИНИШ", 6, Color3.fromRGB(255, 230, 120), 120)

	folder.Parent = Workspace

	return {
		folder = folder,
		center = L,
		spawnCFrame = CFrame.new(at(0, 4, 30)),
		fieldCFrame = CFrame.new(0, G + 4, 0),
		gamePortalPos = gamePortalPos,
		padPos = padPos,
		nestPrompt = nestPrompt,
		boardStatus = boardStatus,
		disco = disco,
		statue = { model = statue, pos = statuePos, height = height, bubble = statueBubble },
		statuePrompt = statuePrompt,
		obbyStart = CFrame.new(ox, 6, -75),
		finishPos = finishPos,
	}
end

-- игрок в Динопарке?
function Lobby.contains(pos: Vector3): boolean
	return math.abs(pos.X - L.X) < LX / 2 and math.abs(pos.Z - L.Z) < LZ / 2
end

return Lobby
