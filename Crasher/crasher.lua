require("utils")

local sides = require("sides")
local robot = require("robot")
local computer = require("computer")
local component = require("component")
local status = require("status_client")

local inventory = component.inventory_controller
local rs = component.redstone

local configFile = "config"
local statsFile = "stats"

local config = utils:loadFrom(configFile)
local stats = utils:loadFrom(statsFile)
local waitingStep = 1

local crasher = {
	sessionSize = 0, -- Amount of blocks in current seesion (between two sucks from income buffer)
	sessionBlock = "none"
}

function crasher:waitBlocks()
	robot.select(1)
	status:sendPing()
	while robot.count() == 0 do
		os.sleep(waitingStep)
		status:sendPing()
		self:suckFirstAvailableStack()

		if robot.count() ~= 0 then
			self.sessionSize = robot.count()
			local blockStack = inventory.getStackInInternalSlot(1)
			self.sessionBlock = blockStack.label
		end
	end
end

function crasher:suckFirstAvailableStack()
	for i = 1, inventory.getInventorySize(config.inSide), 1 do
		if inventory.getStackInSlot(config.inSide, i) ~= nil then
			inventory.suckFromSlot(config.inSide, i)
			return
		end
	end
end

function crasher:firstEmptySlot(side)
	for i = 1, inventory.getInventorySize(side), 1 do
		if inventory.getStackInSlot(side, i) == nil then
			return i
		end
	end
	return nil
end

function crasher:pushOutDropIfNecessary()
	local firstStack = inventory.getStackInInternalSlot(1) or {label = ""}
	if robot.count() ~= 0 and firstStack.label == self.sessionBlock then 
		return 
	end

	os.sleep(2) -- Need gap, because robot get last drop with gap time to time

	self:updateStatistic()
	for i = 1, robot.inventorySize(config.outSide), 1 do
		if robot.count(i) ~= 0 then
			robot.select(i)
			local targetSlot = self:firstEmptySlot(config.outSide)
			inventory.dropIntoSlot(config.outSide, targetSlot)
		end
	end
	robot.select(1)
end

function crasher:updateStatistic()
	local drop = {}
	for i = 1, robot.inventorySize(config.outSide), 1 do
		local stack = inventory.getStackInInternalSlot(i)
		if stack ~= nil then
			drop[stack.label] = (drop[stack.label] or 0) + stack.size
		end
	end

	local sessionStats = stats[self.sessionBlock] or {count = 0, drop = {}}
	sessionStats.count = sessionStats.count + self.sessionSize

	for key, value in pairs(drop) do
		sessionStats.drop[key] = (sessionStats.drop[key] or 0) + value
	end

	stats[self.sessionBlock] = sessionStats
	utils:saveTo(statsFile, stats)
end

function crasher:rechargeTool()
	rs.setOutput(sides.right, 15)
	os.sleep(waitingStep)
	rs.setOutput(sides.right, 0)
	
	local charged = false
	while not charged do
		os.sleep(waitingStep)
		charged = self:getToolStack() ~= nil
	end
end

function crasher:getToolStack()
	inventory.equip()
	local toolStack = inventory.getStackInInternalSlot(1)
	inventory.equip()
	return toolStack
end

function crasher:getCharge()
	local toolStack = self:getToolStack()
	return toolStack[config.chargeKey]
end

function crasher:start()
	status.pingId = inventory.address
	status.pingTitle = config.pingTitle
	status.pingAllowableDelay = config.pingAllowableDelay
	status.statusStrength = config.statusStrength
	status:sendPing(true)

	while true do
		self:waitBlocks()

		robot.place()
		robot.swing()

		self:pushOutDropIfNecessary()
		if self:getCharge() <= config.chargeLimit then
			self:rechargeTool()
		end
	end
end

function crasher:setup()

	if config == nil then
		config = {}
	end
	
	print("Укажите входную сторону (низ - 0, верх - 1, сзади - 2, спереди - 3) [право/лево невозможно]")
	config.inSide = tonumber(term.read())
	print("Укажите выходную сторону (низ - 0, верх - 1, сзади - 2, спереди - 3) [право/лево невозможно]")
	config.outSide = tonumber(term.read())
	print("Укажите уровень энергии, при достижении которого инструмент будет отправляться на зарядку")
	config.chargeLimit = tonumber(term.read())
	print("Инструмент какого мода вы используете: (1 - IC2, 2 - Draconic)")
	local mod = tonumber(term.read())
	if mod == 1 then
		config.chargeKey = "charge"
		config.maxChargeKey = "maxCharge"
	elseif mod == 2 then
		config.chargeKey = "energy"
		config.maxChargeKey = "maxEnergy"
	else
		utils:showError("Неверный индекс мода")
	end

	utils:saveTo(configFile, config)
end

function crasher:showAllStats()
	for key, _ in pairs(stats) do
		self:showStat(key)
	end
end

function crasher:showStat(ore)
	if ore == nil then
		self:showAllStats()
		return
	end

	if stats[ore] == nil then
		print("Unknown ore")
	end

	local stat = stats[ore]
	print(ore .. ": " .. tostring(stat.count))
	for item, count in pairs(stat.drop) do
		print("\t" .. item .. ": " .. tostring(count) .. " avg: " .. tostring(count / stat.count))
	end
end

return crasher