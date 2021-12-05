local component = require("component")

local generator = {
	inventory = component.inventory_controller
}

local templateChar = "T"

function generator:fill(point1, point2)
	local sizeX = point2.x - point1.x + 1
	if sizeX <= 0 then
		print("FAIL: Point2 x less then point1 x")
		return nil
	end

	local sizeY = point2.y - point1.y + 1
	if sizeY <= 0 then
		print("FAIL: Point2 y less then point1 y")
		return nil
	end

	local sizeZ = point2.z - point1.z + 1
	if sizeZ <= 0 then
		print("FAIL: Point2 z less then point1 z")
		return nil
	end

	local stack = self.inventory.getStackInInternalSlot(1)
	if stack == nil then
		print("FAIL: First slot is empty")
		return nil
	end

	schema = {
		emptyName = "none",
		size = {x = sizeX, z = sizeZ},
		codes = {
			[" "] = "none",
		},
		layers = {}
	}

	schema.codes[templateChar] = stack.name

	for y = 1, sizeY do
		local layer = {}
		for z = 1, sizeZ do
			line = string.rep(templateChar, sizeX)
			layer[z] = line
		end

		schema.layers[y] = layer
	end

	return schema
end

return generator