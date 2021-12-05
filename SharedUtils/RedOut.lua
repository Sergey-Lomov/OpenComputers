component = require("component")
sides = require("sides")

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
		result[index] = RedOut:new(nil, data.id, data.side)
	end
	return result
end

function RedOut:enable()
	local redstone = component.proxy(self.id)
	if redstone == nil then
		print("Invalid red out id: " .. self.id)
		return
	end
	redstone.setOutput(self.side, 15)
end

function RedOut:disable()
	local redstone = component.proxy(self.id)
	if redstone == nil then
		print("Invalid red out id: " .. self.id)
		return
	end
	redstone.setOutput(self.side, 0)
end