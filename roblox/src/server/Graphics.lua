-- Красота: свет, атмосфера, облака, ландшафт (холмы, горы, озёра, вулкан) и погода на каждой карте.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Net = require(script.Parent.Net)

local Graphics = {}

local terrain = Workspace:FindFirstChildOfClass("Terrain")
Graphics.hasTerrain = terrain ~= nil

local FX, FZ = Config.FIELD_X, Config.FIELD_Z

-- ---------- свет и эффекты ----------

local function effect(className: string, name: string): any
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e
end

local atmosphere, bloom, color, rays, dof

function Graphics.setup()
	Lighting.GlobalShadows = true
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	Lighting.GeographicLatitude = 35

	atmosphere = effect("Atmosphere", "DinoAtmosphere")
	bloom = effect("BloomEffect", "DinoBloom")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 0.95
	color = effect("ColorCorrectionEffect", "DinoColor")
	rays = effect("SunRaysEffect", "DinoSunRays")
	rays.Intensity = 0.07
	rays.Spread = 0.8
	dof = effect("DepthOfFieldEffect", "DinoDepth")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 80
	dof.InFocusRadius = 120
	dof.NearIntensity = 0

	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.7
		clouds.Parent = terrain
		terrain.WaterColor = Color3.fromRGB(40, 150, 200)
		terrain.WaterReflectance = 0.6
		terrain.WaterTransparency = 0.6
		terrain.WaterWaveSize = 0.2
		terrain.WaterWaveSpeed = 8
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 190, 70))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 140, 50))
		terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(240, 248, 255))
		terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(235, 245, 255))
		terrain:SetMaterialColor(Enum.Material.Ice, Color3.fromRGB(170, 215, 245))
		terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 60, 58))
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(235, 215, 160))
	end
end

-- ---------- мир вокруг: холмы, горы, озёра, вулкан ----------

local volcanoTop: BasePart? = nil

local function hill(center: Vector3, radius: number, material: Enum.Material)
	if terrain then
		terrain:FillBall(center, radius, material)
	end
end

function Graphics.buildWorld(folder: Instance)
	if not terrain then
		-- без ландшафта просто большая трава под всем миром
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(1400, 2, 1400)
		p.CFrame = CFrame.new(0, -1, 0)
		p.Material = Enum.Material.Grass
		p.Color = Color3.fromRGB(106, 190, 70)
		p.Parent = folder
		return
	end
	local t = terrain :: Terrain
	t:Clear()
	-- земля
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1400, 12, 1400), Enum.Material.Grass)
	-- озеро у обби (туда падают с островков)
	local ox = -FX / 2 - 50
	t:FillBlock(CFrame.new(ox, -12, -10), Vector3.new(88, 24, FZ + 60), Enum.Material.Air)
	t:FillBlock(CFrame.new(ox, -17, -10), Vector3.new(88, 14, FZ + 60), Enum.Material.Water)
	t:FillBlock(CFrame.new(ox, -26, -10), Vector3.new(92, 4, FZ + 64), Enum.Material.Sand)
	-- красивое озеро на востоке
	t:FillBlock(CFrame.new(FX / 2 + 70, -6, 0), Vector3.new(90, 12, 130), Enum.Material.Air)
	t:FillBlock(CFrame.new(FX / 2 + 70, -9, 0), Vector3.new(90, 10, 130), Enum.Material.Water)
	t:FillBlock(CFrame.new(FX / 2 + 70, -15, 0), Vector3.new(94, 4, 134), Enum.Material.Sand)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		t:FillBall(Vector3.new(FX / 2 + 70 + math.cos(a) * 52, -3, math.sin(a) * 72), 9, Enum.Material.Sand)
	end

	-- холмы по кругу
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2 + math.random() * 0.15
		local d = math.random(360, 430)
		local r = math.random(45, 80)
		hill(Vector3.new(math.cos(a) * d, -r * 0.55, math.sin(a) * d + 40), r, Enum.Material.Grass)
	end
	-- горы со снежными вершинами
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + math.random() * 0.2
		local d = math.random(560, 640)
		local r = math.random(90, 140)
		local c = Vector3.new(math.cos(a) * d, -r * 0.3, math.sin(a) * d)
		hill(c, r, Enum.Material.Rock)
		hill(c + Vector3.new(0, r * 0.62, 0), r * 0.42, Enum.Material.Glacier) -- не Snow: снег на «Льду» заменяется
	end
	-- дымящийся вулкан вдали (на севере)
	local vz = -330
	for i = 0, 11 do
		t:FillCylinder(CFrame.new(0, i * 7 + 3.5, vz), 7, 95 - i * 7.2, i < 9 and Enum.Material.Rock or Enum.Material.Slate) -- не Basalt: это земля «Вулкана»
	end
	t:FillCylinder(CFrame.new(0, 84, vz), 4, 14, Enum.Material.CrackedLava)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		t:FillBlock(CFrame.new(math.cos(a) * 30, 50 - i, vz + math.sin(a) * 30) * CFrame.Angles(0, -a, 0), Vector3.new(6, 2, 50), Enum.Material.CrackedLava)
	end
	local top = Instance.new("Part")
	top.Anchored = true
	top.CanCollide = false
	top.Transparency = 1
	top.Size = Vector3.new(20, 1, 20)
	top.CFrame = CFrame.new(0, 88, vz)
	top.Parent = folder
	local smoke = Instance.new("Smoke")
	smoke.Size = 25
	smoke.RiseVelocity = 15
	smoke.Opacity = 0.15
	smoke.Color = Color3.fromRGB(90, 90, 90)
	smoke.Parent = top
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 60
	light.Brightness = 3
	light.Parent = top
	volcanoTop = top
