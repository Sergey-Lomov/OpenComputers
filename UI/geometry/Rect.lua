require 'ui/utils/asserts'
require 'ui/geometry/point'
require 'ui/geometry/size'
 
Rect = {}
Rect.typeLabel = "Rect"
 
function Rect:new(origin, size)
  typeAssert(origin, Point, 1)
  typeAssert(size, Size, 2)
 
  local rect = {}
  self.__index = self
  setmetatable(rect, self)
 
  rect.origin = origin
  rect.size = size
 
  return rect
end
 
function Rect:newRaw(x, y, width, height)
  return self:new(Point:new(x, y), Size:new(width, height))
end

function Rect:newBounds(frame)
  typeAssert(frame, Rect, 1)
 
  return self:newRaw(1, 1, frame.size.width, frame.size.height)
end

function Rect:withGap(gap)
  typeAssert(gap, "number", 1)
 
  return Rect:newRaw(1 + gap, 1 + gap, self.size.width - 2 * gap, self.size.height - 2 * gap)
end
 
Rect.zero = Rect:newRaw(0, 0, 0, 0)
 
function Rect:minX()
  return self.origin.x
end
 
function Rect:minY()
  return self.origin.y
end
 
function Rect:maxX()
  return self.origin.x + self.size.width - 1
end
 
function Rect:maxY()
  return self.origin.y + self.size.height - 1
end
 
function Rect:contains(x, y)
  return x >= self.origin.x and y >= self.origin.y and x <= self:maxX() and y <= self:maxY()
end
 
function Rect:__tostring()
  return "<Rect x: " .. tostring(self.origin.x) .. " y: " .. tostring(self.origin.y) .. " w: " .. tostring(self.size.width) .. " h: " .. tostring(self.size.height) .. ">"
end
 
function Rect:fullscreenRect(gpu)
  local width, height = gpu.getResolution()
  return Rect:newRaw(1, 1, width, height)
end