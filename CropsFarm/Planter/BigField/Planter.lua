local utils = require("utils")
local robot = require("robot")
local computer = require("computer")
local term = require("term")
local icExtender = require("inventory_extender")

local configFile = "planterConfig"
local seedStackName = "IC2:itemCropSeed"
local perchesStackName = "IC2:blockCrop"
local weedStackName = "IC2:itemWeed"
local perchesSlot = 1
local hoeSlot = 2
local maxPerchesLimit = 64

Status = {
	planed = 0,
	processing = 1,
	finished = 3,
	unavailable = 4
}

local planter = {
	config = {},
	inventory = component.inventory_controller,
	navigator = require("navigator"),
	field = {
		start = {x = 0, z = 0}, 
		finish = {x = 0, z = 0},
		size = {x = 0, z = 0},
		direction = {x = 1, z = 1}
	},
	unhandledPoints = {},
	statuses = {},
	forcedTargetIndex = nil,
	noSeedsMode = false
}

function planter.field:contains(point)
	local minX = math.min(self.start.x, self.finish.x)
	local maxX = math.max(self.start.x, self.finish.x)
	local minZ = math.min(self.start.z, self.finish.z)
	local maxZ = math.max(self.start.z, self.finish.z)
	
	local validX = point.x <= maxX and point.x >= minX
	local validZ = point.z <= maxZ and point.z >= maxZ
	return validX and validZ
end

function planter:pointToIndex(point) -- Indexate points by snake order
	local absX = math.abs(self.field.start.x - point.x)
	local absZ = math.abs(self.field.start.z - point.z)
	local index = absX * self.field.size.z
	if absX % 2 == 0 then
		index = index + absZ
	else
		index = index + (self.field.size.z - absZ) - 1
	end

	return index + 1 -- In lua indexing start from 1
end

function planter:indexToPoint(index) -- Restore point coords by index
	local normalisedIndex = index - 1
	local absZ = normalisedIndex % self.field.size.z
	local absX = (normalisedIndex - absZ) / self.field.size.z
	if absX % 2 == 1 then
		absZ = self.field.size.z - absZ - 1
	end

	local relX = absX * self.field.direction.x
	local relZ = absZ * self.field.direction.z
	local x = relX + self.field.start.x
	local z = relZ + self.field.start.z

	return {x = x, z = z, y = self.config.fieldCorner1.y}
end

local function distance(p1, p2)
	return math.abs(p1.x - p2.x) + math.abs(p1.z - p2.z)
end

function planter:firstStatusIndex(status, from)
	local sourceIndex = 1
	if from ~= nil then
		if from ~= #self.statuses then
			sourceIndex = from + 1
		end
	end

	for index = sourceIndex, #self.statuses do
		if self.statuses[index] == status then
			return index
		end
	end

	for index = 1, from - 1 do
		if self.statuses[index] == status then
			return index
		end
	end

	return nil
end

function planter:route()
	local firstPoint = nil
	local lastPoint = nil
	local routeLength = 0

	for index = 1, #self.statuses do
		if self.statuses[index] ~= Status.processing then goto continue end

		local point = self:indexToPoint(index)
		if firstPoint == nil then 
			firstPoint = point 
			lastPoint = point 
		end
		routeLength = routeLength + distance(lastPoint, point)
		lastPoint = point

		::continue::
	end

	routeLength = routeLength + distance(lastPoint, firstPoint)

	return {firstPoint = firstPoint, lastPoint = lastPoint, length = routeLength}
end

function planter:extendedRoute(route, point)
	local oneWayLength = route.length - distance(route.firstPoint, route.lastPoint)
	local updatedLength = oneWayLength + distance(route.lastPoint, point) + distance(point, route.firstPoint)
	return {firstPoint = route.firstPoint, lastPoint = point, length = updatedLength}
end

function planter:extendProcessing()
	if self.noSeedsMode then return end -- Robot have no possibility to seeds new crops so no need to add empty points to processing

	local route = self:route()

	while true do
		local routeEndIndex = self:pointToIndex(route.lastPoint)
		local planedIndex = self:firstStatusIndex(Status.planed, routeEndIndex)
		if planedIndex == nil then return end -- No more planed points

		local planedPoint = self:indexToPoint(planedIndex)
		local extendedRoute = self:extendedRoute(route, planedPoint)
		if extendedRoute.length > self.config.maxRoute then
			return -- Next planed point make route to long
		end

		self.statuses[planedIndex] = Status.processing
		route = extendedRoute
	end
