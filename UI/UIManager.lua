local unicode = require "unicode"
local term = require "term"
local gpu = term.gpu()

local manager = {
	screenSizeStack = {},
	textColorStack = {}
}

function manager:setScreenSize(width, height)
	local maxWidth, maxHeight = gpu.maxResolution()
	if maxHeight < height or maxWidth < width then
		print("Try to set unsupported screen size: " .. width .. "х" .. height)
		return
	end

	local oldWidth, oldHeight = gpu.getResolution()
	local oldSize = {width = oldWidth, height = oldHeight}
	table.insert(self.screenSizeStack, oldSize)

	gpu.setResolution(width, height)
end

function manager:restoreScreenSize()
	if #self.screenSizeStack == 0 then
		print("Try to restore screen size from empty stack")
		return
	end

	local oldSize = self.screenSizeStack[#self.screenSizeStack]
	self.screenSizeStack[#self.screenSizeStack] = nil
	gpu.setResolution(oldSize.width, oldSize.height)
end

function manager:isScreenSizeRestorable()
	return #self.screenSizeStack > 0
end

function manager:setTextColor(color)
	local oldColor = gpu.getForeground()
	table.insert(self.textColorStack, oldColor)
	local oldColor = gpu.setForeground(color)
end

function manager:restoreTextColorAt(index)
	if #self.textColorStack == 0 then
		print("Try to restore text color from empty stack")
		return
	end

	if #self.textColorStack < index then
		print("Try to restore text color by to huge index")
		return
	end

	local oldColor = self.textColorStack[index]

	for i = #self.textColorStack, index, -1 do
		self.textColorStack[i] = nil
	end

	gpu.setForeground(oldColor)
end

function manager:restoreTextColor()
	self:restoreTextColorAt(#self.textColorStack)
end

function manager:restoreInitialTextColor()
	self:restoreTextColorAt(1)
end

function manager:isTextColorRestorable()
	return #self.textColorStack > 0
end

function manager:printHeader(header, pattern, spacing)
	spacing = spacing or 1
	local width, _ = gpu.getResolution()
	local headerLength = unicode.len(header)
	if headerLength > width - 2 * spacing then
		print(header)
		return
	end

	local leftPatterFinish = math.floor((width - headerLength - spacing) / 2)
	local rightPatternStart = leftPatterFinish + headerLength + 2 * spacing

	local fullString = ""
	for i = 1, leftPatterFinish do
		fullString = fullString .. pattern
	end

	for i = 1, spacing do
		fullString = fullString .. " "
	end

	fullString = fullString .. header

	for i = 1, spacing do
		fullString = fullString .. " "
	end

	for i = rightPatternStart, width - 1 do
		fullString = fullString .. pattern
	end

	print(fullString)
end

function manager:cursorToBottom()
	local _, height = gpu.getResolution()
	term.setCursor(1, height)
end

function manager:showLinesCentered(lines, colors)
	local width, height = gpu.getResolution()
	local initialColor = gpu.getForeground()
	
	for index, line in ipairs(lines) do
		if colors[index] ~= nil then
			gpu.setForeground(colors[index])
		end

		local y = (height - #lines) / 2 + index - 1
		local x = (width - unicode.len(line)) / 2
		gpu.set(x, y, line)
	end

	gpu.setForeground(initialColor)
end

function manager:secondsToDHM(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor(math.fmod(seconds, 86400) / 3600)
    local minutes = math.floor(math.fmod(seconds, 3600) / 60)
    
    return string.format("%dд. %dч. %dмин.", days, hours, minutes)
end

function manager:readableNumber(number)
    if number >= 1000 then
    	return self:readableNumber(number / 1000, size) .. "K"
    elseif number >= 100 then
    	return string.format("%d", number)
    elseif number >= 10 then
    	return string.format("%.1f", number)
    else
    	return string.format("%.2f", number)
    end
end

return manager