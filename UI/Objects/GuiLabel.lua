require 'ui/base/gui_object'
require 'ui/utils/line_breaking'

GuiLabel = GuiObject:new()
GuiLabel.__index = GuiLabel
GuiLabel.typeLabel = "GuiLabel"
GuiLabel.defaultTextColor = 0xFFFFFF

function GuiLabel:new(frame, background, text)
	local label = GuiObject:new(frame, background)
	setmetatable(label, self)

	label.text = text or ""
	label.textColor = GuiLabel.defaultTextColor
	label.breakMode = LineBreakMode.none

	return label
end


function GuiLabel:drawBy(drawer)
	getmetatable(getmetatable(self)).drawBy(self, drawer)

	local lines = LineBreaker(self.breakMode, self.text, self.frame.size.width, self.frame.size.height)
	for index, line in ipairs(lines) do
		local y = self.frame.origin.y + index - 1
		drawer:drawText(self.frame.origin.x, y, line, self.background, self.textColor)
	end
end