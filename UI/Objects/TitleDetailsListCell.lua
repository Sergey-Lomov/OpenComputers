require 'ui/base/gui_object'
require 'ui/objects/gui_label'
require 'ui/geometry/rect'

TitleDetailsListCell = GuiObject:new()
TitleDetailsListCell.__index = TitleDetailsListCell
TitleDetailsListCell.typeLabel = "TitleDetailsListCell"

TitleDetailsListCell.defaultTitleColor = 0xFFFFFF
TitleDetailsListCell.defaultDetailsColor = 0xBBBBBB
 
function TitleDetailsListCell:new()
  local cell = GuiObject:new()
  setmetatable(cell, self)
 
  cell.titleLabel = GuiLabel:new()
  cell.titleLabel.textColor = TitleDetailsListCell.defaultTitleColor
  cell:addChild(cell.titleLabel)

  cell.detailsLabel = GuiLabel:new()
  cell.detailsLabel.textColor = TitleDetailsListCell.defaultDetailsColor
  cell:addChild(cell.detailsLabel)

  return cell
end

function TitleDetailsListCell:handleFrameUpdate()
  getmetatable(getmetatable(self)).handleFrameUpdate(self)

  local titleFrame = Rect:newRaw(1, 1, self.frame.size.width, 1)
  self.titleLabel:setFrame(titleFrame)
  local detailsFrame = Rect:newRaw(1, 2, self.frame.size.width, 1)
  self.detailsLabel:setFrame(detailsFrame)
end

function TitleDetailsListCell:getContentHeight()
  return 2
end

function TitleDetailsListCell:setupBy(model)
  self.titleLabel.text = model.title
  self.detailsLabel.text = model.details
end