local component = require 'component'
local computer = require 'computer'

local transposer = component.transposer
local redstone = component.redstone
local redOutSide = 3
local inOutSide = 2 -- Items provider inventory
local schemaSide = 3 -- Inventory which schema should be supported

-- In this table may be specified slots, which should contains elements in item provider inventory. If slot fo element not specified, element will be searched in all slots.
local providersSlots = {
	["minecraft:wheat_seed"] = 17,
	["IC2:reactorCondensatorLap"] = 9
}

-- This table contains list of slots, which should be controlled. If list is nil, app will controll all slots
local controllSlots = {1, 5, 8, 12, 17, 19, 24, 31, 36, 38, 43, 47, 50, 54}

local criticalDamage = {
	["IC2:reactorCondensatorLap"] = 6000
}

schema = {}

function handleIncomeElementsMissing()
end

function handleMoveoutImpossibility()
end

function firstSlotWhere(side, key, value)
	local size = transposer.getInventorySize(side)
	if type(size) ~= "number" then
		computer.beep(600, 0.5)
		return nil
	end

	for i = 1, size, 1 do
		local stack = transposer.getStackInSlot(side, i)
		if stack ~= nil then
			if stack[key] == value then
				return i
			end
		end
	end
	return nil
end

function setup()
	if #controllSlots == 0 then
		local schemaSize = transposer.getInventorySize(schemaSide)
		if type(schemaSize) ~= "number" then
			computer.beep(400, 0.5)
			return false
		end

		for i = 1, schemaSize, 1 do
			table.insert(controllSlots, i)
		end
	end

	for _, i in ipairs(controllSlots) do
		local stack = transposer.getStackInSlot(schemaSide, i)
		if stack ~= nil then
			schema[i] = stack.name
		end
	end

	return true
end

function restoreElement(slot, name)
	local inSlot = providersSlots[name]
	if inSlot == nil then
		inSlot = firstSlotWhere(inOutSide, "name", name)
	end

	if inSlot == nil then 
		handleIncomeElementsMissing()
		return false
	end

	return transposer.transferItem(inOutSide, schemaSide, 1, inSlot, slot)
end

function moveOut(slot, stack)
	local success = transposer.transferItem(schemaSide, inOutSide, stack.maxSize, slot)
	if not success then
		handleMoveoutImpossibility()
	end

	return success
end

function checkEmptiness(slot)
	local stack = transposer.getStackInSlot(schemaSide, slot)
	if stack == nil then return end
	moveOut(slot, stack)
end

function replaceAtSlot(slot, stack, requiredName)
	redstone.setOutput(redOutSide, 0)
	if moveOut(slot, stack) then
		if restoreElement(slot, requiredName) then
			redstone.setOutput(redOutSide, 15)
		end
	end
end

function checkElement(slot, requiredName)
	local stack = transposer.getStackInSlot(schemaSide, slot)
	
	if stack == nil then 
		restoreElement(slot, requiredName)
		return
	end

	local criticalDamage = criticalDamage[stack.name] or math.huge
	if stack.name ~= requiredName or stack.damage >= criticalDamage then
		replaceAtSlot(slot, stack, requiredName)
	end
end

function checkSchema()
	for _, i in ipairs(controllSlots) do
		local requiredName = schema[i]
		if requiredName == nil then
			checkEmptiness(i)
		else
			checkElement(i, requiredName)
		end
	end
end

function startSupport()
	redstone.setOutput(redOutSide, 15)
	while true do
		checkSchema()
	end
end
