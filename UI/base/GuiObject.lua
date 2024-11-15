require 'extended_table'
require 'utils'
require 'ui/utils/asserts'
require 'ui/geometry/rect'
require 'ui/base/border_engine'
require 'ui/base/main_loop'
require 'ui/events/keyboard_handler'
require 'ui/events/gui_event'

GuiObject = {}
GuiObject.__index = GuiObject
GuiObject.typeLabel = "GuiObject"
GuiObject.defaultBackground = 0x000000

-- Public

function GuiObject:new(frame, background)
  local object = {}
  setmetatable(object, self)

  object.frame = frame or Rect.zero
  object.background = background
  object.childs = {}
  object.parent = nil
  object.isOutBorderVisible = false
  object.isInBorderVisible = false
  object.needToRender = true
  object.isHidden = false

  object.inheritBorderStyle = true
  object.borderEngine = BorderEngine:new(BorderStyle.default)

  object.onFrameUpdate = nil -- Function which calls at frame update. Take one argument - object.

  return object
end

function GuiObject:setFrame(rect)
  typeAssert(rect, Rect, 1)

  self.frame = rect
  self:handleFrameUpdate()
  safeCall(self.onFrameUpdate, self)

  self:setNeedRender(true)
end

function GuiObject:handleFrameUpdate()
  self:updateInBorders()
  self:updateOutBorders()
end

-------- Drawing

function GuiObject:drawBy(drawer, forced)
  if self.isHidden then return end
  if forced == nil then forced = false end

  self:willDraw(drawer)
  local needToRender = self.needToRender or forced

  drawer:increaseOffset(self.frame.origin.x - 1, self.frame.origin.y - 1)
  
  if needToRender then 
    self:drawSelf(drawer)
  end

  self:drawChilds(drawer, needToRender)
  if needToRender then
    self.borderEngine:drawBy(drawer, self.background)
    self:drawOverborder(drawer)
  end
  
  drawer:decreaseOffset(self.frame.origin.x - 1, self.frame.origin.y - 1)

  self.needToRender = false
end

function GuiObject:willDraw(drawer)
  -- May be overrided by derived classes
end

function GuiObject:drawOverborder(drawer)
  -- May be overrided by derived classes
end

function GuiObject:drawSelf(drawer)
  local background = self:inheritedBackground()
  local bounds = Rect:newBounds(self.frame)
  drawer:drawBackRect(bounds, background)
end

function GuiObject:drawChilds(drawer, forced)
  for _, child in ipairs(self.childs) do
    child:drawBy(drawer, forced)
  end
end

function GuiObject:setNeedRender(withParent)
  if withParent == nil then withParent = true end
  self.needToRender = true
  if self.parent ~= nil and withParent then self.parent:setNeedRender(false) end
end

function GuiObject:inheritedBackground()
  if self.background ~= nil then
    return self.background
  elseif self.parent == nil then 
    return GuiObject.defaultBackground
  else 
    return self.parent:inheritedBackground()
  end
end

-------- Keyboard first responder

function GuiObject:becameFirstResponder()
  KeyboardHandler:setFirstResponder(self)
end

function GuiObject:releaseFirstResponder()
  KeyboardHandler:setFirstResponder(nil)
end

function GuiObject:firstResponderWasReleased()
  -- Declared for subclass
end

function GuiObject:registerResponders()
  if self[KeyEvent.handlingFunc] ~= nil then
    KeyboardHandler:registerResponder(self)
  end
  
  for _, child in ipairs(self.childs) do
    child:registerResponders()
  end
end

function GuiObject:unregisterResponders()
  if self[KeyEvent.handlingFunc] ~= nil then
    KeyboardHandler:unregisterResponder(self)
  end
  
  for _, child in ipairs(self.childs) do
    child:unregisterResponders()
  end
end

------- Hierarchy

function GuiObject:addChild(child)
  table.insert(self.childs, child)
  child.parent = self
  child:registerResponders()

  if child.inheritBorderStyle then
    child.borderEngine.style = self.borderEngine.style
  end
  if child.isOutBorderVisible then
    child:showOutBorders()
  end
