require 'extended_table'
require 'items_config_fingerprint'

local utils = require 'utils'
local component = require 'extended_component'
local status = require 'status_client'

local managerConfigFile = "meManagerConfig"
local itemsConfigFile = "meItemsConfig"
local unspecifiedSestroySide = "NONE"
local statusHistoryPerItem = 2 -- Each item may produce problem or warning about amount and another one problem or warning about crafting state

local StatusPostfix = {
	amountProblem = "_amountProblem",
	amountWarning = "_amountWarning",
	noItemWarning = "_noItemWarning",
	extraHandling = "_extraHandling",
	extraCrafting = "_extraCrafting",
	noRecipe = "_noRecipe",
	manyRecipes = "_manyRecipes",
}

local Phrases = {
	problemItemLevel = "Критический уровень %s : %d",
	warningItemLevel = "Низкий уровень %s : %d",
	warningMissedItem = "Нет данных о ",
	manyRecipes = "Найдено несколько рецептов для %s (NBT)",
	noRecipe = "Не найден рецепт для %s",
	extraHandling = "Невозможно начать крафт %s (%d мин)",
	extraCrafting = "Создание %s длится уже %d мин",
	loadingItemMissed = "МЕ в состоянии загрузки.\nРабота приостановлена."
}

local manager = {
	managerConfig = {},
	itemsConfig = {},
	queue = require 'me_crafting_queue',
	managerConfigUpdated = false,
	itemsConfigUpdated = false,
	chest = nil,
	interface = nil,
	routineTimer = nil,
	isDestroyConfigured = false,
	problem = nil,
	prevalues = {}, -- Previous amount of items
	expectedItems = {} -- List of items, which prbably will be returned to ME. When user take stack of half of ctak to create pattern or put few into inventory.
}

local function chestStackToViev(stack)
	return {
		id = stack.id,
		title = stack.display_name,
		nbtHash = stack.nbt_hash,
		amount = stack.qty,
		damage = stack.dmg
	}
end

function manager:updateManagerConfig()
	self.managerConfig = utils:loadFrom(managerConfigFile, {loadingTestItem = ItemsConfigFingerprint})
	self.managerConfigUpdated = true
	self.queue.config = self.managerConfig.queue
	
	local modem = component.modem
	if modem.isWireless() then
		modem.setStrength(self.managerConfig.modemStrength)
	end

	return self:setupSystemElements()
end

function manager:updateItemsConfig()
	self.itemsConfig = utils:loadFrom(itemsConfigFile, {fingerprint = ItemsConfigFingerprint})
	self.itemsConfigUpdated = true
	status.historyLimit = #self.itemsConfig * statusHistoryPerItem 
end

function manager:chestItems()
	local viewModels = {}
	local stacks = self.chest.getAllStacks(false)
	for i = 1, #stacks do
		local viewModel = chestStackToViev(stacks[i])
		table.insert(viewModels, viewModel)
	end

	return viewModels
end

function manager:chestItem(index)
	local stack = self.chest.getStackInSlot(index)
	return chestStackToViev(stack)
end

function manager:setLoadingTestItem(fingerprint)
	self.managerConfig.loadingTestItem = fingerprint
	utils:saveTo(managerConfigFile, self.managerConfig)
end

function manager:setItemConfig(fingerprint, config)
	if fingerprint == nil or config == nil then return end

	local existNode = table.filteredByKeyValue(self.itemsConfig, "fingerprint", fingerprint)[1]
	
	if existNode ~= nil then
		existNode.config = config
	else
		local node = {fingerprint = fingerprint, config = config}
		table.insert(self.itemsConfig, node)
	end

	utils:saveTo(itemsConfigFile, self.itemsConfig)
end

