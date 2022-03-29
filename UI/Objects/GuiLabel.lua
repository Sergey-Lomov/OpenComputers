require 'ui/base/gui_object'
require 'ui/utils/line_breaking'
require 'ui/utils/content_alignment'
local unicode = require 'unicode'
 
GuiLabel = GuiObject:new()
GuiLabel.__index = GuiLabel
GuiLabel.typeLabel = "GuiLabel"
GuiLabel.defaultTextColor = 0xFFFFFF
 
function GuiLabel:new(frame, background, text)
  local label = GuiObject:new(frame, background)
  setmetatable(label, self)
 
  label.text = text or ""
  label.textColor = GuiLabel.defaultTextColor
  label.textAlignment = ContentAlignment.centerLeft
  label.breakMode = LineBreakMode.none
 
  return label
end
 
function GuiLabel:drawSelf(drawer)
  getmetatable(getmetatable(self)).drawSelf(self, drawer)
 
  local lines = LineBreaker(self.breakMode, self.text, self.frame.size.width, self.frame.size.height)
  local topY = ContentAlignmenter:y(self.textAlignment, #lines, self.frame.size.height)

  for index, line in ipairs(lines) do
    local y = index - 1 + topY
    local x = ContentAlignmenter:x(self.textAlignment, unicode.len(line), self.frame.size.width)
    drawer:drawText(x, y, line, self:inheritedBackground(), self.textColor)
  end
end
 
function GuiLabel:__tostring()
  return "<Label text: " .. self.text .. " frame: " .. tostring(self.frame) .. ">"
end