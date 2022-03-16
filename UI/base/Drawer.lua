Drawer = {
  gpu = nil,
}
Drawer.__index = Drawer
Drawer.typeLabel = "Drawer"
 
function Drawer:new(gpu)
  if gpu == nil then
    error("Missed gpu on drawer creation")
  end
 
  local drawer = {}
  setmetatable(drawer, self)
 
  drawer.gpu = gpu
  drawer.offset = {x = 0, y = 0}
 
  return drawer
end
 
function Drawer:increaseOffset(x, y)
  self.offset.x = self.offset.x + x
  self.offset.y = self.offset.y + y
end
 
function Drawer:decreaseOffset(x, y)
  self.offset.x = self.offset.x - x
  self.offset.y = self.offset.y - y
end
 
function Drawer:drawBackRect(rect, color)
  local initialColor = self.gpu.getBackground()
  self.gpu.setBackground(color)
  self.gpu.fill(rect.origin.x + self.offset.x, rect.origin.y + self.offset.y, rect.size.width, rect.size.height, " ")
  self.gpu.setBackground(initialColor)
end
 
function Drawer:drawText(x, y, text, backColor, frontColor)
  if backColor ~= nil then self.gpu.setBackground(backColor) end
  if frontColor ~= nil then self.gpu.setForeground(frontColor) end
  self.gpu.set(x + self.offset.x, y + self.offset.y, text)
end
 
function Drawer:fill(x, y, width, height, symbol, backColor)
  if backColor ~= nil then self.gpu.setBackground(backColor) end
  self.gpu.fill(x + self.offset.x, y + self.offset.y, width, height, symbol)
end