require 'ui/base/gui_object'
require 'ui/utils/content_alignment'
local unicode = require 'unicode'
 
GuiPanel = GuiObject:new()
GuiPanel.__index = GuiPanel
GuiPanel.typeLabel = "GuiPanel"
GuiPanel.defaultTextColor = 0xFFFFFF
GuiPanel.titleGap = 2
GuiPanel.defaultTitleLeftWrapper = '['
GuiPanel.defaultTitleRightWrapper = ']'
 
function GuiPanel:new(frame, background, title)
  local panel = GuiObject:new(frame, background)
  setmetatable(panel, self)
 
  panel.title = title
  panel.titleColor = GuiLabel.defaultTextColor
  panel.titleAlignment = HorizontalAlignment.left
  panel.titleGap = GuiPanel.titleGap
  panel.titleLeftWrapper = GuiPanel.defaultTitleLeftWrapper
  panel.titleRightWrapper = GuiPanel.defaultTitleRightWrapper
 
  return panel
end
 
function GuiPanel:drawOverborder(drawer)
  if self.title == nil then return end

  local wrappedTitle = self.titleLeftWrapper .. self.title .. self.titleRightWrapper
  local x = 0
  if self.titleAlignment == HorizontalAlignment.left then
    x = self.titleGap + 1
  elseif self.titleAlignment == HorizontalAlignment.center then
    x = math.floor(self.frame.size.width - unicode.len(wrappedTitle)) / 2
  else 
    x = self.frame.size.width - unicode.len(wrappedTitle) - self.titleGap
  end

  drawer:drawText(x, 1, wrappedTitle, self:inheritedBackground(), self.titleColor)
end
 
function GuiPanel:__tostring()
  return "<Panel title: \"" .. (self.title or "nil") .. "\" frame: " .. tostring(self.frame) .. ">"
end