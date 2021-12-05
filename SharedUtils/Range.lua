Range = {
	min = math.mininteger,
	max = math.maxinteger
}

function Range:new(min, max)
	obj = {}
	setmetatable(obj, self)
	self.__index = self
	obj.min = min or math.mininteger
	obj.max = max or math.maxinteger
	return obj
end

function Range:contains(value)
	return value <= self.max and value >= self.min 
end
