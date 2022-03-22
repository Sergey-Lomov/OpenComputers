-- Screen is top level GuiObject
require 'ui/utils/asserts'
require 'ui/events/keyboard_handler'
require 'ui/base/gui_object'
require 'ui/geometry/rect'
 
GuiScreen = GuiObject:new()
GuiScreen.__index = GuiScreen
GuiScreen.typeLabel = "GuiScreen"
 
function GuiScreen:new(frame, background)
  typeAssert(frame, Rect, 1)
 
  local screen = GuiObject:new()
  setmetatable(screen, self)
 
  screen.frame = frame
  screen.background = background or 0x000000
 
  return screen
end
 
function GuiScreen:drawSelf(drawer)
  getmetatable(getmetatable(self)).drawSelf(self, drawer)
  -- Temporal
  drawer.gpu.setBackground(0)
end
 
function GuiScreen:becameActive()
  local responders = {}
  self:collectResponders(responders)
  KeyboardHandler:setResponders(responders)
end
 
function GuiScreen:becameInactive()
  KeyboardHandler:clearResponders()
end
 
------------------- GuiObject extension
function GuiObject:getScreen()
  local current = self
  while current ~= nil and getmetatable(current) ~= GuiScreen do
    current = current.parent
  end
  return current
end