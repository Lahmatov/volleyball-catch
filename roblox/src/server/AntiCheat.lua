-- Защита от читов. Сервер не верит игроку на слово:
--  * check: игрок не может двигаться быстрее, чем ему разрешено (телепорт, ускорение, побег из клетки);
--  * allow: не больше N запросов в секунду (спам кнопками из чит-скрипта).
local AntiCheat = {}

AntiCheat.WINDOW = 0.5 -- секунд: точку отсчёта обновляем не чаще, чтобы мелкие шаги не складывались в телепорт
AntiCheat.SLACK = 4 -- запас в шагах (studs) на рывки сети

-- anchor = { pos, t } — последняя честная точка. Вернёт false, если игрок ушёл слишком далеко.
function AntiCheat.check(anchor, pos: Vector3, now: number, maxSpeed: number, slack: number?): boolean
	if not anchor.pos or (anchor.graceUntil and now < anchor.graceUntil) then
		anchor.pos, anchor.t = pos, now
		return true
	end
	local d = Vector3.new(pos.X - anchor.pos.X, 0, pos.Z - anchor.pos.Z).Magnitude
	if d > maxSpeed * (now - anchor.t) + (slack or AntiCheat.SLACK) then
		anchor.t = now -- вернём игрока в anchor.pos и начнём отсчёт заново
		return false
	end
	if now - anchor.t >= AntiCheat.WINDOW then
		anchor.pos, anchor.t = pos, now
	end
	return true
end

-- сервер сам переносит игрока: секунду верим любой точке (пока новая позиция доходит до игрока и обратно)
function AntiCheat.trust(anchor, now: number)
	anchor.pos = nil
	anchor.graceUntil = now + 1
end

-- ведро с жетонами: perSecond жетонов в секунду, не больше burst сразу
function AntiCheat.allow(bucket, now: number, perSecond: number, burst: number): boolean
	local tokens = bucket.tokens or burst
	tokens = math.min(burst, tokens + (now - (bucket.t or now)) * perSecond)
	bucket.t = now
	if tokens < 1 then
		bucket.tokens = tokens
		return false
	end
	bucket.tokens = tokens - 1
	return true
end

return AntiCheat
