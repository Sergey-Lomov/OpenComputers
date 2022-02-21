require 'ui/utils/asserts'

Size = {}
Size.typeLabel = "Size"

function Size:new(width, height)
	typeAssert(width, "number", 1)
	typeAssert(height, "number", 2)

	local size = {}
	self.__index = self
	setmetatable(size, self)

	size.width = width
	size.height = height

	return size
end

function Size:__tostring()
	return "<Size width: " .. tostring(self.width) .. " height: " .. tostring(self.height) .. ">"
end

function Size:simpleString()
	return tostring(self.width) .. ":" .. tostring(self.height)
end