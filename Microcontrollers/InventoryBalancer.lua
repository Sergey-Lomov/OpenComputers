--Quntum Controller (1.0)

local component = require 'component'

local transposer = component.transposer
local firstInSlot = 18
local lastInSlot = 29
local quantMachineSlots = 29

groupsSizes = {

}

function minCountSlot(side, name, label)
	local currentResult = nil
	local currentResultCount = math.huge
	
	for i = firstInSlot, lastInSlot, 1 do
		local stack = transposer.getStackInSlot(side, i)
		if stack == nil then return i, 0 end
		if stack.name ~= name or stack.label ~= label then goto continue end
		
		if stack.size < currentResultCount then
			currentResultCount = stack.size
			currentResult = i
		end

		::continue::
	end

	local count = currentResultCount or 0
	return currentResult, count
end

function balanceAtSide(side)
	local inventorySize = transposer.getInventorySize(side)
	if type(inventorySize) ~= "number" then return end
	if inventorySize ~= quantMachineSlots then return end

	local balanced = {}
	for slot = firstInSlot, lastInSlot, 1 do
		if balanced[slot] then goto continue end

		local stack = transposer.getStackInSlot(side, slot)
		if stack == nil then goto continue end

		-- Spreading
		local groupSize = groupsSizes[stack.name] or 1
		local groups = stack.size / groupSize
		if groups < 2 then goto continue end
		
		local targetSlot, targetCount = minCountSlot(side, stack.name, stack.label)
		local targetGroups = targetCount / groupSize
		local transferGroups = math.floor((groups + targetGroups) / 2)
		if transferGroups <= 0 then goto continue end
		local transferCount = transferGroups * groupSize
		transposer.transferItem(side, side, transferCount, slot, targetSlot)

		balanced[slot] = true
		balanced[targetSlot] = true

		::continue::
	end
end

function start()
	while true do
		for side = 0, 5, 1 do
			balanceAtSide(side)
		end
	end
end