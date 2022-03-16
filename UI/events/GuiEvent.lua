require 'ui/utils/asserts'
 
GuiEventType = {
  framesUpdate = 0,
  tap = 1,
  key = 2,
}
 
GuiEvent = {}
GuiEvent.__index = GuiEvent
GuiEvent.typeLabel = "GuiEvent"
 
function GuiEvent:new(type, handlingFunc)
  if type == nil then
    error("Missed type on gui event creation")
  end
 
  if handlingFunc == nil then
    error("Missed handling func on gui event creation")
  end
 
  local event = {}
  setmetatable(event, self)
  event.type = type
  event.handled = false
  event.handlingFunc = handlingFunc
 
  return event
end
 
-------------- Frames update event
FramesUpdateEvent = GuiEvent:new(GuiEventType.framesUpdate, "onFramesUpdate")
FramesUpdateEvent.__index = FramesUpdateEvent
 
function FramesUpdateEvent:new()
  local event = GuiEvent:new(GuiEventType.framesUpdate, "onFramesUpdate")
  setmetatable(event, self)
  return event
end
 
------------- Tap event
TapEvent = GuiEvent:new(GuiEventType.tap, "onTap")
TapEvent.__index = TapEvent
 
function TapEvent:new(x, y, button)
  typeAssert(x, "number", 1)
  typeAssert(y, "number", 2)
  typeAssert(button, "number", 3)
 
  local event = GuiEvent:new(GuiEventType.tap, "onTap")
  setmetatable(event, self)
 
  event.x = x
  event.y = y
  event.button = button
 
  return event
end
 
------------- KeyboardEvent
KeyEvent = GuiEvent:new(GuiEventType.key, "onKey")
KeyEvent.__index = TapEvent
 
function KeyEvent:new(isDown, char, code, sender)
  typeAssert(isDown, "boolean", 1)
  typeAssert(char, "number", 2)
  typeAssert(code, "number", 3)
  typeAssert(sender, "string", 4)
 
  local event = GuiEvent:new(GuiEventType.key, "onKey")
  setmetatable(event, self)
  
  event.isDown = isDown
  event.char = char
  event.code = code
  event.sender = sender
 
  return event
end