end

function planter:initPointsStatuses()
	local maxIndexZ = self.field.size.x % 2 == 0 and self.field.start.z or self.field.finish.z
	local maxIndexPoint = {x = self.field.finish.x, z = maxIndexZ}
	local maxIndex = self:pointToIndex(maxIndexPoint)

	for index = 1, maxIndex do
		self.statuses[index] = Status.planed
	end

	for index = 1, #self.config.unavailable do
		local unavailablePoint = self.config.unavailable[index]
		local unavailableIndex = self:pointToIndex(unavailablePoint)
		self.statuses[unavailableIndex] = Status.unavailable
	end

	self.statuses[1] = Status.processing
	self:extendProcessing()
end

function planter:setPerche()
	::set_perche::

	robot.swingDown()
	robot.select(hoeSlot)
	robot.placeDown()
	robot.select(perchesSlot)
	robot.placeDown()

	os.sleep(1)
	local _, result = robot.detectDown()
    if result ~= "solid" then -- Solid type means perches setted successfully
        goto set_perche
    end
end

function planter:loadResources()
	local requiredPerches = maxPerchesLimit - robot.count(perchesSlot)
	if requiredPerches > 0 then
		local perchesOutSlot = self.inventory:firstSlotWhere(self.config.serviceSide, "name", perchesStackName)
		if perchesOutSlot ~= nil then
			robot.select(perchesSlot)
			self.inventory.suckFromSlot(self.config.serviceSide, perchesOutSlot, requiredPerches)
		end
	end

	local requiredHoe = robot.count(hoeSlot) == 0
	if requiredHoe then
		local hoeOutSlot = self.inventory:firstSlotWhere(self.config.serviceSide, "name", self.config.hoeStackName)
		if hoeOutSlot ~= nil then
			robot.select(hoeSlot)
			self.inventory.suckFromSlot(self.config.serviceSide, hoeOutSlot)
		end
	end

	local maxSeedSlot = robot.inventorySize() - self.config.dropSlotsCount
	for i = hoeSlot + 1, maxSeedSlot do
		if robot.count(i) ~= 0 then goto continue end

		local seedOutSlot = self.inventory:firstSlotWhere(self.config.serviceSide, "name", seedStackName)
		if seedOutSlot ~= nil then
			robot.select(i)
			self.inventory.suckFromSlot(self.config.serviceSide, seedOutSlot)
		end

		::continue::
	end

	if self.inventory:firstInternalSlotWhere("name", seedStackName) == nil then
		self.noSeedsMode = true
	end
end

function planter:goToService()
	self.navigator:goTo(self.config.servicePosition)
	self.navigator:faceTo(self.config.serviceFace)

	local unloadFilter = function (slot, stack)
		if slot == perchesSlot then return false end
		if slot == hoeSlot then
			local energy = stack[self.config.hoeEnergyKey]
			return energy < self.config.hoeEnergyLimit
		end
		return stack.name ~= seedStackName
	end
	self.inventory:unload(self.config.serviceSide, unloadFilter)

	self:loadResources()
end

function planter:recharge()
	 -- Time to time it is impossibly to charge robot to full energy
	self.navigator:runRoute(self.config.toRechargeRoute)
	local energyFull = false
	while not energyFull do
		energyFull = computer.energy() >= computer.maxEnergy() * 0.95
		os.sleep(1)
	end

	self.navigator:runRoute(self.config.fromRechargeRoute)
end

function planter:handleEmptyPoint(index)
	if self.noSeedsMode then 
		self.statuses[index] = Status.planed
		return 
	end

	local seedSlot = self.inventory:firstInternalSlotWhere("name", seedStackName)
	if seedSlot == nil then
		self.forcedTargetIndex = self:firstStatusIndex(Status.processing)
		self:goToService()
		return
	end

	self:setPerche()
	robot.select(seedSlot)
	robot.placeDown()
end

function planter:handleWeedAfftectedPoint(point)
	self.navigator:goTo(point)
	local result, cooment = robot.useDown()
	if comment ~= "item_used" then return end

	local index = self:pointToIndex(point)
	self.statuses[index] = Status.processing
	self.handleWeedPoint(point)
end