end

function GuiObject:removeFromParent()
  if self.parent == nil then return end
  table.removeByValue(self.parent.childs, self)
  self:unregisterResponders()
  self.parent = nil
end

function GuiObject:absoluteFrame()
  local origin = self.frame.origin
  if parent ~= nil then
    origin.x = origin.x + parent:absoluteFrame().origin.x - 1
    origin.y = origin.y + parent:absoluteFrame().origin.y - 1
  end

  return Rect:new(origin, self.frame.size)
end

------------------- Borders

function GuiObject:setBorderStyle(style)
  typeAssert(style, BorderStyle, 1)
  self.borderEngine.style = style
  for _, child in ipairs(self.childs) do
    if child.inheritBorderStyle then child:setBorderStyle(style) end
  end
end

local function addBordersRect(engine, x1, y1, x2, y2)
  engine:addLineCoords(x1, y1, x2, y1)
  engine:addLineCoords(x2, y1, x2, y2)
  engine:addLineCoords(x2, y2, x1, y2)
  engine:addLineCoords(x1, y2, x1, y1)
end

function GuiObject:addOutBordersToParent()
  if self.isOutBorderVisible and self.parent ~= nil then
    local frame = self:absoluteFrame()
    addBordersRect(self.parent.borderEngine, frame:minX() - 1, frame:minY() - 1, frame:maxX() + 1, frame:maxY() + 1)
  end
end

function GuiObject:updateOutBorders()
  if self.isOutBorderVisible and self.parent ~= nil then
    self.parent:updateInBorders()
  end
end

function GuiObject:updateInBorders()
  self.borderEngine:clear()
  if self.isInBorderVisible then
    addBordersRect(self.borderEngine, 1, 1, self.frame.size.width, self.frame.size.height)
  end

  for _, child in ipairs(self.childs) do
    child:addOutBordersToParent()
  end
end

function GuiObject:hideOutBorders()
  self.isOutBorderVisible = true
  if self.parent ~= nil then self.parent:updateInBorders() end
end

function GuiObject:showOutBorders()
  self.isOutBorderVisible = true
  if self.parent ~= nil then self:addOutBordersToParent() end
end

function GuiObject:showInBorders()
  self.isInBorderVisible = true
  addBordersRect(self.borderEngine, 1, 1, self.frame.size.width, self.frame.size.height)
end

function GuiObject:hideInBorders()
  self.isInBorderVisible = false
  self:updateInBorders()
end

-- Event handling

-- Adapt event for child. Return nil if child should not handle this event. For example touch out of child frame.
function GuiObject:eventForChild(event, child)
  if event.type == GuiEventType.tap then
    if not child.frame:contains(event.x, event.y) then 
      return nil 
    end

    local x = event.x - child.frame.origin.x + 1
    local y = event.y - child.frame.origin.y + 1
    return TapEvent:new(x, y, event.button)
  else
    return event
  end
end

function GuiObject:handleEvent(event)
  for index = #self.childs, 1, -1 do
    local child = self.childs[index]
    local childEvent = self:eventForChild(event, child)
    if childEvent ~= nil then
      child:handleEvent(childEvent)
      if childEvent.handled then
        event.handled = true
        return 
      end
    end
  end

  if self[event.handlingFunc] ~= nil then
    self[event.handlingFunc](self, event)
    event.handled = true
  end
end

------------------- Development

function GuiObject:printChilds(levelsLeft, prefix)
  if levelsLeft == 0 then return end
  prefix = prefix or ""
  levelsLeft = levelsLeft or math.huge

  for index, child in ipairs(self.childs) do
    local childPrefixTale = (index == #self.childs) and "└" or "├"
    local subchildsPrefixTale = (index == #self.childs) and " " or "│"
    local childPrefix = prefix .. childPrefixTale
    print(childPrefix .. tostring(child))
    child:printChilds(levelsLeft - 1, prefix .. subchildsPrefixTale)
  end
end
