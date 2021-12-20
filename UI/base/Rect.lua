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