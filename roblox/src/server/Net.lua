-- Связь сервера с экраном игрока.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "DinoRemotes"

Net.Request = Instance.new("RemoteFunction")
Net.Request.Name = "Request"
Net.Request.Parent = folder

Net.Notify = Instance.new("RemoteEvent")
Net.Notify.Name = "Notify"
Net.Notify.Parent = folder

folder.Parent = ReplicatedStorage
Net.folder = folder

function Net.send(player: Player, kind: string, payload: any?)
	Net.Notify:FireClient(player, kind, payload)
end

function Net.all(kind: string, payload: any?)
	Net.Notify:FireAllClients(kind, payload)
end

-- маленькое сообщение внизу экрана
function Net.toast(player: Player, text: string)
	Net.send(player, "toast", text)
end

-- большая надпись посередине для всех
function Net.big(text: string, seconds: number?, voice: string?)
	Net.all("big", { text = text, seconds = seconds or 2.5 })
	if voice then
		Net.all("voice", voice)
	end
end

function Net.sound(player: Player?, name: string)
	if player then
		Net.send(player, "sound", name)
	else
		Net.all("sound", name)
	end
end

-- общие значения для табло: время, очки, карта
function Net.set(key: string, value: any)
	folder:SetAttribute(key, value)
end

return Net