function manager:additoinalCasesCheck(item, fingerprint)
	local stringFingerprint = fingerprint:toString()
	local prevalue = self.prevalues[stringFingerprint]
	if prevalue == nil then 
		self.prevalues[stringFingerprint] = item.qty
		return false 
	end

	-- Additional check for case when ME chunk was unloaded at middle of items handling
	if prevalue ~= 0 and (item == nil or item.qty == 0) then
		if not self:checkMEState() then return false end
	end

	-- Check for prevent recraft of items, when user take stack (or half, or all) to place few into inventory and return another.
	local delta = prevalue - item.qty
	local tapSize = math.min(prevalue, item.max_size)
	local estimatedToReturn = delta == tapSize or delta == tapSize / 2
	local isExpected = table.containsValue(self.expectedItems, stringFingerprint)

	self.prevalues[stringFingerprint] = item.qty
	if estimatedToReturn and not isExpected then
		tabel.insert(self.expectedItems, stringFingerprint) 
		return false
	end

	if isExpected then table.removeByValue(stringFingerprint) end

	return true
end

function manager:handleItem(fingerprint, config)
	local item = self.interface.getItemDetail(fingerprint:toMEFormat(), false)

	-- For case when item and craft was moved out from ME.
	local missedItemId = fingerprint.id .. StatusPostfix.noItemWarning
	if item == nil then
		utils:pr(fingerprint:toMEFormat()) 
		local message = Phrases.warningMissedItem .. fingerprint.title
		status:sendWarning(missedItemId, message)
		return 
	else
		status:cancelStatus(missedItemId)
	end

	if not self:additoinalCasesCheck(item, fingerprint) then return end

	self:handleItemStatuses(fingerprint, config, item)
	self:handleItemDestroy(fingerprint, config, item)
	self:handleItemCraft(fingerprint, config, item)
end

function manager:handleItemStatuses(fingerprint, config, item)
	local amount = item.qty

	local problemLimit = config.problem or -1
	local problemId = fingerprint.id .. StatusPostfix.amountProblem
	if amount <= problemLimit then
		local message = string.format(Phrases.problemItemLevel, item.display_name, amount)
		status:sendProblem(problemId, message)
	else 
		status:cancelStatus(problemId, true)
	end

	local warningLimit = config.warning or -1
	local warningId = fingerprint.id .. StatusPostfix.amountWarning
	if amount <= warningLimit and amount > problemLimit then
		local message = string.format(Phrases.warningItemLevel, item.display_name, amount)
		status:sendWarning(warningId, message)
	else 
		status:cancelStatus(warningId, true)
	end
end

function manager:handleItemDestroy(fingerprint, config, item)
	if config.destroy == nil then return end
	if not self.isDestroyConfigured then return end

	local amount = item.qty
	local maxPortion = item.max_size
	local destroyAmount = amount - config.destroy
	local side = self.managerConfig.destroySide

	while destroyAmount > 0 do 
		local portion = math.min(maxPortion, destroyAmount)
		local result = self.interface.exportItem(fingerprint:toMEFormat() , side, portion)
		if result.size == 0 then
			return -- If interface can export any item, manager should stop to try to expot items
		end
		destroyAmount = destroyAmount - result.size
	end
end

function manager:handleItemCraft(fingerprint, config, item)
	if config.craft == nil then return end
	local amount = item.qty
	local limit = config.craft.limit or 0

	if amount >= limit then return end
	local portion = config.craft.portion or math.huge
	local totalAmount = config.craft.limit - amount
	local requestAmount = math.min(portion, totalAmount)
	self.queue:addRequest(fingerprint, requestAmount, totalAmount, config.craft.priority)
end

-- Check is ME network loaded (after chank unloading)
function manager:checkMEState()
	local testMEFingerprint = self.managerConfig.loadingTestItem:toMEFormat()
	local testDetails = self.interface.getItemDetail(testMEFingerprint, false)
	if testDetails == nil or testDetails.qty == 0 then
		self.problem = Phrases.loadingItemMissed
		return false
	end

	return true
end

