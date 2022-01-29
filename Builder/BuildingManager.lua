local utils = require ("utils")
local status = require ("status_client")
local builder = require 'builder'
local computer = require 'computer'
local navigator = builder.navigator

local configFile = "config"
local rechargingCheckFrequency = 2
local rechargeCheckLimit = 0.95
local resourcesLoadingFrequency = 15
local resourcesLoadingLimit = 4

local Phrases = {
	missedJob = "Работа не загружена",
	toSupportFromUnknown = "Попытка перейти в зону поддержки из неизвестной зоны",
	toWorkFromUnknown = "Попытка перейти в рабочую зону из неизвестной зоны",
	missedCharging = "Не указаны детали зарядки",
	missedChargingPoint = "Не указана точка зарядки",
	missedLoading = "Не указаны детали загрузки",
	missedLoadingPoint = "Не указана точка загрузки",
	missedLoadingFace = "Не указано направление загрузки",
	missedTasks = "Планируемая работа не содержит задач",
	missedFirstTaskSchema = "Не указана схема для первой задачи",
	missedFirstTaskFace = "Не указано направление (face) для первой задачи",
	missedTaskPosition = "Не указана позиция задачи #",
	
	notEnoughResources = "Недостаточно ресурсов для строительства",
	jobDone = "Постройка завевршена",
}

Status = {
	missedResourcesId = "builder_missed_resources",
	jobDoneId = "builder_job_done",
	defaultTitle = "Строитель"
}

local Areas = {
	SUPPORT = 1,
	WORK = 2
}

local manager = {
	job = nil,
	currentArea = Areas.SUPPORT
}

function manager:goToSupportArea()
	if self.currentArea == Areas.SUPPORT then
		navigator:goTo(self.job.supportPoint)
	elseif self.currentArea == Areas.WORK then
		navigator:goTo(self.job.workAreaPoint)
		navigator:runRouteReverse(self.job.supportToWorkRoute)
		navigator:goTo(self.job.supportPoint)
		self.currentArea = Areas.SUPPORT
	else
		utils:showError(Phrases.toSupportFromUnknown)
	end
end

function manager:goToWorkArea()
	if self.currentArea == Areas.WORK then
		navigator:goTo(self.job.workAreaPoint)
	elseif self.currentArea == Areas.SUPPORT then
		navigator:goTo(self.job.supportPoint)
		navigator:runRoute(self.job.supportToWorkRoute)
		navigator:goTo(self.job.workAreaPoint)
		self.currentArea = Areas.WORK
	else
		utils:showError(Phrases.toWorkFromUnknown)
	end
end

function manager:recharge()
	local prePoint = self.job.recharging.pre
	if prePoint ~= nil then
		navigator:goTo(prePoint)
	end

	navigator:goTo(self.job.recharging.point)
	
	local limit = computer.maxEnergy() * rechargeCheckLimit
	while computer.energy() < limit do
		os.sleep(rechargingCheckFrequency)
	end

	local postPoint = self.job.recharging.post
	if postPoint ~= nil then
		navigator:goTo(postPoint)
	end
end

function manager:updateResources(withLoading)
	if withLoading == nil then withLoading = true end
	local prePoint = self.job.loading.pre
	if prePoint ~= nil then
		navigator:goTo(prePoint)
	end

	navigator:goTo(self.job.loading.point)
	navigator:faceTo(self.job.loading.face)

	builder:unloadResources()

	if not withLoading then return end

	local counter = 0
	while not builder:loadResources() do
		counter = counter + 1
		if counter >= resourcesLoadingLimit then
			local title = status.pingTitle or Status.defaultTitle
			local message = title .. ": " .. Phrases.notEnoughResources
			status:sendProblem(Status.missedResourcesId, message)
		end
		os.sleep(resourcesLoadingFrequency)
	end

	status:cancelStatus(Status.missedResourcesId)

	local postPoint = self.job.loading.post
	if postPoint ~= nil then
		navigator:goTo(postPoint)
	end
end

function manager:validateJob(job)
	local isValid = true

	if job.recharging == nil then
		utils:showError(Phrases.missedCharging)
		isValid = false
	elseif job.recharging.point == nil then 
		utils:showError(Phrases.missedChargingPoint)
		isValid = false
	end

	if job.loading == nil then
		utils:showError(Phrases.missedLoading)
		isValid = false
	else
		if job.loading.point == nil then 
			utils:showError(Phrases.missedLoadingPoint)
			isValid = false
		end

		if job.loading.face == nil then 
			utils:showError(Phrases.missedLoadingFace)
			isValid = false
		end
	end

	if job.tasks == nil or #job.tasks == 0 then 
		utils:showError(Phrases.missedTasks)
		isValid = false
	end

	if job.tasks[1].schema == nil then
		utils:showError(Phrases.missedFirstTaskSchema)
		isValid = false
	end

	if job.tasks[1].schema == nil then
		utils:showError(Phrases.missedFirstTaskFace)
		isValid = false
	end

	for index, task in ipairs(job.tasks) do
		if task.position == nil then
			utils:showError(Phrases.missedTaskPosition .. tostring(index))
			isValid = false
		end
	end

	return isValid
end

function manager:loadJob(jobFile)
	local job = utils:loadFrom(jobFile)
	
	if not self:validateJob(job) then return false end

	self.job = job
	self.job.supportPoint = self.job.supportPoint or self.job.recharging.point
	self.job.workAreaPoint = self.job.workAreaPoint or self.job.tasks[1].position
	self.job.supportToWorkRoute = self.job.supportToWorkRoute or {self.job.supportPoint, self.job.workAreaPoint}

	return true
end

function manager:handleTask(task, last)
	self:goToSupportArea()
	self:recharge()

	if task.schema ~= nil then last.schema = task.schema end
	if task.fromBottom ~= nil then last.fromBottom = task.fromBottom end
	if task.face ~= nil then last.face = task.face end
	
	builder:load(last.schema)
	self:updateResources()
	self:goToWorkArea()

	local prePoint = {x = task.position.x, y = navigator.y, z = task.position.z}
	navigator:goTo(prePoint)
	builder:build(last.fromBottom, false, task.position, last.face)
end

function manager:startJob()
	if self.job == nil then
		utils:showError(Phrases.missedJob)
		return
	end

	status:sendPing(true)

	self.currentArea = Areas.SUPPORT
	local last = {
		schema = self.job.tasks[1].schema,
		face = self.job.tasks[1].face,
		fromBottom = self.job.tasks[1].fromBottom or false
	}

	for _, task in ipairs(self.job.tasks) do
		self:handleTask(task, last)
	end

	self:goToSupportArea()
	self:updateResources(false)
	
	local robotTitle = status.pingTitle or Status.defaultTitle
	local message = robotTitle .. ": " .. Phrases.jobDone
	status:sendSuccess(Status.jobDoneId, message)
	status:cancelPing()
	computer.shutdown()
end

function manager:init()
	local config = utils:loadFrom(configFile)
	status.pingId = inventory.address
	status.pingTitle = config.pingTitle

	builder.onPositionHandling = function()
		status:sendPing()
	end
end

manager:init()

return manager