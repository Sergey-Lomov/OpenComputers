require 'extended_table'

local utils = require 'utils'
local component = require 'extended_component'
local status = require 'status_client'

local queue = {
	waitingRequests = {},
	craftingRequests = {},
	config = {},				-- Should be configured outside
	interface = nil,			-- Should be configured outside
	timer = nil,

	-- Callbacks
	onMissedRecipe = nil,		-- Should be configured outside. Function with 1 arg - request.
	onNBTRecipe = nil,			-- Should be configured outside. Function with 1 arg - request.
	onFoundRecipe = nil,		-- Should be configured outside. Function with 1 arg - request.	
	onCraftingExtratime = nil,	-- Should be configured outside. Function with 1 arg - request.
	onHandlingExtratime = nil,	-- Should be configured outside. Function with 1 arg - request.
	onCraftingFinish = nil,		-- Should be configured outside. Function with 1 arg - request.
	onCraftingStart = nil,		-- Should be configured outside. Function with 1 arg - request.
}

function queue:getFreeCpus()
	if self.interface == nil then
		utils:showError("ME Queue: try to request cpus with nil interface")
		return {}
	end

	local whitelist = self.config.cpuWhitelist
	local blacklist = self.config.cpuBlacklist or {}

	local validator = function(cpu)
		local white = true
		if whitelist ~= nil then
			white = table.containsValue(whitelist, cpu.name)
		end
		local black = table.containsValue(blacklist, cpu.name)

		return white and not black and not cpu.busy
	end

	local cpus = self.interface.getCraftingCPUs()
	return table.filteredArray(cpus, validator)
end

function queue:handleRequests()
	self:handleWaitingRequests()
	self:handleCraftingRequests()
end

function queue:handleWaitingRequests()
	local cpus = self:getFreeCpus()
	local skipped = 0
	while #self.waitingRequests - skipped > 0 and #cpus ~= 0 do
		local success = self:tryToStartRequest(self.waitingRequests[1], cpus)
		if not success then
			skipped = skipped + 1
		end
	end
end

function queue:tryToStartRequest(request, cpus)
	local craftables = self.interface.getCraftables(request.filter)
	local timeLimit = self.config.maxHandlingTime or math.huge
	request.handlingTime = request.handlingTime or utils:realWorldSeconds()

	if #craftables == 0 then
		if self.onMissedRecipe ~= nil then
			self.onMissedRecipe(request)
			return false
		end
	end

	if #craftables > 1 then
		if self.onNBTRecipe ~= nil then
			self.onNBTRecipe(request)
			return false
		end
	end

	if self.onFoundRecipe ~= nil then
		self.onFoundRecipe(request)
	end

	for index, cpu in ipairs(cpus) do
		local status = craftables[1].request(request.amount, true, cpu.name)
		if status.isCanceled() == false then
			request.craftingTime = utils:realWorldSeconds()
			request.status = status

			table.removeByValue(self.waitingRequests, request)
			table.insert(self.craftingRequests, request)
			table.remove(cpus, index)

			if self.onCraftingStart ~= nil then
				self.onCraftingStart(request)
			end

			return true
		end
	end

	local currenTime = utils:realWorldSeconds()
	if currenTime - request.handlingTime > timeLimit then
		if self.onHandlingExtratime ~= nil then
			self.onHandlingExtratime(request)
		end
	end

	return false
end

function queue:handleCraftingRequests()
	local timeLimit = self.config.maxCraftingTime or math.huge
	local currenTime = utils:realWorldSeconds()

	for index, request in ipairs(self.craftingRequests) do
		local status = request.status
		if status.isCanceled() or status.isDone() then
			table.remove(self.craftingRequests, index)
			if self.onCraftingFinish ~= nil then
				self.onCraftingFinish(request)
			end
		else
			if currenTime - request.craftingTime > timeLimit then
				if self.onCraftingExtratime ~= nil then
					self.onCraftingExtratime(request)
				end
			end
		end
	end
end

function queue:addRequest(fingerprint, amount, total, priority)
	local filter = {
		name = fingerprint.id,
		label = fingerprint.title,
		damage = fingerprint.damage,
	}
	
	-- Check does this item already in waiting queue
	for _, waiting in ipairs(self.waitingRequests) do
		local f = waiting.filter
		if f.name == filter.name and f.label == filter.label and f.damage == filter.damage then
			waiting.amount = amount
			if waiting.priority ~= priority then
				waiting.priority = priority
				self:reorderWaitingRequests()
			end
			return
		end
	end

	-- Check does this item already at crafting
	for _, crafting in ipairs(self.craftingRequests) do
		local f = crafting.filter
		if f.name == filter.name and f.label == filter.label and f.damage == filter.damage then
			local amountLeft = total - crafting.amount
			if amountLeft <= 0 then return end
			amount = math.min(amount, amountLeft)
		end
	end

	local request = {}
	request.addingTime = utils:realWorldSeconds()
	request.filter = filter
	request.amount = amount
	request.priority = priority

	table.insert(self.waitingRequests, request)

	self:reorderWaitingRequests()
	self:handleRequests()
end

function queue:reorderWaitingRequests()
	local sorter = function(r1, r2)
		if r1.priority ~= r2.priority then
			return r1.priority > r2.priority
		else
			return r1.addingTime > r2.addingTime
		end
	end
	
	table.sort(self.waitingRequests, sorter)
end

function queue:start()
	local routine = function()
		self:handleRequests()
	end

	self.timer = event.timer(self.config.frequency, routine, math.huge)
end

function queue:stop()
	if self.timer ~= nil then
		event.cancel(self.timer)
	end
end

return queue