end

-- ---------- вид каждой карты ----------

local LOOKS = {
	field = {
		ground = Enum.Material.Grass, floor = Enum.Material.Grass, weather = "pollen",
		clock = 14.5, ambient = Color3.fromRGB(130, 130, 140),
		atmo = { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(199, 226, 255), Decay = Color3.fromRGB(106, 112, 125), Glare = 0.3, Haze = 1.2 },
		tint = Color3.fromRGB(255, 252, 245), saturation = 0.2,
	},
	jungle = {
		ground = Enum.Material.LeafyGrass, floor = Enum.Material.LeafyGrass, weather = "leaves",
		clock = 13, ambient = Color3.fromRGB(110, 140, 110),
		atmo = { Density = 0.42, Offset = 0.2, Color = Color3.fromRGB(190, 225, 175), Decay = Color3.fromRGB(80, 110, 80), Glare = 0.2, Haze = 2.4 },
		tint = Color3.fromRGB(240, 255, 235), saturation = 0.25,
	},
	volcano = {
		ground = Enum.Material.Basalt, floor = Enum.Material.Basalt, weather = "ash",
		clock = 17.6, ambient = Color3.fromRGB(160, 100, 80),
		atmo = { Density = 0.45, Offset = 0.1, Color = Color3.fromRGB(255, 160, 120), Decay = Color3.fromRGB(110, 50, 35), Glare = 0.5, Haze = 2 },
		tint = Color3.fromRGB(255, 228, 212), saturation = 0.15,
	},
	ice = {
		ground = Enum.Material.Snow, floor = Enum.Material.Ice, weather = "snow",
		clock = 11, ambient = Color3.fromRGB(170, 190, 220),
		atmo = { Density = 0.35, Offset = 0.2, Color = Color3.fromRGB(225, 238, 255), Decay = Color3.fromRGB(150, 170, 200), Glare = 0.4, Haze = 1.6 },
		tint = Color3.fromRGB(240, 248, 255), saturation = 0.1,
	},
}

local currentGround = Enum.Material.Grass

function Graphics.applyTheme(themeId: string, event: string)
	local look = LOOKS[themeId] or LOOKS.field
	if terrain then
		local t = terrain :: Terrain
		if look.ground ~= currentGround then
			-- меняем траву на снег/пепел кусочками, чтобы не упереться в лимит Roblox
			for x = -720, 360, 360 do
				for z = -720, 360, 360 do
					local region = Region3.new(Vector3.new(x, -40, z), Vector3.new(x + 360, 140, z + 360)):ExpandToGrid(4)
					pcall(function()
						t:ReplaceMaterial(region, 4, currentGround, look.ground)
					end)
				end
			end
			currentGround = look.ground
		end
		-- пол поля: на льду — настоящий скользкий лёд
		t:FillBlock(CFrame.new(0, -2, 0), Vector3.new(FX, 4, FZ), look.floor)
	end

	Lighting.ClockTime = look.clock
	Lighting.OutdoorAmbient = look.ambient
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.FogEnd = 100000
	for k, v in pairs(look.atmo) do
		atmosphere[k] = v
	end
	color.TintColor = look.tint
	color.Saturation = look.saturation
	color.Contrast = 0.08
	color.Brightness = 0.02

	local weather = look.weather
	if event == "halloween" then
		Lighting.ClockTime = 18.3
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 120, 170)
		atmosphere.Color = Color3.fromRGB(200, 170, 230)
		color.TintColor = Color3.fromRGB(235, 220, 255)
		weather = "fireflies"
	elseif event == "newyear" then
		weather = "snow"
	end
	if terrain then
		local clouds = (terrain :: Terrain):FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Color = event == "halloween" and Color3.fromRGB(200, 180, 220) or Color3.new(1, 1, 1)
			clouds.Cover = themeId == "volcano" and 0.7 or 0.55
		end
	end
	if volcanoTop then
		local smoke = volcanoTop:FindFirstChildOfClass("Smoke")
		if smoke then
			smoke.Opacity = themeId == "volcano" and 0.35 or 0.15
			smoke.Size = themeId == "volcano" and 40 or 25
		end
	end
	Net.set("Weather", weather)
end

-- светящиеся трещины лавы на поле (только на карте «Вулкан»)
function Graphics.lavaPatch(pos: Vector3, radius: number)
	if terrain then
		(terrain :: Terrain):FillCylinder(CFrame.new(pos.X, -1, pos.Z), 2, radius, Enum.Material.CrackedLava)
	end
end

return Graphics
