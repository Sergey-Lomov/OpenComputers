Status = {
    SUCCESS = 0,
    WARNING = 1,
    PROBLEM = 2,
    PING = 3,
    CANCEL = 4,
    CANCEL_PING = 5
}

statusPort = 4361
pingId = "manually_enetered_id"
pingTitle = "ping_title"

modem = component.proxy(component.list("modem")())
if modem == nil then computer.beep(900, 1) return end
modem.setStrength(100)

function sendStatus(status, id, message)
	local data = string.format('{id="%s",message="%s"}', id, message)
	modem.broadcast(statusPort, status, data)
end

modem.broadcast(statusPort, Status.CANCEL, id)

lastPing = 0
function sendPing()
	if computer.uptime() - lastPing < 15  then return end
	local data = string.format('{id="%s",title="%s"}', pingId, pingTitle)
	modem.broadcast(statusPort, Status.PING, data)
	lastPing = computer.uptime()
end

if math.modf(computer.uptime() / 2) == 1 then
	sendStatus(Status.PROBLEM, "micro_problem", "Micro-problem")
else
	modem.broadcast(statusPort, Status.CANCEL, "micro_problem")
end

while true do
	computer.pullSignal(0.5)
	sendPing()
end