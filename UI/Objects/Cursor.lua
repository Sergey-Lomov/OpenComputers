require 'utils'
require 'ui/base/gui_object'
require 'ui/geometry/rect'

Cursor = GuiObject:new()
Cursor.__index = Cursor
Cursor.typeLabel = "Cursor"

Cursor.defaulColor = 0xFFFFFF
Cursor.defaulFrequency = 0.5
Cursor.fullChar = "█"
 
function Cursor:new()
  local cursor = {}
  setmetatable(cursor, self)
 
  cursor.underchar = Cursor.fullChar
  cursor.color = Cursor.defaulColor
  cursor.isInverted = false
  cursor.frequency = Cursor.defaulFrequency
  cursor.lastUpdate = utils:realWorldSeconds()
  cursor.frame = Rect:newRaw(1,1,1,1)
 
  return cursor
end

function Cursor:setUnderchar(underchar)
  if underchar == "" or underchar == " " then
    underchar = Cursor.fullChar
  end
  self.underchar = underchar
end

function Cursor:willDraw(drawer)
  if utils:realWorldSeconds() - self.lastUpdate >= self.frequency then
  	self.lastUpdate = utils:realWorldSeconds()
  	self.isInverted = not self.isInverted
  	self:setNeedRender(false)
  end
end

function Cursor:drawSelf(drawer)
  local origin = self.frame.origin
  local background = self:inheritedBackground()
  if self.isInverted then
    drawer:drawText(origin.x, origin.y, self.underchar, self.color, background)
  else
  	drawer:drawText(origin.x, origin.y, self.underchar, background, self.color)
  end
end