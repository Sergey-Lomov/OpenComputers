require 'extended_table'
local unicode = require 'unicode'

unicode.whitespaces = {" ", "\n", "\t"}

unicode.truncateLeft = function(text)
	local counter = 0
	local nextChar = unicode.sub(text, 1, 1)
	while table.containsValue(unicode.whitespaces, nextChar) do
		counter = counter + 1
		nextChar = unicode.sub(text, counter + 1, counter + 1)
	end

	return unicode.sub(text, counter + 1)
end

unicode.truncateRight = function(text)
	local counter = 0
	local nextChar = unicode.sub(text, #text, #text)
	while table.containsValue(unicode.whitespaces, nextChar) do
		counter = counter + 1
		nextChar = unicode.sub(text, -1 * counter, -1 * counter)
	end

	if counter > 0 then
		return unicode.sub(text, 1, -1 * counter)
	else
		return text
	end
end

unicode.truncateBoth = function(text)
	return unicode.truncateRight(unicode.truncateLeft(text))
end

return unicode