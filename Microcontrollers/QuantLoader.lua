-- Quntum Loader (1.0)

local component = require 'component'
local computer = require 'computer'

local transposer = component.transposer
local firstOutSlot = 18
local lastOutSlot = 29
local quantMachineSlots = 29

local groupsSizes = {

}

inSide = nil
outSide = nil

function setup()
	for i = 0, 5, 1 do
		local inventorySize = transposer.getInventorySize(i)
		if type(inventorySize) ~= "number" then goto continue end
		
		if inventorySize == quantMachineSlots then
			if outSide == nil then 
				outSide = i
			else
				computer.beep(600, 1)
				return false
			end
		else
			if inSide == nil then 
				inSide = i
			else
				computer.beep(200, 1)
				return false
			end
		end

		::continue::
	end

	computer.beep(300, 0.25)
	computer.beep(400, 0.25)
	computer.beep(300, 0.25)

	return true
end

function firstItemInRange(from ,to)
	for slot = from, to, 1 do
		local stack = transposer.getStackInSlot(inSide, slot)
		if stack ~= nil then
			return slot, stack
		end
	end
end

local lastInSlot = 1
function nextInStack()
	local inSize = transposer.getInventorySize(inSide)
	if type(inSize) ~= "number" then return nil end

	local slot, stack = firstItemInRange(lastInSlot + 1, inSize)
	if stack ~= nil then
		lastInSlot = slot
		return stack
	end

	local slot, stack = firstItemInRange(1, lastInSlot)
	if stack ~= nil then
		lastInSlot = slot
		return stack
	end

	return nil
end

function getOutSlotsInfo(name, label)
	local minSlot = nil
	local minSlotCount = math.huge
	local totalCount = 0
	local availableSlots = 0

	for i = firstOutSlot, lastOutSlot, 1 do
		local stack = transposer.getStackInSlot(outSide, i)
		if stack == nil then 
			availableSlots = availableSlots + 1
			minSlot = i
			minSlotCount = 0
			goto continue
		end

		if stack.name ~= name or stack.label ~= label then goto continue end
		
		availableSlots = availableSlots + 1
		totalCount = totalCount + stack.size

		if stack.size < minSlotCount then
			minSlot = i
			minSlotCount = stack.size
		end

		::continue::
	end

	return minSlot, minSlotCount, totalCount, availableSlots
end

function loadingIteration()
	local inSize = transposer.getInventorySize(inSide)
	if type(inSize) ~= "number" then return nil end

	local inSlot, inStack = firstItemInRange(1, inSize) --nextInStack()
	if inSlot == nil or inStack == 0 then return end
	
	local groupSize = groupsSizes[inStack.name] or 1
	local outSlot, outSlotCount, totalCount, availableSlots = getOutSlotsInfo(inStack.name, inStack.label)
	if outSlot == nil or availableSlots == 0 then return end

	local balancedCount = (totalCount + inStack.size) / availableSlots
	local estimatedTransferCount = balancedCount - outSlotCount
	local transferGroups = math.ceil(estimatedTransferCount / groupSize)
	local transferCount = transferGroups * groupSize

	transposer.transferItem(inSide, outSide, transferCount, inSlot, outSlot)
end