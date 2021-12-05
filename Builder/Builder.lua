local utils = require ("utils")
local component = require("component")
local icExtender = require("inventory_extender")

local builder = {
	navigator = require("navigator"),
	inventory = component.inventory_controller,
	schema = {
		emptyName = "none",
		size = {x = 0, z = 0},
		codes = {},
		layers = {}
	}
}

-- Private methods

function builder:getNameInPoint(x, y, z)
	local layer = self.schema.layers[y]
	local line = layer[z]
	local code = line:sub(x, x)
	return builder.schema.codes[code]
end

function builder:verifyInventory()
	local counts = self.inventory:getCounts()
	
	local required = {}
	local layers = self.schema.layers
	for layerIndex = 1, #layers do
		local layer = layers[layerIndex]
		for lineIndex = 1, #layer do
			local line = layer[lineIndex]
			for codeIndex = 1, #line do
				local code = line:sub(codeIndex, codeIndex)
				required[code] = (required[code] or 0) + 1
			end
		end
	end

	local haveMaterials = true
	for code, count in pairs(required) do
		local name = self.schema.codes[code]
		local diff = count - (counts[name] or 0)
		if diff > 0 and name ~= self.schema.emptyName then
			print("  Need " .. tostring(diff) .. " of " .. name)
			haveMaterials = false
		end
	end
	return haveMaterials
end

-- Public methods

function builder:load(fileName)
	self.schema = utils:loadFrom(fileName)
end

function builder:build(fromBottom, verify)
	if fromBottom == nil then fromBottom = true end
	if verify == nil then verify = true end

	if verify then
		if not self:verifyInventory(self.schema) then
			return
		end
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
	self.navigator:nullify()
end

builder:init()

return builder