function planter:handleWeedAffect(weedPoint)
	local nearestPoints = {
		[1] = {x = weedPoint.x + 1, z = weedPoint.z, y = self.config.fieldCorner1.y},
		[2] = {x = weedPoint.x - 1, z = weedPoint.z,  y = self.config.fieldCorner1.y},
		[3] = {x = weedPoint.x, z = weedPoint.z - 1, y = self.config.fieldCorner1.y},
		[4] = {x = weedPoint.x, z = weedPoint.z + 1,  y = self.config.fieldCorner1.y}
	}
	local affectedPoints = {}

	for i = 1, 4 do
		local point = nearestPoints[i]
		local index = self:pointToIndex(point)
		local isInField = self.field:contains(point)
		local isFinished = self.statuses[index] == Status.finished
		if isInField and isFinished then
			table.insert(affectedPoints, point)
		end
	end

	for i = 1, #affectedPoints do
		local point = affectedPoints[i]
		self:handleWeedAfftectedPoint(point)
	end
end

function planter:handleWeedPoint(index)
	local weedSlot = self.inventory:firstInternalSlotWhere("name", weedStackName)
	if weedSlot ~= nil then
		robot.select(weedSlot)
		robot.dropUp()
	end

	::reseed::
	local point = self:indexToPoint(index)
	if self.noSeedsMode then
		robot.swingDown()
		self.statuses[index] = Status.planed
	else 
		local seedSlot = self.inventory:firstInternalSlotWhere("name", seedStackName)
		if seedSlot ~= nil then
			robot.select(seedSlot)
			robot.placeDown()
		else 
			self:goToService()
			self.navigator:goTo(point)
			robot.useDown()
			goto reseed
		end
	end

	self:handleWeedAffect(point)
end

function planter:handleTargetIndex(index)
	local point = self:indexToPoint(index)
	self.navigator:goTo(point)

	local _, bottom = robot.detectDown()
	if bottom == "air" or bottom == "replaceable" then
		self:handleEmptyPoint(index)
		return
	end

	local result, comment = robot.useDown()
	if not result then -- This means no weed and not fully growed plant
		return
	end

	if comment == "item_used" then -- This means weed was harvested
		self:handleWeedPoint(index)
		return
	elseif comment == "block_activated" then -- This means crop did grow to max size, so planting completed
		self.statuses[index] = Status.finished
		self:extendProcessing()
	end
end

function planter:init()
	self.config = utils:loadFrom(configFile)
	if self.config.fieldCorner1.y ~= self.config.fieldCorner2.y then
		utils:showError("Field corners have different y coord")
		self.config = {}
		return
	end
	
	self.field.start = {x = self.config.fieldCorner1.x, z = self.config.fieldCorner1.z}
	self.field.finish = {x = self.config.fieldCorner2.x, z = self.config.fieldCorner2.z}
	
	local xSize = math.abs(self.field.start.x - self.field.finish.x) + 1
	local zSize = math.abs(self.field.start.z - self.field.finish.z) + 1
	self.field.size = {x = xSize, z = zSize}

	local xDirection = self.field.start.x <= self.field.finish.x and 1 or -1
	local zDirection = self.field.start.z <= self.field.finish.z and 1 or -1
	self.field.direction = {x = xDirection, z = zDirection}

	icExtender:extend(self.inventory)
	self.navigator:nullify()
end

function planter:start()
	self:initPointsStatuses(self.config.maxProcessingCount)
	local energyLimit = computer.maxEnergy() * self.config.rechargeRate

	local currentTargetIndex = self:firstStatusIndex(Status.processing)
	while currentTargetIndex ~= nil do
		self:handleTargetIndex(currentTargetIndex)
		self:printStatuses()
		print("Handled index: " .. currentTargetIndex)

		if computer.energy() < energyLimit then
			self:recharge()
		end

		if self.forcedTargetIndex ~= nil then
			currentTargetIndex = self.forcedTargetIndex
			self.forcedTargetIndex = nil
		else
			currentTargetIndex = self:firstStatusIndex(Status.processing, currentTargetIndex)
		end

		if currentTargetIndex ~= nil then
			print("Next index: " .. currentTargetIndex)
		else
			print("Work done")
		end
	end
end

-- Debug methods
function planter:printStatuses()
	term.clear()
	for x = self.field.start.x, self.field.finish.x, self.field.direction.x do
		local row = ""
		for z = self.field.start.z, self.field.finish.z, self.field.direction.z do
			local index = self:pointToIndex({x = x, z = z})
			local status = self.statuses[index]
			row = row .. " " .. tostring(status)
		end
		print(row)
	end
end

planter:init()
return planter