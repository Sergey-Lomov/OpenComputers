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

function builder:getCodeInPoint(x, y, z)
	local layer = self.schema.layers[y]
	local line = layer[z]
	local code = line:sub(x, x)
	return code
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

	local start = {x = self.navigator.x, y = self.navigator.y, z = self.navigator.z}

	local routine = function()
		local x = math.abs(self.navigator.x - start.x) + 1
		local y = self.navigator.y - start.y
		local z = self.schema.size.z - math.abs(self.navigator.z - start.z)

		if fromBottom then
			y = y + 2
		end

		self:handlePosition(x, y, z)
	end

	for yIterator = 1, #self.schema.layers do
		local y = start.y + yIterator
		if fromBottom then
			y = start.y + #self.schema.layers - yIterator - 1
		end

		local maxX = start.x + self.schema.size.x - 1
		local maxZ = start.z + self.schema.size.z - 1
		local from = {x = start.x, y = y, z = maxZ}
		local to = {x = maxX, y = y, z = start.z}
		self.navigator:snakeFill(from, to, routine)
	end
end

function builder:useUp()
	self.inventory.equip()
	os.sleep(0.05)
	robot.useUp()
	self.inventory.equip()
end

function builder:useDown()
	self.inventory.equip()
	os.sleep(0.05)
	robot.useDown()
	self.inventory.equip()
end

function builder:handlePosition(x, y, z, fromBottom)
	local code = self:getCodeInPoint(x, y, z)
	local name = builder.schema.codes[code]
	if name == self.schema.emptyName then return end

	local slot = self.inventory:firstInternalSlotWhere("name", name)
	while slot == nil do
		print("Need more " .. name)
		os.sleep(1)
		slot = self.inventory:firstInternalSlotWhere("name", name)
	end
	robot.select(slot)

	local usable = self.schema.usable[code] or false
	if not fromBottom then
		if usable then
			self:useDown()
		else
			robot.placeDown()
		end
	else
		if usable then
			self:useUp()
		else
			robot.placeUp()
		end
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