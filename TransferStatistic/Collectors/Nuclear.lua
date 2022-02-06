--local computer = require 'computer'
--local component = require 'component'

modem = component.proxy(component.list("modem")())
transposer = component.proxy(component.list("transposer")())

frequency = 15
timeGap = 15
handleableSlots = 9
inSide = 0
outSide = 1

statsPort = 5784
registrationCode = 0
statsCode = 1
statsId = "nuclear"
statsTitle = "Реакторная"
pointInterval = 300

statusPort = 4361
pingId = "nuclear_stats_id"
pingTitle = "Реакторная"
pingCode = 3

lastUpdate = 0
function start()
	registerStatProvider()

	while true do
		computer.pullSignal(0.5)
		sendPing()
		if computer.uptime() - lastUpdate < frequency then goto continue end
		transferItems()
		lastUpdate = computer.uptime()

		::continue::
	end
end

function registerStatProvider()
	local maxDelay = math.max(frequency + timeGap, handleableSlots)
	local meta = string.format("{id = \"%s\",  title = \"%s\", maxDelay = %d, pointInterval = %d}", statsId, statsTitle, maxDelay, pointInterval)
	modem.broadcast(statsPort, registrationCode, meta)
end

function transferItems()
	local stats = {}
	for i = 1, handleableSlots do
		local stack = transposer.getStackInSlot(inSide, i)
		if stack == nil then goto continue end
		
		::transfer::
		local result = transposer.transferItem(inSide, outSide, stack.size, i)
		if not result then 
			goto transfer 
		else
			local current = stats[stack.label] or 0
			stats[stack.label] = current + stack.size
		end

		::continue::
	end

	sendStats(stats)
end

function sendStats(stats)
	local serialized = string.format("{id=\"%s\", items={", statsId)
	for label, amount in pairs(stats) do
		local node = string.format("[\"%s\"]=%d,", label, amount)
		serialized = serialized .. node
	end
	serialized = serialized .. "}}"

	modem.broadcast(statsPort, statsCode, serialized)
end

lastPing = 0
function sendPing()
	if computer.uptime() - lastPing < 15  then return end
	local data = string.format('{id="%s",title="%s"}', pingId, pingTitle)
	modem.broadcast(statusPort, pingCode, data)
	lastPing = computer.uptime()
end

start()