t = component.proxy(component.list("transposer")())
m = component.proxy(component.list("modem")())

inSide = 1 -- Items provider inventory
outSide = 1 -- Items provider inventory
schemaSide = 0 -- Inventory which schema should be supported
frequency = 2.5

sp = 4361			-- Status port
pid = "nep1_id"		-- Ping id
pt = "Нептуний 1"	-- Ping title
wc = 1				-- Warning code
prc = 2 			-- Problem code
pic = 3				-- Ping code
cc = 4  			-- Cancel code
ass = {}			-- Active statuses

-- In this table may be specified slots, which should contains elements in item provider inventory. 
-- If slot for element not specified and 'upso' setted to false, element will be searched in all slots.
providersSlots = {
	["IC2:reactorMOXQuad:1"] = 9,
}
upso = true  -- Search items only in slots specified in 'providersSlots'

updateStreams = {
	{1,3,4,6,7,8,10,12,13,14,15,17,18,19,20,21,23,24,25,26,29,30,31,32,34,35,36,37,38,40,41,42,43,45,47,48,49,51,52,54},
}
streamsCarrets = {}

schema = {}

lastPing = 0
function sendPing()
	if computer.uptime() - lastPing < 15  then return end
	local data = string.format('{id="%s",title="%s"}', pid, pt)
	m.broadcast(sp, pic, data)
	lastPing = computer.uptime()
end

function sendStatus(status, id, message)
	local data = string.format('{id="%s",message="%s"}', id, message)
	m.broadcast(sp, status, data)
	ass[id] = true
end

function cancelStatus(id)
	if ass[id] ~= nil then
		m.broadcast(sp, cc, id)
		ass[id] = nil
	end
end

function firstSlotWhere(side, key, value)
	local size = t.getInventorySize(side)
	if type(size) ~= "number" then
		computer.beep(600, 0.5)
		return nil
	end

	for i = 1, size, 1 do
		local stack = t.getStackInSlot(side, i)
		if stack ~= nil then
			if stack[key] == value then
				return i
			end
		end
	end
	return nil
end

function setup()
	for _, stream in ipairs(updateStreams) do
		for _, slotIndex in ipairs(stream) do
			local stack = t.getStackInSlot(schemaSide, slotIndex)
			if stack ~= nil then
				schema[slotIndex] = stack.name
			end
		end
	end

	return true
end

function restoreElement(slot, name)
	local inSlot = providersSlots[name]
	if inSlot == nil and not upso then
		inSlot = firstSlotWhere(inSide, "name", name)
	end

	if inSlot == nil then 
		return false
	end

	return t.transferItem(inSide, schemaSide, 1, inSlot, slot)
end

function moveOut(slot, stack)
	local success = t.transferItem(schemaSide, outSide, stack.maxSize, slot)
	
	local warnId = pid .. "_noOut_" .. slot
	if success then
		cancelStatus(warnId)
	else
		local message = pt .. ": не получается вывести " .. stack.label
		sendStatus(wc, warnId, message)
	end

	return success
end

function checkEmptiness(slot)
	local stack = t.getStackInSlot(schemaSide, slot)
	if stack == nil then 
		return true, false
	end
	
	local success = moveOut(slot, stack)
	return success, success
end

function checkElement(slot, requiredName)
	local stack = t.getStackInSlot(schemaSide, slot)
	
	if stack == nil then 
		local success = restoreElement(slot, requiredName)
		return success, success
	end

	if stack.name ~= requiredName then
		if moveOut(slot, stack) then
			local success = restoreElement(slot, requiredName)
			return success, success
		else
			return false, false
		end
	end

	return true, false
end

function iterateStreams()
	for streamIndex, stream in ipairs(updateStreams) do
		local instreamIndex = streamsCarrets[streamIndex]
		local slotIndex = stream[instreamIndex]
		local requiredName = schema[slotIndex]
		
		local wasChanged = false
		if requiredName == nil then
			_, wasChanged = checkEmptiness(slotIndex)
		else
			_, wasChanged = checkElement(slotIndex, requiredName)
		end

		if wasChanged then
			if instreamIndex == #stream then
				streamsCarrets[streamIndex] = 1
			else
				streamsCarrets[streamIndex] = instreamIndex + 1
			end
		end
	end
end

function start()
	for i = 1, #updateStreams do streamsCarrets[i] = 1 end
	while true do
		computer.pullSignal(frequency)
		sendPing()
		iterateStreams()
	end
end

setup()
start()