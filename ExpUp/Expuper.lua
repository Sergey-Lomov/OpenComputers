sides = require("sides")
robot = require("robot")
component = require("component")
computer = require("computer")

ic = component.inventory_controller

counter = 0
rechargeLimit = 3750
rechargeSide = sides.up
rechargeDuration = 60

startTime = computer.uptime()
startLevel = robot.level()

while true do
	robot.place()
	robot.swing()
	counter = counter + 1

	if counter % 10 == 0 then
		local experiences = component.list("experience")
		for id, type in pairs(experiences) do
			local short = id:sub(1, 6)
			local proxy = component.proxy(component.get(id))
			local level = proxy.level()
			print(short .. " : " .. tostring(level))
		end

		local currentTime = computer.uptime()
		local timeDiff = currentTime - startTime
		local levelDiff = robot.level() - startLevel
		local perSec = levelDiff / timeDiff
		print("Per sec on main: " .. tostring(perSec))
	end

	if counter == rechargeLimit then
		ic.equip()
		ic.dropIntoSlot(rechargeSide, 1)
		os.sleep(rechargeDuration)
		ic.suckFromSlot(rechargeSide, 1)
		ic.equip()

		counter = 0
	end
end