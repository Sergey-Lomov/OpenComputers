require 'utils'
require 'ui/base/gui_object'
require 'ui/objects/gui_label'
require 'ui/events/keyboard_handler'
require 'ui/utils/line_breaking'
require 'ui/utils/content_alignment'
require 'ui/geometry/rect'
local keyboard = require 'keyboard'
 
GuiButton = GuiObject:new()
GuiButton.__index = GuiButton
GuiButton.typeLabel = "GuiButton"
 
function GuiButton:new(frame, background, text)
  local button = GuiObject:new(frame, background)
  setmetatable(button, self)
 
  button.action = nil
  button.selectedBackground = button.background

  local labelFrame = Rect:newBounds(button.frame)
  button.label = GuiLabel:new(labelFrame, nil, text)
  button.label.breakMode = LineBreakMode.wordWrap
  button.label.textAlignment = ContentAlignment.center
  button:addChild(button.label)

  button.label:setFrame(labelFrame)

  return button
end

function GuiButton:setText(text)
  self.label.text = text
  self:setNeedRender(false)
end
 
function GuiButton:__tostring()
  return "<Button text: " .. self.label.text .. " frame: " .. tostring(self.frame) .. ">"
end

function GuiButton:handleFrameUpdate()
  getmetatable(getmetatable(self)).handleFrameUpdate(self)
  local labelFrame = Rect:newBounds(self.frame)
  self.label:setFrame(labelFrame)
end

function GuiButton:onTap(tap)
  if tap.button ~= 0 then return end
  safeCall(self.action)
end

function GuiButton:onKey(key)
  if not key.isDown then return end
 
  if key.code == keyboard.keys.enter or key.code == keyboard.keys.space then
    safeCall(self.action)
  end
end

function GuiButton:firstResponderWasBecame()
  self:setNeedRender(false)
end

function GuiButton:firstResponderWasReleased()
  self:setNeedRender(false)
end

function GuiButton:inheritedBackground()
  local parentBack = getmetatable(getmetatable(self)).inheritedBackground(self)
  local defaultBack = self.background or parentBack

  if KeyboardHandler:isFirstResponder(self) then
    return self.selectedBackground or defaultBack
  else 
    return defaultBack
  end
end