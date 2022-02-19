require 'extended_table'
local unicode = require 'ui/utils/extended_unicode'

------------------- Default breakinf functions
local function noneBreaking(text, width, height)
	return {text}
end

local function cutBreaking(text, width, height)
	return {unicode.sub(text, 1, width)}
end

local function truncateTailBreaking(text, width, height)
	if unicode.len(text) <= width then
		return {text}
	end

	local truncateLength = unicode.len(LineBreaker.truncateStub)
	local truncated = unicode.sub(text, 1, width - truncateLength) .. LineBreaker.truncateStub
	return {truncated}
end

local function charWrapBreaking(text, width, height)
	local lines = {}
	local left = text
	while unicode.len(left) > 0 do
		local line = unicode.sub(left, 1, width)
		left = unicode.sub(left, width + 1)
		left = unicode.truncateLeft(left)
		table.insert(lines, line)
	end

	while #lines > height do table.remove(lines, #lines) end
	return lines
end

local function wordWrapBreaking(text, width, height)
	local lines = {}
	local left = text
	while unicode.len(left) > 0 do
		local line = unicode.sub(left, 1, width)
		local lineLen = unicode.len(line)
		local separatorIndex = nil

		for i = lineLen + 1, 1, -1 do
			local currentChar = unicode.sub(left, i, i)
			if table.containsValue(unicode.whitespaces, currentChar) or currentChar == "" then
				lastSeparatorIndex = i
				break
			end
			if separatorIndex ~= nil then break end
		end
		
		line = unicode.sub(line, 1, lastSeparatorIndex - 1)
		left = unicode.sub(left, unicode.len(line) + 1)
		left = unicode.truncateLeft(left)
		table.insert(lines, line)
	end

	while #lines > height do table.remove(lines, #lines) end
	return lines
end

------------------- Line breaker itself

LineBreakMode = {
	none = 0,
	cut = 1,
	truncateTail = 2,
	charWrap = 3,
	wordWrap = 4
}

LineBreaker = {
	truncateStub = "...",
	breakingFuncs = {
		[LineBreakMode.none] = noneBreaking,
		[LineBreakMode.cut] = cutBreaking,
		[LineBreakMode.truncateTail] = truncateTailBreaking,
		[LineBreakMode.charWrap] = charWrapBreaking,
		[LineBreakMode.wordWrap] = wordWrapBreaking,
	}
}

setmetatable(LineBreaker, LineBreaker)

LineBreaker.__call = function(self, mode, text, width, height)
	local breakingFunc = self.breakingFuncs[mode]
	if breakingFunc ~= nil then
		return breakingFunc(text, width, height)
	else
		return {text}
	end
end