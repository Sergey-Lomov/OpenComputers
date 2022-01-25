local port = 2327
local dataId = "induction_recipes"
local modem = component.proxy(component.list("modem")())
function requestData()
	if modem == nil then computer.beep(900, 3) return end
	modem.open(port)

	while true do
		modem.broadcast(port, dataId)
		local args = {computer.pullSignal(10)}
		print("Pulled signal")
		print(tostring(args[1]) .. " " .. tostring(args[2]) .. " " .. tostring(args[3]) .. " " .. tostring(args[4]) .. " " .. tostring(args[5]))

		if args[1] == "modem_message" and args[4] == port and args[5] == dataId then
			local data = args[#args]
			if data == nil or data == "" then 
				computer.beep(1200, 3)
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