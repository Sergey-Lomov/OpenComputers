require 'ui/utils/asserts'
require 'ui/geometry/point'
require 'ui/geometry/size'

-- This line may by only vertical or horizontal
GridLine = {}
GridLine.typeLabel = "GridLine"

function GridLine:new(p1, p2)
	typeAssert(p1, Point, 1)
	typeAssert(p2, Point, 2)
	assert(p1.x == p2.x or p1.y == p2.y, "Grid line should be horizontal or vertical")

	local line = {}
	self.__index = self
	setmetatable(line, self)

	line.p1 = p1
	line.p2 = p2
	line.isVertical = p1.x == p2.x

	return line
end

function GridLine:newRaw(x1, y1, x2, y2)
	return self:new(Point:new(x1, y1), Point:new(x2, y2))
end

function GridLine:__tostring()
	return "<Line from: " .. self.p1:simpleString() .. " to: " .. self.p2:simpleString() .. ">"
end

function GridLine:maxX()
	return math.max(self.p1.x, self.p2.x)
end

function GridLine:minX()
	return math.min(self.p1.x, self.p2.x)
end

function GridLine:maxY()
	return math.max(self.p1.y, self.p2.y)
end

function GridLine:minY()
	return math.min(self.p1.y, self.p2.y)
end

function GridLine:size()
	return Size:new(self:maxX() - self:minX() + 1, self:maxY() - self:minY() + 1)
end

function GridLine:toPoint()
	if self.p1.x == self.p2.x and self.p1.y == self.p2.y then
		return self.p1
	end
	return nil
end

local function compound(constantAxis, variableAxis, line1, line2)
	if line1.p1[constantAxis] ~= line2.p2[constantAxis] then return nil end
	
	local maxVar1 = math.max(line1.p1[variableAxis], line1.p2[variableAxis])
	local maxVar2 = math.max(line2.p1[variableAxis], line2.p2[variableAxis])
	local minVar1 = math.min(line1.p1[variableAxis], line1.p2[variableAxis])
	local minVar2 = math.min(line2.p1[variableAxis], line2.p2[variableAxis])
	
	if math.min(maxVar1, maxVar2) < math.max(minVar1, minVar2) then
		return nil -- Lines have no intersection
	end

	local p1 = Point:new(0, 0)
	p1[constantAxis] = line1.p1[constantAxis]
	p1[variableAxis] = math.max(maxVar1, maxVar2)

	local p2 = Point:new(0, 0)
	p2[constantAxis] = line1.p1[constantAxis]
	p2[variableAxis] = math.min(minVar1, minVar2)

	return GridLine:new(p1, p2)
end

function GridLine:compound(line)
	typeAssert(line, GridLine, 1)

	if self.isVertical and line.isVertical then
		return compound("x", "y", self, line)
	elseif not self.isVertical and not line.isVertical then
		return compound("y", "x", self, line)
	else
		return nil
	end
end

-- Return intersection point, info about environment and sublines. 
-- Return nil in case, when intersection is bigger then one point
function GridLine:intersectionPoint(line)
	typeAssert(line, GridLine, 1)

	if self.isVertical == line.isVertical then return nil end

	local vertical = self.isVertical and self or line
	local horizontal = self.isVertical and line or self

	local x = vertical.p1.x
	local y = horizontal.p1.y
	local environment = {top = false, bottom = false, right = false, left = false}
	local sublines = {}

	if x > horizontal:maxX() or x < horizontal:minX() or y > vertical:maxY() or y < vertical:minY() then
		return nil
	end

	if y < vertical:maxY() then
		environment.bottom = true
		local p1 = Point:new(x, y + 1)
		local p2 = Point:new(x, vertical:maxY())
		table.insert(sublines, GridLine:new(p1, p2))
	end

	if y > vertical:minY() then
		environment.top = true
		local p1 = Point:new(x, y - 1)
		local p2 = Point:new(x, vertical:minY())
		table.insert(sublines, GridLine:new(p1, p2))
	end

	if x < horizontal:maxX() then
		environment.right = true
		local p1 = Point:new(x + 1, y)
		local p2 = Point:new(horizontal:maxX(), y)
		table.insert(sublines, GridLine:new(p1, p2))
	end

	if x > horizontal:minX() then
		environment.left = true
		local p1 = Point:new(x - 1, y)
		local p2 = Point:new(horizontal:minX(), y)
		table.insert(sublines, GridLine:new(p1, p2))
	end

	return Point:new(x,y), environment, sublines
end

-- If line contains point environment info and sublines will be return also
function GridLine:containsPoint(point)
	typeAssert(point, Point, 1)

	if (self.isVertical and point.x ~= self.p1.x) 
		or (self.isVertical and point.y > self:maxY())
		or (self.isVertical and point.y < self:minY())
		or (not self.isVertical and point.y ~= self.p1.y)
		or (not self.isVertical and point.x > self:maxX())
		or (not self.isVertical and point.x < self:minX()) then
		return false
	end

	local environment = {top = false, bottom = false, right = false, left = false}
	local sublines = {}

	if self.isVertical then
		if self:maxY() > point.y then
			environment.bottom = true
			local p1 = Point:new(point.x, point.y + 1)
			local p2 = Point:new(point.x, self:maxY())
			table.insert(sublines, GridLine:new(p1, p2))
		end

		if self:minY() < point.y then
			environment.top = true
			local p1 = Point:new(point.x, point.y - 1)
			local p2 = Point:new(point.x, self:minY())
			table.insert(sublines, GridLine:new(p1, p2))
		end
	else
		if self:maxX() > point.x then
			environment.right = true
			local p1 = Point:new(point.x + 1, point.y)
			local p2 = Point:new(self:maxX(), point.y)
			table.insert(sublines, GridLine:new(p1, p2))
		end

		if self:minX() < point.x then
			environment.left = true
			local p1 = Point:new(point.x - 1, point.y)
			local p2 = Point:new(self:minX(), point.y)
			table.insert(sublines, GridLine:new(p1, p2))
		end
	end

	return true, environment, sublines
end