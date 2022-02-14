table.containsValue = function(tab, value)
	for _, currentValue in pairs(tab) do
		if value == currentValue then
			return true
		end
	end
	return false
end

table.haveSuccess = function(tab, checker)
	for _, currentValue in pairs(tab) do
		if checker(currentValue) then
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

table.mapByKey = function(tab, mappingKey, defaultValue)
	local result = {}
	for key, value in pairs(tab) do
		result[key] = value[mappingKey] or defaultValue
	end
	return result
end

-- Return array with all keys, which contains in tab1 but no contains in tab2
table.missedKeys = function(tab1, tab2)
	local result = {}
	for key, _ in pairs(tab1) do
		if tab2[key] == nil then
			table.insert(result, key)
		end
	end
	return result
end

-- Return array with value, which contains in tab1 but no contains in tab2
table.subtractionArray = function(tab1, tab2)
	local result = {}
	for _, value in ipairs(tab1) do
		if not table.containsValue(tab2, value) then
			table.insert(result, value)
		end
	end
	return result
end

-- Add all values from array tab2 into array tab1
table.addAll = function(tab1, tab2)
	for _, value in ipairs(tab2) do
		table.insert(tab1, value)
	end
end