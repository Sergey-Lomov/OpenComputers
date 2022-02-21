Point = {}
Point.typeLabel = "Point"

function Point:new(x, y)
	typeAssert(x, "number", 1)
	typeAssert(y, "number", 2)

	local point = {}
	self.__index = self
	setmetatable(point, self)

	point.x = x or 0
	point.y = y or 0

	return point
end

function Point:__tostring()
	return "<Point x:" .. tostring(self.x) .. " y:" .. tostring(self.y) .. ">"
end

function Point:simpleString()
	return tostring(self.x) .. "-" .. tostring(self.y)
end