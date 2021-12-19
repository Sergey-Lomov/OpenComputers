require 'extended_table'
require 'items_config_fingerprint'

local utils = require 'utils'
local component = require 'extended_component'
local status = require 'status_client'
queue = require 'me_crafting_queue'

local managerConfigFile = "meManagerConfig"
local itemsConfigFile = "meItemsConfig"

local StatusPostfix = {
	amountProblem = "_amountProblem",
	amountWarning = "_amountWarning",
	extraHandling = "_extraHandling",
	extraCrafting = "_extraCrafting",
	noRecipe = "_noRecipe",
	manyRecipes = "_manyRecipes",
}

local Phrases = {
	problemItemLevel = "Критический уровень %s : %d",
	warningItemLevel = "Низкий уровень %s : %d",
	manyRecipes = "Найдено несколько рецептов для %s (NBT)",
	noRecipe = "Не найден рецепт для %s",
	extraHandling = "Не найден CPU для %s (%d мин)",
	extraCrafting = "Создание %s длится уже %d мин"
}

local manager = {
	managerConfig = {},
	itemsConfig = {},
	managerConfigUpdated = false,
	itemsConfigUpdated = false,
	chest = nil,
	interface = nil,
	routineTimer = nil,
	isDestroyConfigured = false
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
	self.managerConfig = utils:loadFrom(managerConfigFile)
	self.managerConfigUpdated = true
	queue.config = self.managerConfig.queue
	return self:setupSystemElements()
end

function manager:updateItemsConfig()
	self.itemsConfig = utils:loadFrom(itemsConfigFile, {fingerprint = ItemsConfigFingerprint})
	self.itemsConfigUpdated = true
	status.historyLimit = #self.itemsConfig * 2 -- Each item may produce problem or warning about amount and another one problem or warning about crafting state
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

function manager:setItemConfig(fingerprint, config)
	local existNode = table.filteredByKeyValue(self.itemsConfig, "fingerprint", fingerprint)[1]
	
	if existNode ~= nil then
		existNode.config = config
	else
		local node = {fingerprint = fingerprint, config = config}
		table.insert(self.itemsConfig, node)
	end

	utils:saveTo(itemsConfigFile, self.itemsConfig)
end

function manager:handleItem(fingerprint, config)
	local item = self.interface.getItemDetail(fingerprint:toMEFormat(), false)

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

	while destroyAmount > 0 do 
		local portion = math.min(maxPortion, destroyAmount)
		local result = self.interface.exportItem(self.managerConfig.destroySide)
		if result.size == 0 then
			return -- If interface can export any item, manager should stop to try to expot items
		end
		destroyAmount = destroyAmount - result.size
	end
end

function manager:handleItemCraft(fingerprint, config, item)
	if config.craft == nil then return end
	local amount = item.qty

	if amount >= config.craft.limit then return end
	local portion = config.craft.portion or math.huge
	local totalAmount = config.craft.limit - amount
	local requestAmount = math.min(portion, totalAmount)
	queue:addRequest(fingerprint, requestAmount, totalAmount, config.craft.priority)
end

function manager:routine()
	if not self.managerConfigUpdated then
		self:stop()
		self:start(false)
	end

	if not self.itemsConfigUpdated then
		self:updateItemsConfig()
	end

	for _, node in ipairs(self.itemsConfig) do
		self:handleItem(node.fingerprint, node.config)
	end
end

function manager:configureQueueCallbacks()

	queue.onHandlingExtratime = function(request)
		local id = request.filter.name .. StatusPostfix.extraHandling
		local duration = (utils:realWorldSeconds() - request.handlingTime) / 60
		local message = string.format(Phrases.extraHandling, request.filter.label, duration)
		status:sendWarning(id, message)
	end

	queue.onCraftingExtratime = function(request)
		local id = request.filter.name .. StatusPostfix.extraCrafting
		local duration = (utils:realWorldSeconds() - request.handlingTime) / 60
		local message = string.format(Phrases.extraCrafting, request.filter.label, duration)
		status:sendWarning(id, message)
	end

	queue.onCraftingStart = function(request)
		local id = request.filter.name .. StatusPostfix.extraHandling
		status:cancelStatus(id)
	end

	queue.onCraftingFinish = function(request)
		local id = request.filter.name .. StatusPostfix.extraCrafting
		status:cancelStatus(id)
	end

	queue.onNBTRecipe = function(request)
		local id = request.filter.name .. StatusPostfix.manyRecipes
		local message = string.format(Phrases.manyRecipes, request.filter.label)
		status:sendProblem(id, message)
	end

	queue.onMissedRecipe = function(request)
		local id = request.filter.name .. StatusPostfix.noRecipe
		local message = string.format(Phrases.noRecipe, request.filter.label)
		status:sendProblem(id, message)
	end

	queue.onFoundRecipe = function(request)
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
	queue.interface = self.interface

	local validSides = {"UP", "DOWN", "NORTH", "SOUTH", "EAST", "WEST"}
	local destroySide = self.managerConfig.destroySide or "[missed]"
	if not table.containsValue(validSides, destroySide) then
		utils:showError("Invalid destroy side: " .. destroySide)
		self.isDestroyConfigured = false
		return false
	end

	if self.interface.canExport(destroySide) then
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

	local routine = function()
		manager:routine()
	end

	self.routineTimer = event.timer(self.managerConfig.frequency, routine, math.huge)
	if immideatelyIteration then
		routine()
	end

	queue:start()

	return false
end

function manager:stop()
	if self.routineTimer ~= nil then
		event.cancel(self.routineTimer)
	end
	self.routineTimer = nil

	queue:stop()
end

function manager:init()
	self:updateManagerConfig()
	self:updateItemsConfig()
	self:configureQueueCallbacks()
end

manager:init()

return manager