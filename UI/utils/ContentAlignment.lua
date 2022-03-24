require 'ui/geometry/point'

local VerticalAlignment = {
	top = 1,
	center = 2,
	bottom = 3
}

local HorizontalAlignment = {
	left = 1,
	center = 2,
	right = 3
}

ContentAlignment = {
	topLeft = {vertical = VerticalAlignment.top, horizontal = HorizontalAlignment.left},
	topCenter = {vertical = VerticalAlignment.top, horizontal = HorizontalAlignment.center},
	topRight = {vertical = VerticalAlignment.top, horizontal = HorizontalAlignment.right},
	centerLeft = {vertical = VerticalAlignment.center, horizontal = HorizontalAlignment.left},
	center = {vertical = VerticalAlignment.center, horizontal = HorizontalAlignment.center},
	centerRight = {vertical = VerticalAlignment.center, horizontal = HorizontalAlignment.right},
	bottomLeft = {vertical = VerticalAlignment.bottom, horizontal = HorizontalAlignment.left},
	bottomCenter = {vertical = VerticalAlignment.bottom, horizontal = HorizontalAlignment.center},
	bottomRight = {vertical = VerticalAlignment.bottom, horizontal = HorizontalAlignment.right},
}

ContentAlignmenter = {}
setmetatable(ContentAlignmenter, ContentAlignmenter)

function ContentAlignmenter:y(alignment, height, inHeight)
	if alignment.vertical == VerticalAlignment.top then
		return 1
	elseif alignment.vertical == VerticalAlignment.center then
		return math.floor((inHeight - height) / 2) + 1
	elseif alignment.vertical == VerticalAlignment.bottom then
		return inHeight - height + 1
	end
end

function ContentAlignmenter:x(alignment, width, inWidth)
	if alignment.horizontal == HorizontalAlignment.left then
		return 1
	elseif alignment.horizontal == HorizontalAlignment.center then
		return math.floor((inWidth - width) / 2) + 1
	elseif alignment.horizontal == HorizontalAlignment.right then
		return inWidth - width + 1
	end
end

function ContentAlignmenter:origin(alignment, size, inSize)
	local x = self:x(alignment, size.width, inSize.width)
	local y = self:y(alignment, size.height, inSize.height)
	return Point:new(x, y)
end