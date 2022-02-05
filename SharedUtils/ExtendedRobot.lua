require 'extended_table'

local navigator = require 'navigator'
local icExtender = require 'ic_extender'
local component = require 'component'
local computer = require 'computer'

local inventory = component.inventory_controller
icExtender:extend(inventory)

local waitingStep = 1
local fullChargeLimit = 0.975

local Modes = {
	ic2 = "IC2",
	galaxy = "GalaxySpace",
	draconic = "DraconicEvolution",
	gravi = "GraviSuite",
}

function robot.chargeForStack(stack)
	if stack == nil then return 0 end

	local mode = string.gmatch(stack.name, '([^:]+)')()
	if mode == Modes.ic2 or mode == Modes.gravi then
		return stack.charge / stack.maxCharge
	elseif mode == Modes.draconic then
		return stack.energy / stack.maxEnergy
	elseif mode == Modes.galaxy then
		return 1 - (stack.damage / stack.maxDamage)
	else
		utils:showError("Try to handle chargin of unsupported mode tool: " .. mode)
		return 0
	end
end

function robot.chargeLevel()
	return computer.energy() / computer.maxEnergy()
end

function robot.rechargeTool(charge, slot, routine)
	if charge.route ~= nil then
		navigator:runRoute(charge.route, routine)
	end

	navigator:faceTo(charge.face)
	robot.select(slot)
	inventory.dropIntoSlot(charge.side, charge.inSlot)
	
	repeat 
		if routine ~= nil then routine() end
		os.sleep(waitingStep)
		local outStack = inventory.getStackInSlot(charge.side, charge.outSlot)
	until robot.chargeForStack(outStack) >= fullChargeLimit

	inventory.suckFromSlot(charge.side, charge.outSlot)

	if charge.route ~= nil then
		navigator:runRouteReverse(charge.route, routine)
	end
end

function robot.recharge(charge, routine)
	if charge.route ~= nil then
		navigator:runRoute(charge.route, routine)
	end
	
	repeat 
		if routine ~= nil then routine() end
		os.sleep(waitingStep)
	until robot.chargeLevel() >= fullChargeLimit

	if charge.route ~= nil then
		navigator:runRouteReverse(charge.route, routine)
	end
end

function robot.unload(unload, routine)
	if unload.route ~= nil then
		navigator:runRoute(unload.route, routine)
	end
	navigator:faceTo(unload.face)
	
	local filter = unload.filter
	if filter == nil and unload.excludeSlots ~= nil then
		filter = function (slot, stack)
			return not table.containsValue(unload.excludeSlots, slot)
		end
	end

	inventory:unload(unload.side, filter)

	if unload.route ~= nil then
		navigator:runRouteReverse(unload.route, routine)
	end
end