function manager:routine()
	self.problem = nil
	
	if not self.managerConfigUpdated then
		self:stop()
		self:start(false)
	end

	if not self.itemsConfigUpdated then
		self:updateItemsConfig()
	end

	if not self:checkMEState() then return end

	if #self.queue:permittedCpus() == 0 then
		return
	end

	for _, node in ipairs(self.itemsConfig) do
		self:handleItem(node.fingerprint, node.config)
		if self.problem ~= nil then break end
	end
end

function manager:configureQueueCallbacks()

	self.queue.onHandlingExtratime = function(request)
		local id = request.filter.name .. StatusPostfix.extraHandling
		local duration = (utils:realWorldSeconds() - request.handlingTime) / 60
		local message = string.format(Phrases.extraHandling, request.filter.label, duration)
		status:sendWarning(id, message)
	end

	self.queue.onCraftingExtratime = function(request)
		local id = request.filter.name .. StatusPostfix.extraCrafting
		local duration = (utils:realWorldSeconds() - request.handlingTime) / 60
		local message = string.format(Phrases.extraCrafting, request.filter.label, duration)
		status:sendWarning(id, message)
	end

	self.queue.onCraftingStart = function(request)
		local id = request.filter.name .. StatusPostfix.extraHandling
		status:cancelStatus(id)
	end

	self.queue.onCraftingFinish = function(request)
		local id = request.filter.name .. StatusPostfix.extraCrafting
		status:cancelStatus(id)
	end

	self.queue.onNBTRecipe = function(request)
		local id = request.filter.name .. StatusPostfix.manyRecipes
		local message = string.format(Phrases.manyRecipes, request.filter.label)
		status:sendProblem(id, message)
	end

	self.queue.onMissedRecipe = function(request)
		local id = request.filter.name .. StatusPostfix.noRecipe
		local message = string.format(Phrases.noRecipe, request.filter.label)
		status:sendProblem(id, message)
	end

	self.queue.onFoundRecipe = function(request)
		local nbtRecipesId = request.filter.name .. StatusPostfix.manyRecipes
		local noRecipeId = request.filter.name .. StatusPostfix.noRecipe
		status:cancelStatus(nbtRecipesId)
		status:cancelStatus(noRecipeId)
	end
end

function manager:setupSystemElements()
	self.interface = component.safePrimary("me_interface")
	if self.interface == nil then
		utils:showError("Can't find ME interface")
		return false
	end
	self.queue.interface = self.interface

	local validSides = {"UP", "DOWN", "NORTH", "SOUTH", "EAST", "WEST", unspecifiedSestroySide}
	local destroySide = self.managerConfig.destroySide or "[missed]"
	if not table.containsValue(validSides, destroySide) then
		utils:showError("Invalid destroy side: " .. destroySide .. ", you may use " .. unspecifiedSestroySide)
		self.isDestroyConfigured = false
		return false
	end

	if destroySide == unspecifiedSestroySide then
		self.isDestroyConfigured = false
	elseif self.interface.canExport(destroySide) then
		self.isDestroyConfigured = true
	else
		self.isDestroyConfigured = false
		utils:showWarning("Impossible to export items to destroy side: " .. destroySide)
	end

	self.chest = component.safePrimary(self.managerConfig.chestType)
	if self.chest == nil then
		utils:showError("Can't find chest")
		return false
	end

	return true
end

function manager:start(immideatelyIteration)
	immideatelyIteration = immideatelyIteration or true

	if not self:updateManagerConfig() then
		return false
	end

	if self.managerConfig.loadingTestItem == nil then
		utils:showError("Loading test item not configured")
		return false
	end

	local routine = function()
		manager:routine()
	end

	self.routineTimer = event.timer(self.managerConfig.frequency, routine, math.huge)
	if immideatelyIteration then
		routine()
	end

	self.queue:start()

	return false
end

function manager:stop()
	if self.routineTimer ~= nil then
		event.cancel(self.routineTimer)
	end
	self.routineTimer = nil

	self.queue:stop()
end

function manager:init()
	self:updateManagerConfig()
	self:updateItemsConfig()
	self:configureQueueCallbacks()
end

manager:init()

return manager