require 'utils'
require 'ui/objects/gui_paginator'
require 'ui/objects/gui_panel'
require 'ui/geometry/rect'
 
GuiList = GuiPaginator:new()
GuiList.__index = GuiList
GuiList.typeLabel = "GuiList"
 
function GuiList:new(frame, background, cellType, models)
  assert(cellType ~= nil, "Cell type should be specified at list creation")
  assert(cellType.new ~= nil, "Cell type " .. tostring(cellType) .. " have no new method")
  assert(cellType.setupBy ~= nil, "Cell type " .. tostring(cellType) .. " have no setupBy method")
  assert(cellType.getContentHeight ~= nil, "Cell type " .. tostring(cellType) .. " have no getContentHeight method")

  local list = GuiPaginator:new(frame, background)
  setmetatable(list, self)
 
  list.cellType = cellType
  list.models = models or {}
  list.onCellSelection = nil -- Call back which take two arguments - selected cell (first) and related model (second)

  list:reloadCells()
 
  return list
end

local function updatePageLayout(page)
  local cells = page.cells or {}
  local currentY = 1
  for _, cell in ipairs(cells) do
    local height = cell:getContentHeight()
    local cellFrame = Rect:newRaw(1, currentY, page.frame.size.width, height)
    cell:setFrame(cellFrame)
    currentY = currentY + height
  end
end

function GuiList:addCell(model, pages, currentY)
  local cell = self.cellType:new()
  assert(cell ~= nil, "Fail at cell creation by cellType " .. tostring(self.cellType))
  cell:setupBy(model)
  
  cell.onTap = function(cell, tap) 
    safeCall(self.onCellSelection, cell, model) 
  end

  local height = cell:getContentHeight()
  
  local outOfHeight = currentY + height > self.pageContainer.frame.size.height
  if outOfHeight or #pages == 0 then
    local newPage = GuiPanel:new()
    newPage.cells = {}
    newPage.onFrameUpdate = function() updatePageLayout(newPage) end
    table.insert(pages, newPage)
    currentY = 1
  end

  local page = pages[#pages]
  table.insert(page.cells, cell)
  page:addChild(cell)

  return currentY + height
end

function GuiList:reloadCells()
  local pages = {}
  if #self.models == 0 then return end

  local currentY = 1
  for _, model in ipairs(self.models) do
    currentY = self:addCell(model, pages, currentY)
  end

  self:setPages(pages)
end
 
function GuiList:__tostring()
  return "<List frame: " .. tostring(self.frame) .. ">"
end