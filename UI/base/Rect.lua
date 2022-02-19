Rect = {}

function Rect:new(x, y, width, height)
	local rect = {}
	self.__index = self
	setmetatable(rect, self)

	rect.x = x or 0
	rect.y = y or 0
	rect.width = width or 0
	rect.height = height or 0

	return rect
end

function Rect:getMaxX()
	return self.x + self.width - 1
end

function Rect:getMaxY()
	return self.y + self.height - 1
end

function Rect:contains(x, y)
	return x >= self.x and y >= self.y and x <= self:getMaxX() and y <= self:getMaxY()
end

function Rect:__tostring()
	return "<Rect x: " .. tostring(self.x) .. " y: " .. tostring(self.y) .. " w: " .. tostring(self.width) .. " h: " .. tostring(self.height) .. ">"
end