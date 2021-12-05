--Version 1.0

local statusSystemPort = 4361
local sentByCollectorMark = "sent_by_status_collector"
local systemArgsCount = 5

local wan = nil
local lan = nil

for address, _ in component.list("modem") do
	local proxy = component.proxy(address)
	if proxy.isWireless() then
		wan = proxy
	else
		lan = proxy
	end
end

wan.open(statusSystemPort)

while true do
	local args = {computer.pullSignal()}

	local name = args[1]
	if name ~= "modem_message" then goto continue end

	local lastArg = args[#args]
	if lastArg == sentByCollectorMark then goto continue end

	local payload = {}
	for i = systemArgsCount + 1, #args do
		table.insert(payload, args[i])
	end
	table.insert(payload, sentByCollectorMark)

	lan.broadcast(statusSystemPort, table.unpack(payload))
	computer.beep(400, 0.2)

	::continue::
end