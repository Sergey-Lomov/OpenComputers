local color = require 'color'

GradientPoint = {}

function GradientPoint:new(position, color)
	if position > 1 or position < 0 then
		print("Gradient point position should be between 0 and 1")
		return nil
	end
	
	local point = {}
	point.position = position
	point.color = color

	return point
end

Gradient = {}

function Gradient:new(points)
	if #points == 0 then
		print("Gradient should contains at least one point")
		return nil
	end

	local gradient = {}
	setmetatable(gradient, self)
	self.__index = self
	
	gradient.points = points
	gradient:normalisePoints()

	return gradient
end

-- This method should be called after manual points update
function Gradient:normalisePoints()
	local comparator = function(p1, p2) return p1.position < p2.position end
	table.sort(self.points, comparator)

	if self.points[1].position ~= 0 then
		local firstPoint = GradientPoint:new(0, self.points[1].color)
		table.insert(self.points, 1, firstPoint)
	end

	if self.points[#self.points].position ~= 1 then
		local lastPoint = GradientPoint:new(1, self.points[#self.points].color)
		table.insert(self.points, lastPoint)
	end
end

function Gradient:getValue(position) 
	if position > 1 or position < 0 then
		print("Position should be between 0 and 1")
		return nil
	end

	local leftPoint = self.points[1]
	for i = 1, #self.points do
		if self.points[i].position <= position then
			leftPoint = self.points[i]
		end
	end

	local rightPoint = self.points[#self.points]
	for i = #self.points, 1, -1 do
		if self.points[i].position >= position then
			rightPoint = self.points[i]
		end
	end

	local intervalSize = rightPoint.position - leftPoint.position
	if intervalSize == 0 then -- This means left and right points are same, because position full equal to position of some point
		return leftPoint.color
	end

	local relativePosition = (position - leftPoint.position) / intervalSize

	return color.transition(leftPoint.color, rightPoint.color, relativePosition)
end