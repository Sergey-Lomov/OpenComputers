require 'extended_robot'

local status = require 'status_client'
local component = require 'component'

local inventory = component.inventory_controller
local configFile = "config"
local checkFrequency = 100

local killer = {}

local function pingRoutine()
	status:sendPing()
end

function killer:checkTool(recharge)
	robot.select(1)
	inventory.equip()
	local toolStack = inventory.getStackInInternalSlot(1)
	if toolStack == nil then
		utils:showError("Try to check missed tool")
		return 0
	end

	if robot.chargeForStack(toolStack) < recharge.limit then
		robot.rechargeTool(recharge, 1, pingRoutine)
	end
	inventory.equip()
end

function killer:checkSelfCharge(recharge)
	if robot.chargeLevel() < recharge.limit then
		robot.recharge(recharge, pingRoutine)
	end
end

function killer:checkUnload(unload)
	if robot.count(unload.checkSlot) > 0 then
		robot.unload(unload, pingRoutine)
	end
end

function killer:start()
	local config = utils:loadFrom(configFile)
	status.pingId = inventory.address
	status.pingTitle = config.pingTitle
	status:sendPing(true)

	while true do
		-- Run few atacks without status checking
		for i = 1, checkFrequency do
			robot.swingDown()
			status:sendPing()
		end

		self:checkSelfCharge(config.selfRecharge)
		self:checkUnload(config.unload)
		self:checkTool(config.toolRecharge)
	end
end

return killer