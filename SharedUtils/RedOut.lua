local component = require("component")
local sides = require("sides")

local maxPower = 15

RedOut = {
	id = "",
	side = sides.north
}

function RedOut:new(obj, id, side)
	obj = obj or {}
	setmetatable(obj, self)
	self.__index = self
	obj.id = id or ""
	obj.side = side or sides.north
	return obj
end

function RedOut:fromRaw(data)
	return RedOut:new(nil, data.id, data.side)
end

function RedOut:fromRawArray(array)
	local result = {}
	for index, data in pairs(array) do
		table.insert(result, RedOut:fromRaw(data))
	end
	return result
end

function RedOut:enable()
	local redstone = component.proxy(self.id)
	if redstone == nil then
		print("Invalid red out id: " .. self.id)
		return
	end
	redstone.setOutput(self.side, maxPower)
end

function RedOut:disable()
	local redstone = component.proxy(self.id)
	if redstone == nil then
		print("Invalid red out id: " .. self.id)
		return
	end
	redstone.setOutput(self.side, 0)
end

function RedOut:invert()
	local redstone = component.proxy(self.id)
	if redstone == nil then
		print("Invalid red out id: " .. self.id)
		return
	end
	local current = redstone.getOutput(self.side)
	redstone.setOutput(self.side, maxPower - current)
end

function RedOut.enableAllIn(array)
	for _, out in ipairs(array) do
		out:enable()
	end
end

function RedOut.disableAllIn(array)
	for _, out in ipairs(array) do
		out:disable()
	end
end

function RedOut.setStatusForAll(status, array)
	local func = status and RedOut.enableAllIn or RedOut.disableAllIn
	func(array)
end

function RedOut.invertAll(array)
	for _, out in ipairs(array) do
		out:invert()
	end
end