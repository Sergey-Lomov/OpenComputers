local utils = require ("utils")
local component = require("component")
local sides = require("sides")
local icExtender = require("ic_extender")

local Errors = {
	missedSchemeOnResourcesLoading = "Попытка загрузить ресуры до выбора схемы",
	missedResourcesBase = "Не обнаружена ресурсная база",
	missedResources = "Недостаточно ресурсов для строительства"
}

local builder = {
	navigator = require("navigator"),
	inventory = component.inventory_controller,
	schema = nil
}

-- Private methods

function builder:getNameInPoint(x, y, z)
	local layer = self.schema.layers[y]
	local line = layer[z]
	local code = line:sub(x, x)
	return builder.schema.codes[code]
end

function builder:requiredResources()
	if self.schema == nil then return {} end

	local requiredByCodes = {}
	local layers = self.schema.layers
	for layerIndex = 1, #layers do
		local layer = layers[layerIndex]
		for lineIndex = 1, #layer do
			local line = layer[lineIndex]
			for codeIndex = 1, #line do
				local code = line:sub(codeIndex, codeIndex)
				requiredByCodes[code] = (requiredByCodes[code] or 0) + 1
			end
		end
	end

	local requiredByNames = {}
	for code, count in pairs(requiredByCodes) do
		local name = self.schema.codes[code]
		if name ~= self.schema.emptyName then
			requiredByNames[name] = count
		end
	end

	return requiredByNames
end

function builder:verifyInventory()
	local counts = self.inventory:getCounts()
	local required = self:requiredResources()

	local enoughtResources = true
	for name, count in pairs(required) do
		local diff = count - (counts[name] or 0)
		if diff > 0 then
			print("  Need " .. tostring(diff) .. " of " .. name)
			enoughtResources = false
		end
	end
	return enoughtResources
end

-- Public methods

function builder:load(fileName)
	self.schema = utils:loadFrom(fileName)
end

function builder:build(fromBottom, verify, fromPosition, faceCode)
	if fromBottom == nil then fromBottom = true end
	if verify == nil then verify = true end

	if verify then
		if not self:verifyInventory(self.schema) then
			return
		end
	end

	if fromPosition ~= nil then
		self.navigator:goTo(fromPosition)
		self.navigator:faceTo(faceCode or 0)
	end

	self.navigator.x = 1
	self.navigator.y = 0
	self.navigator.z = self.schema.size.z

	local routine = function()
		local placeY = self.navigator.y
		if not fromBottom then
			placeY = placeY + 2
		end

		local name = self:getNameInPoint(self.navigator.x, placeY, self.navigator.z)
		if name == self.schema.emptyName then return end

		local slot = self.inventory:firstInternalSlotWhere("name", name)
		while slot == nil do
			print("Need more " .. name)
			os.sleep(1)
			slot = self.inventory:firstInternalSlotWhere("name", name)
		end
		robot.select(slot)

		if fromBottom then
			robot.placeDown()
		else
			robot.placeUp()
		end
	end

	for yIterator = 1, #self.schema.layers do
		local y = yIterator
		if not fromBottom then
			y = #self.schema.layers - yIterator - 1
		end

		local from = {x = 1, y = y, z = self.schema.size.z}
		local to = {x = self.schema.size.x, y = y, z = 1}
		self.navigator:snakeFill(from, to, routine)
	end
end

function builder:init()
	icExtender:extend(self.inventory)
	self.navigator:restoreState()
end

function builder:loadResources(verbose)
	verbose = verbose or true

	if self.schema == nil then
		if verbose then print(Errors.missedSchemeOnResourcesLoading) end
		return false, Errors.missedSchemeOnResourcesLoading
	end

	local side = sides.front

	local inventorySize = self.inventory.getInventorySize(side)
	if type(inventorySize) ~= "number" then
		if verbose then print(Errors.missedResourcesBase) end
		return false, Errors.missedResourcesBase
	end

	local resources = self:requiredResources()
	local alreadyHave = self.inventory:getCounts()
	for name, count in pairs(alreadyHave) do
		local required = resources[name]
		if required ~= nil then
			resources[name] = required - count
		end
	end

	for i = 1, inventorySize, 1 do
		local stack = self.inventory.getStackInSlot(side, i)
		if stack == nil then goto continue end
		
		local required = resources[stack.name]
		if required == nil or required == 0 then goto continue end

		local suckSize = math.min(required, stack.size)
		self.inventory.suckFromSlot(side, i, suckSize)
		resources[stack.name] = required - suckSize

		::continue::
	end

	local readyToBuild = true
	for resource, required in pairs(resources) do
		if required ~= 0 then
			if verbose then
				if readyToBuild then print(Errors.missedResources) end
				print("\t" .. resource .. "\t" .. required)
			end
			readyToBuild = false
		end
	end

	if not readyToBuild then 
		return false, Errors.missedResources
	end

	return true
end

builder:init()

return builder