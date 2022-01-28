require 'extended_table'

local utils = require 'utils'
local navigator = require 'navigator'
local icExtender = require 'ic_extender'
local status = require 'status_client'

local sides = require 'sides'
local component = require 'component'

local perchesSlot = 1
local hoeSlot = 2
local firstSeedSlot = 3
local perchesLimit = 64
local perchesStackName = "IC2:blockCrop"
local seedStackName = "IC2:itemCropSeed"
local seedsCheckFrequency = 10
local rechargingCheckFrequency = 2
local rechargeCheckLimit = 0.95
local hoeLowLimit = 200
local pingTitle = "Сеятель"
local pingDelay = 90

inventory = component.inventory_controller

local StatusPostfix = {
	missedSeeds = "_no_seeds",
	jobDone = "_job_done",
}

local Phrases = {
	missedJob = "Работа не загружена",
	missedSeeds = "Нехватает семян",
	jobDone = "Высевание завершено",
}

local planter = {
	job = nil,
	currentTask = nil
}

function planter:goToService(isLast)
	if isLast == nil then isLast = false end

	local servicePoint = self.job.toServiceRoute[#self.job.toServiceRoute]
	if navigator.x ~= servicePoint.x or navigator.y ~= servicePoint.y or navigator.z ~= servicePoint.z then
		navigator:runRoute(self.job.toServiceRoute)
	end

	if isLast then return end

	navigator:faceTo(self.job.loadingFace)
	status:sendPing()

	-- Drop hoe to charger
	robot.select(hoeSlot)
	inventory.dropIntoSlot(self.job.toolsChargeSide, 1)

	-- Get perches
	robot.select(perchesSlot)
	while robot.count() < perchesLimit do
        local perchesRequest = perchesLimit - robot.count()
        local perchesSourceSlot = inventory:firstSlotWhere(sides.front, "name", perchesStackName)
        if perchesSourceSlot ~= nil then
            inventory.suckFromSlot(sides.front, perchesSourceSlot, perchesRequest)
        end
        os.sleep(1)
    end

    ::load_seeds::
    local noSeeds = true
    for i = firstSeedSlot, robot.inventorySize(), 1 do
    	if robot.count(i) ~= 0 then
    		noSeeds = false
    		goto continue 
    	end

    	local seedSlot = inventory:firstSlotWhere(sides.front, "name", seedStackName)
    	if seedSlot ~= nil then
    		noSeeds = false
    		robot.select(i)
    		inventory.suckFromSlot(sides.front, seedSlot)
    	else
    		break
    	end

    	::continue::
    end
    
    if noSeeds then
    	local message = pingTitle .. ": " .. Phrases.missedSeeds
    	local id = status.pingId .. StatusPostfix.missedSeeds
    	status:sendProblem(message)
    	utils:showError(Phrases.missedSeeds)
    	os.sleep(seedsCheckFrequency)
    	goto load_seeds
    end

    status:sendPing()
    -- Check self charge
    local limit = computer.maxEnergy() * rechargeCheckLimit
	while computer.energy() < limit do
		os.sleep(rechargingCheckFrequency)
	end

    -- Check hoe charge
    repeat
    	os.sleep(rechargingCheckFrequency)
    	local hoe = inventory.getStackInSlot(self.job.toolsChargeSide, 1)
    	local hoeLimit = hoe.maxCharge * rechargeCheckLimit
	until hoe.charge >= hoeLimit

	robot.select(hoeSlot)
	inventory.suckFromSlot(self.job.toolsChargeSide, 1)

	status:sendPing()
	navigator:runRouteReverse(self.job.toServiceRoute)
end

function planter:safeRouteToTask(task)
	local prePoint = {x = task.position.x, y = navigator.y, z = task.position.z}
	navigator:goTo(prePoint)
	navigator:goTo(task.position)
end

function planter:handleTask(task, isLast)
	self.currentTask = task
	self:safeRouteToTask(task)
	
	local toX = task.position.x + task.size.x - math.abs(task.size.x) / task.size.x
	local toZ = task.position.z + task.size.z - math.abs(task.size.z) / task.size.z
	local to = {x = toX, y = navigator.y, z = toZ}
	navigator:snakeFill(task.position, to, function() self:plantRoutine() end)

	navigator:goTo(task.position)
	self:goToService(isLast)
end

function planter:checkState()
	local seedSlot = inventory:firstInternalSlotWhere("name", seedStackName)
	if seedSlot == nil then return false end

	if robot.count(perchesSlot) == 0 then return false end

	local hoe = inventory.getStackInInternalSlot(hoeSlot)
	if hoe.charge < hoeLowLimit then return false end

	return true, seedSlot
end

function planter:plant(seedSlot, perchesInitCount)
	local perchesCount = robot.count(perchesSlot)
	if perchesCount == perchesInitCount then
		robot.select(hoeSlot)
		os.sleep(0.5)
		robot.placeDown()
		robot.select(perchesSlot)
		os.sleep(0.5)
		robot.placeDown()
	end

	robot.select(seedSlot)
	os.sleep(0.5)
	robot.placeDown()
end

function planter:searchPlantHeight(deltaX, deltaZ)
	local isEven = (deltaX + deltaZ) % 2 == 0
	local isDeep = isEven == self.currentTask.firstDeep
	if isDeep then
		robot.down()	-- Should be used robot movemen not navigator. Because when robot stay at top of harvester it can't go down.
		os.sleep(2) 
	end

	return isDeep
end

function planter:plantRoutine()
	status:sendPing()

	local deltaX = math.abs(navigator.x - self.currentTask.position.x)
	local deltaZ = math.abs(navigator.z - self.currentTask.position.z)
	local checker = function(point) 
		return point.x == deltaX and point.z == deltaZ
	end
	
	if table.haveSuccess(self.currentTask.exceptions, checker) then return end

	::state_check::
	local ready, seedSlot = self:checkState()
	if not ready then
		local currentPosition = {x = navigator.x, y = navigator.y, z = navigator.z}
		local currentFace = navigator.face
		navigator:goTo(self.currentTask.position)
		self:goToService()
		self:safeRouteToTask(self.currentTask)
		navigator:goTo(currentPosition)
		navigator:faceTo(currentFace)
		goto state_check
	end

	local perchesInitCount = robot.count(perchesSlot)
	
	::planting::
	local isDeep = self:searchPlantHeight(deltaX, deltaZ)
	self:plant(seedSlot, perchesInitCount)
	if isDeep then 
		robot.up() 
		os.sleep(2) 
	end

	if robot.count(seedSlot) ~= 0 then
		goto planting
	end
end

function planter:loadJob(jobFile)
	self.job = utils:loadFrom(jobFile)
end

function planter:startJob(serviceFirst)
	status:sendPing(true)

	local successMessage = pingTitle .. ": " .. Phrases.jobDone
	local successId = status.pingId .. StatusPostfix.jobDone
	status:cancelStatus(successId)

	if serviceFirst == nil then
		serviceFirst = true
	end

	if self.job == nil then
		utils:showError(Phrases.missedJob)
		return
	end

	if serviceFirst then
		self:goToService()
	else
		navigator:runRouteReverse(self.job.toServiceRoute)
	end

	for index, task in ipairs(self.job.tasks) do
		self:handleTask(task, index == #self.job.tasks)
	end

	local finalPoint = self.job.finalPosition
	if finalPoint ~= nil then
		navigator:goTo(finalPoint)
	end

	status:sendSuccess(successId, successMessage)
	status:cancelPing()
	computer.shutdown()
end

function planter:init()
	icExtender:extend(inventory)
	navigator:restoreState()
	
	status.pingId = inventory.address
	status.pingTitle = pingTitle
	status.pingAllowableDelay = pingDelay
end

planter:init()

return planter