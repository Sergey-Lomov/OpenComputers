require 'GuiObject'

GuiLabel = GuiObject:new()
GuiLabel.__index = GuiLabel
GuiLabel.defaultTextColor = 0xFFFFFF

GuiLabelBreakMode = {
	none = 0,
	truncateTail = 1,
	worldWrap = 2,
	charWrap = 3
}

function GuiLabel:new(frame, background, text)
	local label = GuiObject:new(frame, background)
	setmetatable(label, self)

	label.text = text or ""
	label.textColor = GuiLabel.defaultTextColor
	label.breakMode = GuiLabelBreakMode.none

	return label
end

local function breakText(text, mode, width)
	return {text}
end

function GuiLabel:drawBy(drawer)
	getmetatable(getmetatable(self)).drawBy(self, drawer)

	local lines = breakText(self.text, self.breakMode, self.frame.width)
	for index, line in ipairs(lines) do
		local y = self.frame.y + index - 1
		drawer:drawText(self.frame.x, y, line, self.background, self.textColor)
	end
end