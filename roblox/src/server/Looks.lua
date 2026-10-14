-- Шапки, рюкзак, следы, питомцы и превращение игрока в динозавра.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Models = require(script.Parent.Models)

local Looks = {}

local PET_COLORS = {
	green = { Config.DINOS.green.color, Config.DINOS.green.dark },
	red = { Config.DINOS.red.color, Config.DINOS.red.dark },
	gold = { Config.DINOS.gold.color, Config.DINOS.gold.dark },
	rainbow = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(90, 60, 160) },
}
local PET_SCALE = 0.32

local petFolder = Instance.new("Folder")
petFolder.Name = "DinoPets"
petFolder.Parent = Workspace

local pets: { [Player]: any } = {}

-- ---------- костюмы ----------

local function trailColors(id: string): (ColorSequence?, boolean)
	if id == "trail_fire" then
		return ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(230, 50, 20)), false
	elseif id == "trail_hearts" then
		return ColorSequence.new(Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 200, 230)), true
	elseif id == "trail_rainbow" then
		return Models.rainbowSequence(), false
	end
	return nil, false
end

function Looks.applyCosmetics(character: Model, equipped: any, petKind: string?)
	local old = character:FindFirstChild("DinoLooks")
	if old then
		old:Destroy()
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (head and root) then
		return
	end
	-- точки следа живут на root, а не в DinoLooks — убираем старые, иначе они копятся
	for _, name in ipairs({ "TrailTop", "TrailBottom" }) do
		local a = root:FindFirstChild(name)
		while a do
			a:Destroy()
			a = root:FindFirstChild(name)
		end
	end
	local looks = Instance.new("Folder")
	looks.Name = "DinoLooks"

	if equipped.hat ~= "" then
		local hat = Instance.new("Model")
		hat.Name = "Hat"
		local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 - 0.1, 0)
		local parts = Models.hat(equipped.hat, hat, top, 1)
		if #parts > 0 then
			for _, p in ipairs(parts) do
				p.Anchored = false
			end
			Models.weldTo(hat, head)
			hat.Parent = looks
		end
	end

	if equipped.back ~= "" then
		local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
		if torso then
			local egg = Models.ball(nil, Vector3.new(1.8, 2.4, 1.2), torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + 0.6), Color3.fromRGB(251, 246, 230))
			for _, off in ipairs({ Vector3.new(-0.4, 0.4, 0.55), Vector3.new(0.35, -0.3, 0.55) }) do
				local spot = Models.ball(egg, Vector3.new(0.5, 0.5, 0.2), egg.CFrame * CFrame.new(off), Color3.fromRGB(150, 200, 120))
				spot.Anchored = false
			end
			local m = Instance.new("Model")
			egg.Parent = m
			Models.weldTo(m, torso)
			m.Parent = looks
		end
	end

	local trailId = equipped.trail
	if trailId == "" and petKind == "rainbow" then
		trailId = "trail_rainbow"
	end
	local colors, hearts = trailColors(trailId)
	if colors then
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailTop"
		a0.Position = Vector3.new(0, 0.8, 0.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailBottom"
		a1.Position = Vector3.new(0, -1.2, 0.4)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = colors
		trail.Lifetime = 0.7
		trail.LightEmission = 0.5
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Parent = looks
		if hearts then
			local p = Instance.new("ParticleEmitter")
			p.Color = ColorSequence.new(Color3.fromRGB(255, 110, 180))
			p.Rate = 12
			p.Lifetime = NumberRange.new(0.8)
			p.Speed = NumberRange.new(1, 2)
			p.Size = NumberSequence.new(0.5, 0)
			p.Parent = a1
		end
	end
	looks.Parent = character
end

-- ---------- питомцы ----------

function Looks.setPet(player: Player, kind: string?)
	local old = pets[player]
	if old then
		old.model:Destroy()
		pets[player] = nil
	end
	if not kind or not Config.PETS[kind] then
		return
	end
	local c = PET_COLORS[kind]
	local def = Config.PETS[kind]
	local model, colorParts, height = Models.dino(c[1], c[2], PET_SCALE, {
		name = player.Name .. "_pet",
		label = def.name,
		labelColor = Config.RARITY_COLORS[def.rarity],
		trail = kind == "rainbow",
	})
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	if kind == "gold" then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 230, 120)
		sp.Parent = model.PrimaryPart
	end
	model.Parent = petFolder
	pets[player] = { model = model, colorParts = colorParts, height = height, kind = kind, pos = nil, face = Vector3.new(0, 0, -1) }
end

function Looks.removePlayer(player: Player)
	Looks.setPet(player, nil)
end

function Looks.updatePets(dt: number, now: number)
	for player, pet in pairs(pets) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hip = hum and (hum.HipHeight + root.Size.Y / 2) or 3
			local feet = root.Position.Y - hip
			local target = (root.CFrame * CFrame.new(3, 0, 3)).Position
			target = Vector3.new(target.X, feet, target.Z)
			if not pet.pos or (pet.pos - target).Magnitude > 40 then
				pet.pos = target
			end
			local delta = target - pet.pos
			pet.pos += delta * math.min(1, dt * 6)
			local flatDelta = Vector3.new(delta.X, 0, delta.Z)
			local moving = flatDelta.Magnitude > 0.5
			if moving then
				pet.face = flatDelta.Unit
			end
			local hop = moving and math.abs(math.sin(now * 12)) * 0.8 or 0
			local body = pet.pos + Vector3.new(0, pet.height + hop, 0)
			Models.moveRig(pet.model, CFrame.lookAt(body, body + pet.face))
			if pet.kind == "rainbow" then
				local col = Color3.fromHSV((now * 0.3) % 1, 0.8, 1)
				for _, p in ipairs(pet.colorParts) do
					p.Color = col
				end
			end
		end
	end
end

-- ---------- игрок-динозавр ----------

function Looks.morphDino(character: Model, kind: string)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local old = character:FindFirstChild("DinoLooks")
	if old then
		old:Destroy()
	end
	local def = Config.DINOS[kind]
	local model, _, height = Models.dino(def.color, def.dark, 0.75, { name = "DinoMorph", trail = kind == "rainbow" })
	local feet = root.Position.Y - (hum.HipHeight + root.Size.Y / 2)
	local look = root.CFrame.LookVector
	local body = Vector3.new(root.Position.X, feet + height, root.Position.Z)
	model:PivotTo(CFrame.lookAt(body, body + Vector3.new(look.X, 0, look.Z)))
	Models.attachRig(model, root)
	model.Parent = character
end

-- ---------- показать язык ----------

function Looks.tongue(character: Model)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head or head:FindFirstChild("Tongue") then
		return
	end
	local t = Models.part(nil, Vector3.new(0.5, 0.15, 0.8), head.CFrame * CFrame.new(0, -0.35, -head.Size.Z / 2 - 0.3), Color3.fromRGB(240, 90, 110))
	t.Name = "Tongue"
	t.Anchored = false
	t.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = head, t, t
	t.Parent = head
	local label = Models.label(head, "😛", 3, Color3.new(1, 1, 1), 80)
	task.delay(2.5, function()
		t:Destroy()
		if label.Parent then
			(label.Parent :: Instance):Destroy()
		end
	end)
end

return Looks
