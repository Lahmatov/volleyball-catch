--[[
	Dino Egg Catch — главный скрипт.

	Люди забегают в круг, хватают яйцо и убегают. Динозавры ловят.
	В круге может быть только один человек. Кто набрал больше — получает кубок.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoShared"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Data = require(script.Parent.Data)
local Models = require(script.Parent.Models)
local Arena = require(script.Parent.Arena)
local Looks = require(script.Parent.Looks)
local Progress = require(script.Parent.Progress)
local Lobby = require(script.Parent.Lobby)
local Graphics = require(script.Parent.Graphics)
local AntiCheat = require(script.Parent.AntiCheat)

local R, ZONE, G = Config.CIRCLE_RADIUS, Config.ZONE_RADIUS, Config.GROUND_Y
local FX, FZ = Config.FIELD_X, Config.FIELD_Z

local event = Config.currentEvent()
Progress.event = event
Net.set("Event", event)

local worldFolder = Instance.new("Folder")
worldFolder.Name = "DinoWorld"
worldFolder.Parent = workspace
Graphics.setup()
Graphics.buildWorld(worldFolder)
Graphics.applyTheme(Config.THEMES[1].id, event)

local setScale: (Player, number) -> ()
local lobby = Lobby.build()
local fxFolder = Instance.new("Folder")
fxFolder.Name = "DinoFX"
fxFolder.Parent = workspace
local arena = Arena.buildRound(Config.THEMES[1].id, event)
Net.set("Map", Config.THEMES[1].icon .. " " .. Config.THEMES[1].name)
Net.set("Theme", Config.THEMES[1].id)

local roundNo = 0
local roundActive = false
local roundEnd = 0
local humansScore, dinoScore = 0, 0
local status = "Ждём игроков"
local dinoPlayer: Player? = nil
local lastCaught: { [Player]: number } = {}
local boss: any = nil
local bossDone = false
local powerups = {}
local nextPowerup = 0

-- ---------- состояние каждого игрока ----------

local function newState()
	return {
		carry = nil,
		cagedUntil = 0,
		cage = nil,
		starUntil = 0,
		bananaUntil = 0,
		springUntil = 0,
		slowUntil = 0,
		dashUntil = 0,
		roarAt = 0,
		dashAt = 0,
		shieldUsed = false,
		hidden = false,
		caught = 0,
		isDino = false,
		dinoKind = "red",
		obbyAt = -1000,
		lavaAt = 0,
		bushToastAt = 0,
		portalToastAt = 0,
		fartAt = 0,
		mushroomAt = 0,
		scaleUntil = 0,
		track = {}, -- последняя честная точка (защита от телепорта)
		peakSpeed = Config.WALK_SPEED,
		peakUntil = 0,
		bucket = {}, -- сколько запросов можно прямо сейчас
		cheatToastAt = 0,
	}
end

local states: { [Player]: any } = {}
local function st(player: Player)
	local s = states[player]
	if not s then
		s = newState()
		states[player] = s
	end
	return s
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
local function flatDist(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
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

local function onField(pos: Vector3): boolean
	return math.abs(pos.X) < FX / 2 and math.abs(pos.Z) < FZ / 2 and pos.Y < G + 15
end

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	if char then
		local s = states[player]
		if s then
			AntiCheat.trust(s.track, os.clock())
		end
		char:PivotTo(cf)
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function moveOut(root: BasePart, from: Vector3, radius: number)
	local dir = flat(root.Position - from)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = dir.Unit
	local x = math.clamp(from.X + dir.X * radius, -FX / 2 + 4, FX / 2 - 4)
	local z = math.clamp(from.Z + dir.Z * radius, -FZ / 2 + 4, FZ / 2 - 4)
	local player = Players:GetPlayerFromCharacter(root.Parent)
	if player and states[player] then
		AntiCheat.trust(states[player].track, os.clock())
	end
	root.CFrame = CFrame.new(x, root.Position.Y, z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

-- игрок сейчас на поле (а не в Динопарке или на обби)?
local function playing(player: Player): boolean
	local root = getRoot(player)
	return root ~= nil and onField(root.Position)
end

local function updateScore()
	Net.set("Humans", humansScore)
	Net.set("Dinos", dinoScore)
end

-- ---------- внешний вид ----------

local function applyLooks(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local pet = Progress.petKind(player)
	local char = player.Character
	if char and not st(player).isDino then
		Looks.applyCosmetics(char, profile.equipped, pet)
	end
	Looks.setPet(player, pet)
end
Progress.onLooksChanged = applyLooks

-- ---------- яйца ----------

local function dropEgg(player: Player)
	local s = states[player]
	if not s or not s.carry then
		return
	end
	local carry = s.carry
	carry.egg.taken = false
	Models.setVisible(carry.egg.part, true)
	carry.visual:Destroy()
	s.carry = nil
end

local function grabEgg(player: Player, root: BasePart, circle, egg)
	egg.taken = "carried"
	local m = Instance.new("Model")
	m.Name = "CarriedEgg"
	local visual = egg.part:Clone()
	visual.Parent = m
	m.PrimaryPart = visual
	Models.setVisible(egg.part, false)
	m:PivotTo(root.CFrame * CFrame.new(1.6, 0.4, -1))
	Models.weldTo(m, root)
	m.Parent = player.Character
	st(player).carry = { circle = circle, egg = egg, visual = m, closest = math.huge }
	Net.sound(player, "pickup")
	Net.toast(player, "🥚 Есть яйцо! Беги за белые точки!")
end

local EGG_COINS = { normal = 5, gold = 10, rainbow = 25 }

local function bankEgg(player: Player)
	local s = st(player)
	local carry = s.carry
	local egg = carry.egg
	egg.taken = "gone"
	egg.respawnAt = os.clock() + Config.EGG_RESPAWN
	carry.visual:Destroy()
	s.carry = nil

	humansScore += 1
	updateScore()
	local stats = player:FindFirstChild("leaderstats")
	local eggsStat = stats and stats:FindFirstChild("Яйца") :: IntValue?
	if eggsStat then
		eggsStat.Value += 1
	end

	local profile = Data.get(player)
	Progress.addEgg(player, egg.kind)
	local coins = Progress.addCoins(player, EGG_COINS[egg.kind] or 5, true)
	Net.sound(player, "coin")
	Net.toast(player, string.format("%s Яйцо твоё! +%d 🪙  (вылупи его в гнезде 🐣)", Config.EGGS[egg.kind].icon, coins))
	Progress.badge(player, "first_egg")
	if profile then
		profile.escapes += 1
		if profile.escapes >= 10 then
			Progress.badge(player, "escape10")
		end
	end
	if egg.kind == "rainbow" then
		Progress.badge(player, "rainbow_egg")
		Net.all("toast", "🌈 " .. player.DisplayName .. " унёс радужное яйцо!")
	end
	if carry.closest < 8 then
		local bonus = Progress.addCoins(player, 5, true)
		Net.toast(player, "😅 Еле убежал! +" .. bonus .. " 🪙")
		Progress.badge(player, "close_call")
	end
end

-- ---------- поймали / клетка / спасение ----------

local function releaseCage(player: Player)
	local s = states[player]
	if not s then
		return
	end
	s.cagedUntil = 0
	if s.cage then
		s.cage:Destroy()
		s.cage = nil
	end
end

-- from: откуда пришёл динозавр; outRadius — если задан, человека выкидывает из круга
local function catchPlayer(prey: Player, root: BasePart, from: Vector3, outRadius: number?, catcherName: string, catcher: Player?): boolean
	local s = st(prey)
	local now = os.clock()
	if s.starUntil > now or s.cagedUntil > now then
		return false
	end
	if Progress.petKind(prey) == "red" and not s.shieldUsed then
		s.shieldUsed = true
		moveOut(root, from, (outRadius or 10) + 4)
		Net.toast(prey, "🛡 Красный динозаврик тебя спас! (один раз за тайм)")
		Net.sound(prey, "swoosh")
		return false
	end

	dropEgg(prey)
	dinoScore += 1
	updateScore()
	s.caught += 1
	if outRadius then
		moveOut(root, from, outRadius)
	end
	s.cagedUntil = now + Config.CAGE_TIME
	s.cage = Models.cage(Vector3.new(root.Position.X, G, root.Position.Z), arena.folder)
	local head = prey.Character and prey.Character:FindFirstChild("Head") :: BasePart?
	if head then
		local stars = Models.label(head, "😵‍💫 ⭐ ⭐", 3, Color3.new(1, 1, 1), 80)
		local bb = stars.Parent :: BillboardGui
		bb.Parent = s.cage
		task.spawn(function()
			local t = 0
			while bb.Parent do
				t += 0.1
				bb.StudsOffset = Vector3.new(math.sin(t * 6) * 0.8, 3, math.cos(t * 6) * 0.8)
				task.wait(0.1)
			end
		end)
	end
	for _, c in ipairs(arena.circles) do
		if c.occupant == prey then
			c.occupant = nil
		end
	end

	Net.sound(prey, "caught")
	Net.send(prey, "voice", "Ой! Поймали!")
	Net.toast(prey, "😵‍💫 Ой! Голова кружится! Друг может спасти, или подожди " .. Config.CAGE_TIME .. " секунд")
	Net.all("toast", catcherName .. " поймал " .. prey.DisplayName .. "! +1 динозаврам")
	if catcher then
		local coins = Progress.addCoins(catcher, 5, true)
		Net.toast(catcher, "🦖 Поймал! +" .. coins .. " 🪙")
	end
	return true
end

-- может ли динозавр ловить этого игрока прямо сейчас
local function isPrey(player: Player, now: number, roots): boolean
	local s = states[player]
	local root = roots[player]
	return s ~= nil
		and root ~= nil
		and not s.isDino
		and s.cagedUntil <= now
		and s.starUntil <= now
		and not s.hidden
		and onField(root.Position)
end

-- ---------- скорость и прыжок ----------

local function applyMovement(player: Player, s, hum: Humanoid, now: number)
	local speed
	if s.cagedUntil > now then
		speed = 0
	elseif s.slowUntil > now then
		speed = 6
	else
		speed = s.isDino and 17 or Config.WALK_SPEED
		if not s.isDino then
			local pet = Progress.petKind(player)
			if pet == "green" then
				speed += 2
			elseif pet == "rainbow" then
				speed += 3
			end
		end
		if s.bananaUntil > now then
			speed += 10
		end
		if s.dashUntil > now then
			speed += 26
		end
		if s.carry then
			speed -= 1
		end
	end
	-- самая большая скорость за последнюю секунду: по ней сервер проверяет, не читер ли
	if speed >= s.peakSpeed then
		s.peakSpeed, s.peakUntil = speed, now + 1
	elseif now > s.peakUntil then
		s.peakSpeed = speed
	end
	if hum.WalkSpeed ~= speed then
		hum.WalkSpeed = speed
	end
	local jump = 7.2
	if s.cagedUntil > now then
		jump = 0
	elseif s.springUntil > now then
		jump = 22
	end
	if hum.JumpHeight ~= jump then
		hum.JumpHeight = jump
		hum.JumpPower = jump == 0 and 0 or (jump > 10 and 95 or 50)
	end
end

-- ---------- круг ломается ----------

local function crackCircle(c, player: Player)
	if not c.cracked then
		Net.toast(player, "💥 Круг сломан! Там уже есть человек")
		Net.sound(player, "crack")
	end
	c.crackUntil = os.clock() + 1
	c.cracked = true
	for i, seg in ipairs(c.ring) do
		seg.Color = Color3.fromRGB(216, 69, 47)
		seg.Transparency = (i % 2 == 0) and 1 or 0
	end
end

-- ---------- бонусы ----------

local POWER_KINDS = { "banana", "star", "spring" }

local function clearPowerups()
	for _, p in ipairs(powerups) do
		p.model:Destroy()
	end
	table.clear(powerups)
end

local function takePowerup(player: Player, s, p, now: number)
	local def = Config.POWERUPS[p.kind]
	if p.kind == "banana" then
		s.bananaUntil = now + def.time
	elseif p.kind == "star" then
		s.starUntil = now + def.time
		local char = player.Character
		if char then
			local ff = Instance.new("ForceField")
			ff.Parent = char
			task.delay(def.time, function()
				ff:Destroy()
			end)
		end
	elseif p.kind == "spring" then
		s.springUntil = now + def.time
	end
	Progress.addCoins(player, 1, true)
	Net.sound(player, p.kind == "spring" and "jump" or "pickup")
	Net.toast(player, def.icon .. " " .. def.text)
end

-- ---------- Ти-Рекс ----------

local function spawnBoss(now: number)
	local model, bossParts, height = Models.dino(Color3.fromRGB(120, 95, 70), Color3.fromRGB(70, 50, 35), 2.4, {
		name = "Ти-Рекс",
		label = "ТИ-РЕКС",
		labelColor = Color3.fromRGB(255, 90, 60),
		hat = (event == "halloween" and "hat_pumpkin") or (event == "newyear" and "hat_santa") or nil,
	})
	local pos = Vector3.new(0, G, -FZ / 2 + 12)
	model:PivotTo(CFrame.new(pos + Vector3.new(0, height, 0)))
	model:SetAttribute("Chasing", true)
	model.Parent = arena.folder
	boss = {
		model = model,
		height = height,
		pos = pos,
		face = Vector3.new(0, 0, 1),
		untilT = now + Config.BOSS_TIME,
		caughtAny = false,
		bubble = Models.bubble(bossParts[2], 9),
		nextChat = now + 1,
	}
	Net.big("🦖 ТИ-РЕКС! БЕГИ!", 3, "Ти-Рекс! Беги!")
	Net.all("shake", 1)
	Net.sound(nil, "roar")
	Net.set("Boss", true)
end

local function removeBoss(rewarded: boolean)
	if not boss then
		return
	end
	boss.model:Destroy()
	if rewarded and not boss.caughtAny then
		for _, player in ipairs(Players:GetPlayers()) do
			local s = states[player]
			if s and not s.isDino and playing(player) then
				Progress.addCoins(player, 10, true)
				Progress.badge(player, "boss")
			end
		end
		Net.big("Все убежали от Ти-Рекса! +10 🪙", 3)
	end
	boss = nil
	Net.set("Boss", false)
end

-- ---------- каждый кадр ----------

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()

	-- анимации: радужные динозавры и яйца, сломанные круги, яйца возвращаются
	local hue = Color3.fromHSV((now * 0.25) % 1, 0.8, 1)
	for _, c in ipairs(arena.circles) do
		if c.kind == "rainbow" then
			for _, p in ipairs(c.colorParts) do
				p.Color = hue
			end
		end
		if c.cracked and now > c.crackUntil then
			c.cracked = false
			for _, seg in ipairs(c.ring) do
				seg.Color = c.ringColor
				seg.Transparency = 0
			end
		end
		for _, egg in ipairs(c.eggs) do
			if egg.taken == "gone" and now >= egg.respawnAt then
				if math.random() < 0.04 then
					Arena.remakeEgg(egg, "rainbow", event, arena.folder)
				elseif egg.kind ~= egg.baseKind then
					Arena.remakeEgg(egg, egg.baseKind, event, arena.folder)
				else
					Models.setVisible(egg.part, true)
				end
				egg.taken = false
			end
			if egg.kind == "rainbow" and not egg.taken then
				egg.part.Color = hue
			end
		end
	end
	for _, p in ipairs(powerups) do
		p.model:PivotTo(CFrame.new(p.pos + Vector3.new(0, math.sin(now * 3) * 0.4, 0)) * CFrame.Angles(0, now * 2, 0))
	end
	Looks.updatePets(dt, now)

	-- игроки: лобби, обби, лава, кусты, скорость
	local roots: { [Player]: BasePart } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local s = states[player]
		local root, hum = getRoot(player)
		if s and root and hum then
			roots[player] = root
			local pos = root.Position

			-- телепорт, ускорение или побег из клетки: возвращаем на последнюю честную точку
			local caged = s.cagedUntil > now
			local park = Lobby.contains(pos) or pos.X < -FX / 2 - 10 -- горка и батуты разгоняют сильнее
			local limit = caged and 0 or (park and 70 or s.peakSpeed * 1.25)
			if not AntiCheat.check(s.track, pos, now, limit, caged and 1.5 or nil) then
				dropEgg(player)
				root.CFrame = CFrame.new(s.track.pos) * root.CFrame.Rotation
				root.AssemblyLinearVelocity = Vector3.zero
				pos = s.track.pos
				if now - s.cheatToastAt > 5 then
					s.cheatToastAt = now
					Net.toast(player, "🚫 Так быстро нельзя! Возвращаем назад")
				end
			end

			if pos.Y < -40 then
				dropEgg(player) -- иначе телепорт в центр поля засчитал бы яйцо как унесённое
				teleport(player, (roundActive and not Lobby.contains(pos)) and lobby.fieldCFrame or lobby.spawnCFrame)
			elseif pos.X < -FX / 2 - 10 and pos.Y < -3 then
				teleport(player, lobby.obbyStart) -- упал в воду на обби
			end
			if flatDist(pos, lobby.padPos) < 3 and pos.Y < G + 6 and s.cagedUntil <= now then
				dropEgg(player)
				teleport(player, lobby.obbyStart)
				Net.toast(player, "🏃 Прыгай по островкам до финиша!")
			end
			if flatDist(pos, lobby.finishPos) < 6 and math.abs(pos.Y - lobby.finishPos.Y) < 6 then
				if now - s.obbyAt > 120 then
					s.obbyAt = now
					local coins = Progress.addCoins(player, 15, true)
					Net.toast(player, "🏁 Обби пройдено! +" .. coins .. " 🪙")
					Net.sound(player, "win")
					Progress.badge(player, "obby")
				else
					Net.toast(player, "🏁 Молодец! Монетки за обби — раз в 2 минуты")
				end
				teleport(player, lobby.spawnCFrame)
			end
			if flatDist(pos, lobby.gamePortalPos) < 4 and pos.Y < G + 6 then
				if roundActive then
					teleport(player, lobby.fieldCFrame * CFrame.new(math.random(-20, 20), 0, 0))
					Net.toast(player, "▶ Беги за яйцами!")
				elseif now - s.portalToastAt > 4 then
					s.portalToastAt = now
					Net.toast(player, "▶ Портал откроется, когда начнётся игра")
				end
			end
			for _, l in ipairs(arena.lava) do
				if flatDist(pos, l.pos) < l.radius and pos.Y < G + 5 and now - s.lavaAt > 1 then
					s.lavaAt = now
					dropEgg(player)
					teleport(player, lobby.fieldCFrame)
					Net.toast(player, "🔥 Ой, горячо! Обходи лаву")
					Net.sound(player, "caught")
				end
			end

			local hidden = false
			if pos.Y < G + 8 then
				for _, b in ipairs(arena.bushes) do
					if flatDist(pos, b) < 4.5 then
						hidden = true
						break
					end
				end
			end
			if hidden and not s.hidden and now - s.bushToastAt > 4 then
				s.bushToastAt = now
				Net.toast(player, "🌿 Ты спрятался в кусте! Динозавры тебя не видят")
			end
			s.hidden = hidden

			applyMovement(player, s, hum, now)
		end
	end

	if not roundActive then
		return
	end

	-- кто в каком круге (динозавр-игрок и пойманные не считаются)
	local inside = {}
	for player, root in pairs(roots) do
		local s = states[player]
		if not s.isDino and s.cagedUntil <= now then
			for _, c in ipairs(arena.circles) do
				if flatDist(root.Position, c.center) < R and root.Position.Y < G + 10 then
					inside[player] = c
					break
				end
			end
		end
	end
	for _, c in ipairs(arena.circles) do
		if c.occupant and inside[c.occupant] ~= c then
			c.occupant = nil
		end
	end
	for player, c in pairs(inside) do
		if c.occupant == nil then
			c.occupant = player
		elseif c.occupant ~= player then
			moveOut(roots[player], c.center, R + 4)
			crackCircle(c, player)
			inside[player] = nil
		end
	end

	-- взять яйцо, убежать с ним
	for player, root in pairs(roots) do
		local s = states[player]
		local c = inside[player]
		if c and not s.carry then
			for _, egg in ipairs(c.eggs) do
				if not egg.taken and flatDist(root.Position, egg.part.Position) < 3.5 then
					grabEgg(player, root, c, egg)
					break
				end
			end
		end
		if s.carry then
			local d = flatDist(root.Position, s.carry.circle.dinoPos)
			if d < s.carry.closest then
				s.carry.closest = d
			end
			if flatDist(root.Position, s.carry.circle.center) > ZONE + 2 then
				bankEgg(player)
			end
		end
	end

	-- спасение из клетки
	for player, s in pairs(states) do
		if s.cage then
			if now >= s.cagedUntil then
				releaseCage(player)
				Net.toast(player, "🔓 Ты свободен! Беги!")
			else
				local root = roots[player]
				for other, os2 in pairs(states) do
					local r2 = roots[other]
					if other ~= player and root and r2 and not os2.isDino and os2.cagedUntil <= now and flatDist(root.Position, r2.Position) < 5 then
						releaseCage(player)
						Net.toast(player, "🦸 " .. other.DisplayName .. " тебя спас!")
						local coins = Progress.addCoins(other, 5, true)
						Net.toast(other, "🦸 Ты спас " .. player.DisplayName .. "! +" .. coins .. " 🪙")
						Net.sound(other, "win")
						Progress.badge(other, "rescuer")
						break
					end
				end
			end
		end
	end

	-- динозавры в кругах
	for _, c in ipairs(arena.circles) do
		local prey: Player? = nil
		for player, s in pairs(states) do
			if s.carry and s.carry.circle == c and isPrey(player, now, roots) then
				prey = player
				break
			end
		end
		if not prey and c.occupant and isPrey(c.occupant, now, roots) then
			prey = c.occupant
		end

		local chasing = prey ~= nil
		if chasing and not c.chasing then
			Net.sound(prey, "roar")
			c.noticeUntil = now + Config.DINO_REACTION
			c.bubble.Text = "❗"
			c.chatUntil = now + Config.DINO_REACTION
		end
		c.chasing = chasing

		-- зелёный прячется в траве, пока никого не ловит
		if c.kind == "green" and c.camo ~= not chasing then
			c.camo = not chasing
			for _, p in ipairs(c.allParts) do
				p.Transparency = c.camo and 0.6 or 0
			end
		end

		local target = prey and Vector3.new(roots[prey].Position.X, G, roots[prey].Position.Z) or c.center
		local delta = flat(target - c.dinoPos)
		local speed = c.def.speed * (chasing and 1 or 0.6)
		-- красный делает рывок
		if c.kind == "red" and chasing and now >= c.nextDash and delta.Magnitude < 18 then
			c.dashUntil = now + 0.5
			c.nextDash = now + 4
		end
		if c.dashUntil > now then
			speed *= 2.2
		end
		if (c.noticeUntil or 0) > now then
			speed = 0 -- ещё удивляется
		end
		local moving = delta.Magnitude > 0.2
		if moving then
			c.dinoPos += delta.Unit * math.min(delta.Magnitude, speed * dt)
			c.dinoFace = delta.Unit
		end
		local fromHome = flat(c.dinoPos - c.center)
		if fromHome.Magnitude > ZONE then
			c.dinoPos = c.center + fromHome.Unit * ZONE
		end
		local bob = moving and math.abs(math.sin(now * 12)) * 0.5 or 0
		local body = c.dinoPos + Vector3.new(0, c.height + bob, 0)
		Models.moveRig(c.dino, CFrame.lookAt(body, body + c.dinoFace))
		if c.dino:GetAttribute("Chasing") ~= chasing then
			c.dino:SetAttribute("Chasing", chasing)
		end

		-- динозавры болтают
		if now >= c.nextChat then
			c.nextChat = now + math.random(6, 14)
			local list = chasing and Config.DINO_PHRASES.chase or Config.DINO_PHRASES.idle
			c.bubble.Text = list[math.random(#list)]
			c.chatUntil = now + 2.5
		elseif c.chatUntil > 0 and now > c.chatUntil then
			c.bubble.Text = ""
			c.chatUntil = 0
		end

		if prey and flatDist(roots[prey].Position, c.dinoPos) < Config.CATCH_DISTANCE then
			if catchPlayer(prey, roots[prey], c.center, ZONE + 6, c.def.name .. " динозавр", nil) then
				local list = Config.DINO_PHRASES.catch
				c.bubble.Text = list[math.random(#list)]
				c.chatUntil = now + 2.5
			end
		end
	end

	-- игрок-динозавр
	if dinoPlayer and roots[dinoPlayer] then
		local dpos = roots[dinoPlayer].Position
		for player, root in pairs(roots) do
			if player ~= dinoPlayer and isPrey(player, now, roots) and flatDist(root.Position, dpos) < Config.CATCH_DISTANCE + 1 then
				catchPlayer(player, root, dpos, nil, "🦖 " .. dinoPlayer.DisplayName, dinoPlayer)
			end
			if states[player].carry and player ~= dinoPlayer then
				local d = flatDist(root.Position, dpos)
				if d < states[player].carry.closest then
					states[player].carry.closest = d
				end
			end
		end
	end

	-- Ти-Рекс
	if not bossDone and roundEnd - now <= Config.BOSS_AT then
		bossDone = true
		spawnBoss(now)
	end
	if boss then
		if now >= boss.untilT then
			removeBoss(true)
		else
			local best, bestD = nil, math.huge
			for player, root in pairs(roots) do
				if isPrey(player, now, roots) then
					local d = flatDist(root.Position, boss.pos)
					if d < bestD then
						best, bestD = player, d
					end
				end
			end
			local target = best and Vector3.new(roots[best].Position.X, G, roots[best].Position.Z) or Vector3.new(0, G, -FZ / 2 + 12)
			local delta = flat(target - boss.pos)
			local moving = delta.Magnitude > 0.5
			if moving then
				boss.pos += delta.Unit * math.min(delta.Magnitude, 12.5 * dt)
				boss.face = delta.Unit
			end
			local body = boss.pos + Vector3.new(0, boss.height + (moving and math.abs(math.sin(now * 6)) or 0), 0)
			Models.moveRig(boss.model, CFrame.lookAt(body, body + boss.face))
			if now >= boss.nextChat then
				boss.nextChat = now + 4
				local list = Config.DINO_PHRASES.boss
				boss.bubble.Text = list[math.random(#list)]
			end
			if best and bestD < 8 then
				if catchPlayer(best, roots[best], boss.pos, nil, "🦖 Ти-Рекс", nil) then
					boss.caughtAny = true
				end
			end
		end
	end

	-- бонусы: появляются и подбираются
	if now >= nextPowerup and #powerups < 4 then
		nextPowerup = now + 6
		local kind = POWER_KINDS[math.random(#POWER_KINDS)]
		local pos = Arena.freePos(2) + Vector3.new(0, 2, 0)
		table.insert(powerups, { kind = kind, pos = pos, model = Models.powerup(kind, pos, arena.folder) })
	end
	for i = #powerups, 1, -1 do
		local p = powerups[i]
		for player, root in pairs(roots) do
			local s = states[player]
			if not s.isDino and s.cagedUntil <= now and flatDist(root.Position, p.pos) < 4 and math.abs(root.Position.Y - p.pos.Y) < 6 then
				takePowerup(player, s, p, now)
				p.model:Destroy()
				table.remove(powerups, i)
				break
			end
		end
	end
end)

-- ---------- игроки заходят и выходят ----------

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	char:WaitForChild("HumanoidRootPart")
	char:WaitForChild("Head")
	hum.Died:Connect(function()
		dropEgg(player)
		releaseCage(player)
	end)
	local s = st(player)
	AntiCheat.trust(s.track, os.clock())
	if s.isDino then
		Looks.morphDino(char, s.dinoKind)
	else
		applyLooks(player)
	end
end

local function onPlayerAdded(player: Player)
	if #Players:GetPlayers() > Config.MAX_PLAYERS then
		player:Kick("Игра полная: играть можно только 5 человек")
		return
	end
	states[player] = newState()
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Яйца", "Монетки", "Кубки" }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	Data.load(player)
	if not player.Parent then
		return
	end
	Progress.sync(player)
	applyLooks(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	dropEgg(player)
	releaseCage(player)
	Looks.removePlayer(player)
	for _, c in ipairs(arena.circles) do
		if c.occupant == player then
			c.occupant = nil
		end
	end
	if dinoPlayer == player then
		dinoPlayer = nil
	end
	states[player] = nil
	lastCaught[player] = nil
end)

lobby.nestPrompt.Triggered:Connect(function(player)
	Net.send(player, "panel", "pets")
end)

-- ---------- смешное в Динопарке ----------

local SCALES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
setScale = function(player: Player, factor: number)
	local _, hum = getRoot(player)
	if not hum then
		return
	end
	for _, name in ipairs(SCALES) do
		local v = hum:FindFirstChild(name) :: NumberValue?
		if v then
			v.Value = factor
		end
	end
	task.delay(0.2, applyLooks, player)
end

local statueToken = 0
lobby.statuePrompt.Triggered:Connect(function(player)
	statueToken += 1
	local my = statueToken
	local list = Config.DINO_PHRASES.statue
	local phrase = list[math.random(#list)]
	local st0 = lobby.statue
	st0.bubble.Text = phrase
	local snd = Instance.new("Sound")
	local which = phrase:find("Пук") and Config.SOUNDS.fart or Config.SOUNDS.boing
	snd.SoundId = which.id
	snd.PlaybackSpeed = which.speed
	snd.Volume = 1
	snd.Parent = st0.model.PrimaryPart
	snd:Play()
	task.delay(3, function()
		snd:Destroy()
	end)
	task.spawn(function()
		local base = st0.pos + Vector3.new(0, st0.height, 0)
		local look = CFrame.lookAt(base, base + Vector3.new(0.4, 0, 1)).Rotation
		for i = 1, 10 do
			local y = math.sin(i / 10 * math.pi) * 3
			Models.moveRig(st0.model, CFrame.new(base + Vector3.new(0, y, 0)) * look)
			task.wait(0.04)
		end
		Models.moveRig(st0.model, CFrame.new(base) * look)
	end)
	task.delay(3, function()
		if my == statueToken then
			st0.bubble.Text = ""
		end
	end)
end)

-- ---------- кнопки с экрана ----------

Net.Request.OnServerInvoke = function(player: Player, action: any, arg: any)
	local s = states[player]
	if not s then
		-- игрок ещё не добавлен или уже ушёл: не создаём ему состояние заново
		return { ok = false }
	end
	local now = os.clock()
	if not AntiCheat.allow(s.bucket, now, 8, 15) then
		return { ok = false, busy = true } -- чит-скрипт жмёт кнопки сотни раз в секунду
	end
	if action == "roar" then
		if not (s.isDino and roundActive) then
			return { ok = false }
		end
		if now < s.roarAt then
			return { ok = false, wait = s.roarAt - now }
		end
		s.roarAt = now + 8
		local root = getRoot(player)
		if root then
			for other, os2 in pairs(states) do
				local r2 = getRoot(other)
				if other ~= player and r2 and flatDist(r2.Position, root.Position) < 25 then
					os2.slowUntil = now + 2
					Net.toast(other, "🦖 РРРР! Динозавр рычит, ты замедлился!")
					Net.send(other, "shake", 0.5)
				end
			end
		end
		Net.sound(nil, "roar")
		return { ok = true, cooldown = 8 }
	elseif action == "dash" then
		if not (s.isDino and roundActive) then
			return { ok = false }
		end
		if now < s.dashAt then
			return { ok = false, wait = s.dashAt - now }
		end
		s.dashAt = now + 5
		s.dashUntil = now + 0.6
		Net.sound(player, "swoosh")
		return { ok = true, cooldown = 5 }
	elseif action == "fart" then
		local root = getRoot(player)
		if root and now - s.fartAt > 2 then
			s.fartAt = now
			local cloud = Models.part(fxFolder, Vector3.new(1, 1, 1), CFrame.new(root.Position - Vector3.new(0, 1.5, 0)), Color3.new(1, 1, 1))
			cloud.Transparency = 1
			local puff = Instance.new("ParticleEmitter")
			puff.Color = ColorSequence.new(Color3.fromRGB(170, 210, 60), Color3.fromRGB(120, 160, 40))
			puff.Size = NumberSequence.new(1.5, 5)
			puff.Transparency = NumberSequence.new(0.2, 1)
			puff.Lifetime = NumberRange.new(1.2, 1.8)
			puff.Speed = NumberRange.new(2, 5)
			puff.SpreadAngle = Vector2.new(180, 180)
			puff.Rate = 80
			puff.Parent = cloud
			Models.label(cloud, "ПУК! 💨", 4, Color3.fromRGB(190, 240, 90), 80)
			local snd = Instance.new("Sound")
			snd.SoundId = Config.SOUNDS.fart.id
			snd.PlaybackSpeed = Config.SOUNDS.fart.speed
			snd.Volume = 1
			snd.RollOffMaxDistance = 80
			snd.Parent = cloud
			snd:Play()
			task.delay(0.4, function()
				puff.Enabled = false
			end)
			task.delay(2.5, function()
				cloud:Destroy()
			end)
			Net.toast(player, "💨 Хи-хи!")
			for _, other in ipairs(Players:GetPlayers()) do
				local r2 = getRoot(other)
				if other ~= player and r2 and flatDist(r2.Position, root.Position) < 25 then
					Net.toast(other, "Фу-у-у! " .. player.DisplayName .. " пукнул 😂")
				end
			end
		end
		return { ok = true }
	elseif action == "mushroom" then
		local root = getRoot(player)
		if not root or not Lobby.contains(root.Position) or now - s.mushroomAt < 4 or s.isDino then
			return { ok = false }
		end
		s.mushroomAt = now
		local factor = arg == "big" and 2.2 or 0.45
		setScale(player, factor)
		s.scaleUntil = now + 12
		Net.sound(player, "boing")
		Net.toast(player, arg == "big" and "🍄 Ты ВЕЛИКАН! Топ-топ!" or "🍄 Ты малыш-малышок! Пи-пи-пи!")
		task.delay(12, function()
			if states[player] == s and os.clock() >= s.scaleUntil - 0.05 then
				setScale(player, 1)
			end
		end)
		return { ok = true }
	elseif action == "tongue" then
		if player.Character and not s.isDino then
			Looks.tongue(player.Character)
		end
		return { ok = true }
	end
	return Progress.handle(player, action, arg)
end

-- ---------- табло ----------

task.spawn(function()
	while true do
		Net.set("Status", status)
		lobby.boardStatus.Text = roundActive and "Идёт игра! Прыгай в зелёный портал ▶" or (status ~= "" and status or "Скоро игра!")
		for _, tile in ipairs(lobby.disco) do
			tile.Color = Color3.fromHSV(math.random(), 0.65, 1)
		end
		Net.set("TimeLeft", roundActive and math.max(0, math.ceil(roundEnd - os.clock())) or -1)
		task.wait(0.2)
	end
end)

-- ---------- таймы ----------

local function pickDinoPlayer(list: { Player }): Player?
	if #list < 2 then
		return nil
	end
	local best, bestN = nil, 0
	for _, p in ipairs(list) do
		local n = lastCaught[p] or 0
		if n > bestN then
			best, bestN = p, n
		end
	end
	return best or list[math.random(#list)]
end

local function cleanupRound()
	roundActive = false
	for player in pairs(states) do
		dropEgg(player)
		releaseCage(player)
	end
	clearPowerups()
	removeBoss(false)
end

local function showTrophy(text: string, seconds: number)
	local cup = Models.trophy(lobby.folder, text)
	local start = os.clock()
	while os.clock() - start < seconds do
		cup:PivotTo(CFrame.new(0, 10, 0) * CFrame.Angles(0, (os.clock() - start) * 2, 0))
		task.wait()
	end
	cup:Destroy()
end

local function giveCup(player: Player)
	local profile = Data.get(player)
	if profile then
		profile.cups += 1
	end
	Progress.addCoins(player, 20, true)
	Progress.badge(player, "winner")
end

task.spawn(function()
	while true do
		status = "Ждём игроков"
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end

		roundNo += 1
		local theme = Config.THEMES[(roundNo - 1) % #Config.THEMES + 1]
		for i = Config.INTERMISSION, 1, -1 do
			status = "Скоро " .. theme.icon .. " " .. theme.name .. ": " .. i
			task.wait(1)
		end

		cleanupRound()
		Graphics.applyTheme(theme.id, event)
		arena = Arena.buildRound(theme.id, event)
		Net.set("Map", theme.icon .. " " .. theme.name)
		Net.set("Theme", theme.id)
		humansScore, dinoScore = 0, 0
		updateScore()
		bossDone = false
		nextPowerup = 0

		local list = Players:GetPlayers()
		dinoPlayer = pickDinoPlayer(list)
		table.clear(lastCaught)
		-- новый персонаж появляется не мгновенно: переносим на поле только после LoadCharacter
		local function spawnOnField(player: Player, slot: number)
			player:LoadCharacter()
			if player.Parent then
				teleport(player, lobby.fieldCFrame * CFrame.new(-24 + (slot - 1) * 12, 0, 0))
			end
		end
		for i, player in ipairs(list) do
			local old = states[player]
			local s = newState()
			if old then
				s.obbyAt = old.obbyAt
			end
			states[player] = s
			local stats = player:FindFirstChild("leaderstats")
			local eggs = stats and stats:FindFirstChild("Яйца") :: IntValue?
			if eggs then
				eggs.Value = 0
			end
			if player ~= dinoPlayer then
				task.spawn(spawnOnField, player, i)
			end
		end
		if dinoPlayer then
			local s = st(dinoPlayer)
			s.isDino = true
			s.dinoKind = Config.DINO_ORDER[math.random(#Config.DINO_ORDER)]
			task.spawn(spawnOnField, dinoPlayer, table.find(list, dinoPlayer) or 1) -- при появлении сразу станет динозавром
			Net.send(dinoPlayer, "role", { dino = true })
			Net.send(dinoPlayer, "big", { text = "🦖 Ты динозавр! Лови людей!", seconds = 4 })
			Net.send(dinoPlayer, "voice", "Ты динозавр! Лови людей!")
			Progress.badge(dinoPlayer, "was_dino")
			Net.all("toast", "🦖 " .. dinoPlayer.DisplayName .. " в этот раз динозавр!")
		end
		Net.set("DinoPlayer", dinoPlayer and dinoPlayer.DisplayName or "")
		task.wait(1)

		Net.big("Хватай яйца и убегай!", 3, "Хватай яйцо! Беги!")
		roundEnd = os.clock() + Config.ROUND_TIME
		roundActive = true
		status = ""
		while os.clock() < roundEnd and #Players:GetPlayers() > 0 do
			task.wait(0.25)
		end

		for player, s in pairs(states) do
			lastCaught[player] = s.caught
		end
		cleanupRound()

		local text
		if humansScore > dinoScore then
			text = "🏆 Кубок у людей!"
			for player, s in pairs(states) do
				if not s.isDino and playing(player) then
					giveCup(player)
				end
			end
		elseif dinoScore > humansScore then
			text = "🏆 Кубок у динозавров!"
			if dinoPlayer and dinoPlayer.Parent then
				giveCup(dinoPlayer)
			end
		else
			text = "🤝 Ничья!"
		end
		status = "Конец тайма"
		Net.big(string.format("%s  Люди %d : %d Динозавры", text, humansScore, dinoScore), 7, text:find("Ничья") and "Ничья!" or "Кубок!")
		Net.sound(nil, "win")
		for _, player in ipairs(Players:GetPlayers()) do
			Progress.sync(player)
		end

		showTrophy(text, 7)
		if dinoPlayer and dinoPlayer.Parent then
			local dp = dinoPlayer
			st(dp).isDino = false
			Net.send(dp, "role", { dino = false })
			task.spawn(dp.LoadCharacter, dp) -- появится в Динопарке
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= dinoPlayer then
				teleport(player, lobby.spawnCFrame * CFrame.new(math.random(-6, 6), 0, math.random(-4, 4)))
			end
		end
		dinoPlayer = nil
		Net.set("DinoPlayer", "")
		Net.big("🦖 Добро пожаловать в Динопарк!", 3)
	end
end)
