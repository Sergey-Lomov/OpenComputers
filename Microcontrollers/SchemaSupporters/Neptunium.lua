--local component = require 'component'
--local computer = require 'computer'

transposer = component.proxy(component.list("transposer")())
modem = component.proxy(component.list("modem")())

inSide = 1 -- Items provider inventory
outSide = 1 -- Items provider inventory
schemaSide = 0 -- Inventory which schema should be supported

statusPort = 4361
pingId = "nep1_id"
pingTitle = "Нептуний 1"
warningCode = 1
problemCode = 2
pingCode = 3
cancelCode = 4
ativeStatuses = {}

-- In this table may be specified slots, which should contains elements in item provider inventory. If slot fo element not specified, element will be searched in all slots.
providersSlots = {
	["dwcity:ReactorNeptuniumDual:1"] = 8,
	["dwcity:ReactorNeptuniumSimple:1"] = 9
}

-- This table contains list of slots, which should be controlled. If list is empty, app will controll all slots
controllSlots = {}

schema = {}

lastPing = 0
function sendPing()
	if computer.uptime() - lastPing < 15  then return end
	local data = string.format('{id="%s",title="%s"}', pingId, pingTitle)
	modem.broadcast(statusPort, pingCode, data)
	lastPing = computer.uptime()
end

function sendStatus(status, id, message)
	local data = string.format('{id="%s",message="%s"}', id, message)
	modem.broadcast(statusPort, status, data)
	ativeStatuses[id] = true
end

function cancelStatus(id)
	if ativeStatuses[id] ~= nil then
		modem.broadcast(statusPort, cancelCode, id)
		ativeStatuses[id] = nil
	end
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
		inSlot = firstSlotWhere(inSide, "name", name)
	end

	if inSlot == nil then
		computer.pullSignal(1)
		return
	end

	return transposer.transferItem(inSide, schemaSide, 1, inSlot, slot)
end

function moveOut(slot, stack)
	local success = transposer.transferItem(schemaSide, outSide, stack.maxSize, slot)
	
	local warnId = pingId .. "_noOut_" .. slot
	if success then
		cancelStatus(warnId)
	else
		local message = pingTitle .. ": не получается вывести " .. stack.label
		sendStatus(warningCode, warnId, message)
	end

	return success
end

function checkEmptiness(slot)
	local stack = transposer.getStackInSlot(schemaSide, slot)
	if stack == nil then return end
	moveOut(slot, stack)
end

function checkElement(slot, requiredName)
	local stack = transposer.getStackInSlot(schemaSide, slot)
	
	if stack == nil then 
		restoreElement(slot, requiredName)
		return
	end

	if stack.name ~= requiredName then
		if moveOut(slot, stack) then
			restoreElement(slot, requiredName)
		end
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

function start()
	while true do
		computer.pullSignal(0.5)
		sendPing()
		checkSchema()
	end
end

setup()
start()