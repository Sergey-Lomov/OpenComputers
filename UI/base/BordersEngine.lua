require 'extended_table'
require 'ui/utils/asserts'
require 'ui/base/border_style'
require 'ui/geometry/grid_line'
require 'ui/geometry/point'

BorderEngine = {}
BorderEngine.typeLabel = "BorderEngine"

function BorderEngine:new(style)
  typeAssert(style, BorderStyle, 1)

  local engine = {}
  self.__index = self
  setmetatable(engine, self)
  
  engine.style = style
  engine.verticalLines = {}
  engine.horizontalLines = {}
  engine.points = {}

  return engine
end

function BorderEngine:clear()
  self.verticalLines = {}
  self.horizontalLines = {}
  self.points = {}
end

function BorderEngine:drawBy(drawer, backColor)
  typeAssert(drawer, Drawer, 1)

  local verticalSymbol =  self.style:verticalSymbol()
  local horizontalSymbol =  self.style:horizontalSymbol()
  
  for _, line in ipairs(self.verticalLines) do
    local size = line:size()
    drawer:fill(line:minX(), line:minY(), size.width, size.height, verticalSymbol, backColor)
  end

  for _, line in ipairs(self.horizontalLines) do
    local size = line:size()
    drawer:fill(line:minX(), line:minY(), size.width, size.height, horizontalSymbol, backColor)
  end

  for _, point in ipairs(self.points) do
    local pattern = self.style:pattern(point.env.top, point.env.left, point.env.right, point.env.bottom)
    local symbol = self.style.symbols[pattern]
    drawer:drawText(point.coords.x, point.coords.y, symbol, backColor)
  end
end

function BorderEngine:addLineCoords(x1, y1, x2, y2)
  self:addLinePoints(Point:new(x1, y1), Point:new(x2, y2))
end

function BorderEngine:addLinePoints(point1, point2)
  typeAssert(point1, Point, 1)
  typeAssert(point2, Point, 2)
  self:addLine(GridLine:new(point1, point2))
end

function BorderEngine:checkLineAndPoint(line, point)
  local success, environment, sublines = line:containsPoint(point.coords)
  if success then
    if line.isVertical then
      table.removeByValue(self.verticalLines, line)
    else
      table.removeByValue(self.horizontalLines, line)
    end

    environment.top = point.env.top or environment.top
    environment.bottom = point.env.bottom or environment.bottom
    environment.left = point.env.left or environment.left
    environment.right = point.env.right or environment.right

    table.removeByValue(self.points, point)
    self:addPoint(point.coords, environment, false)

    for _, newLine in ipairs(sublines) do
      self:addLine(newLine)
    end 
  end

  return success
end

function BorderEngine:addPoint(coords, env, checkLines)
  for _, point in ipairs(self.points) do
    if point.coords.x == coords.x and point.coords.y == coords.y then
      point.env.top = point.env.top or environment.top
      point.env.bottom = point.env.bottom or environment.bottom
      point.env.left = point.env.left or environment.left
      point.env.right = point.env.right or environment.right
      return
    elseif point.coords.x == coords.x then
      if point.coords.y == coords.y - 1 then
        env.top = point.env.bottom or env.top
        point.env.bottom = env.top
      elseif point.coords.y == coords.y + 1 then
        env.bottom = point.env.top or env.bottom
        point.env.top = env.bottom
      end
    elseif point.coords.y == coords.y then
      if point.coords.x == coords.x - 1 then
        env.left = point.env.right or env.left
        point.env.right = env.left
      elseif  point.coords.x == coords.x + 1 then
        env.right = point.env.left or env.right
        point.env.left = env.right
      end
    end
  end

  local point = {coords = coords, env = env}
  table.insert(self.points, point)

  if not checkLines then return end
  for index, line in ipairs(self.verticalLines) do
    if self:checkLineAndPoint(line, point) then 
      return
    end
  end

  for index, line in ipairs(self.horizontalLines) do
    if self:checkLineAndPoint(line, point) then 
      return
    end
  end
end

function BorderEngine:addLine(line)
  local asPoint = line:toPoint()
  if asPoint ~= nil then 
    local env = {top = false, left = false, right = false, bottom = false}
    self:addPoint(asPoint, env, true)
    return
  end 

  local sameLines = line.isVertical and self.verticalLines or self.horizontalLines
  local opositeLines = line.isVertical and self.horizontalLines or self.verticalLines

  for index, iterLine in ipairs(sameLines) do
    local compound = line:compound(iterLine)
    if compound ~= nil then
      table.remove(sameLines, index)
      self:addLine(compound)
      return
    end
  end

  for index, iterLine in ipairs(opositeLines) do
    local point, environment, sublines = line:intersectionPoint(iterLine)
    if point ~= nil then
      table.remove(opositeLines, index)
      self:addPoint(point, environment, false)

      for _, newLine in ipairs(sublines) do
        self:addLine(newLine)
      end
      return
    end
  end

  for _, point in ipairs(self.points) do
    if self:checkLineAndPoint(line, point) then return end
  end

  table.insert(sameLines, line)
end