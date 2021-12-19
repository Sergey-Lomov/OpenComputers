table.containsValue = function(tab, value)
	for _, currentValue in pairs(tab) do
		if value == currentValue then
			return true
		end
	end
	return false
end

table.filtered = function(tab, func)
	local result = {}
	for key, value in pairs(tab) do
		if func(value) then
			result[key] = value
		end
	end
	return result
end

table.filteredArray = function(tab, func)
	local result = {}
	for _, value in ipairs(tab) do
		if func(value) then
			table.insert(result, value)
		end
	end
	return result
end

table.filteredByKeyValue = function(tab, filterKey, filterValue)
	local result = {}
	for _, value in pairs(tab) do
		if value[filterKey] == filterValue then
			table.insert(result, value)
		end
	end
	return result
end

table.removeByValue = function(tab, removedValue)
	for key, value in pairs(tab) do
		if value == removedValue then
			table.remove(tab, key)
		end
	end
end