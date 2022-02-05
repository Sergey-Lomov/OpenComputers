local port = 2327
local dataId = "induction_recipes"
local modem = component.proxy(component.list("modem")())
if modem == nil then computer.beep(900, 1) return end

function requestData()
	modem.open(port)

	while true do
		modem.broadcast(port, dataId)
		local args = {computer.pullSignal(10)}
		if args[1] == "modem_message" and args[4] == port and args[5] == dataId then
			local data = args[#args]
			if data == nil or data == "" then 
				computer.beep(1200, 0.25)
				return
			end
			x,y = load(data)()
			-- Here should be buisnes logic
			computer.beep(300, 3)
			modem.close(port)
			return
		end
	end
end