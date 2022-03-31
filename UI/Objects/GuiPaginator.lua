require 'ui/base/gui_object'
require 'ui/utils/content_alignment'
require 'ui/objects/gui_label'
require 'ui/objects/gui_button'
require 'ui/objects/gui_panel'
require 'ui/geometry/rect'
 
GuiPaginator = GuiObject:new()
GuiPaginator.__index = GuiPaginator
GuiPaginator.typeLabel = "GuiPaginator"

GuiPaginator.defaultIndexColor = 0x999999
GuiPaginator.defaultNavColor = 0xFFFFFF
GuiPaginator.defaultNavButtonsWidth = 8
GuiPaginator.defaultNavPanelSpacing = 4
GuiPaginator.defaultNavPanelHeight = 3
GuiPaginator.defaultNextTitle = ">>"
GuiPaginator.defaultPrevTitle = "<<"
 
function GuiPaginator:new(frame, background, pages)
  local paginator = GuiObject:new(frame, background)
  setmetatable(paginator, self)

  paginator.pages = pages or {}
  paginator.currentPageIndex = 1
  paginator.navPanelHeight = GuiPaginator.defaultNavPanelHeight
  paginator.navPanelSpacing = GuiPaginator.defaultNavPanelSpacing
  paginator.navButtonsWidth = GuiPaginator.defaultNavButtonsWidth
 
  paginator.pageContainer = GuiPanel:new()
  paginator:addChild(paginator.pageContainer)

  paginator.navContainer = GuiPanel:new()
  paginator:addChild(paginator.navContainer)

  paginator.indexLabel = GuiLabel:new()
  paginator.indexLabel.textColor = GuiPaginator.defaultIndexColor
  paginator.indexLabel.textAlignment = ContentAlignment.center
  paginator.navContainer:addChild(paginator.indexLabel)

  paginator.nextButton = GuiButton:new(Rect.zero, nil, GuiPaginator.defaultNextTitle)
  paginator.nextButton.label.textColor = GuiPaginator.defaultNavColor
  paginator.nextButton.action = function() paginator:showNextPage() end
  paginator.navContainer:addChild(paginator.nextButton)

  paginator.prevButton = GuiButton:new(Rect.zero, nil, GuiPaginator.defaultPrevTitle)
  paginator.prevButton.label.textColor = GuiPaginator.defaultNavColor
  paginator.prevButton.action = function() paginator:showPrevPage() end
  paginator.navContainer:addChild(paginator.prevButton)
 
  paginator:setupChildsLayout()
  paginator:handleFrameUpdate()
  if pages ~= nil and #pages > 0 then paginator:showPage(1) end

  return paginator
end

function GuiPaginator:setupChildsLayout()
  self.pageContainer.onFrameUpdate = function(container)
    local page = container.childs[1]
    if page ~= nil then 
      local frame = Rect:newBounds(container.frame)
      page:setFrame(frame)
    end
  end

  self.navContainer.onFrameUpdate = function(container)
    local middleY = math.ceil(container.frame.size.height / 2)
    local prevFrame = Rect:newRaw(self.navPanelSpacing + 1, middleY, self.navButtonsWidth, 1)
    self.prevButton:setFrame(prevFrame)

    local nextX = container.frame.size.width - self.navPanelSpacing - self.navButtonsWidth + 1
    local nextFrame = Rect:newRaw(nextX, middleY, self.navButtonsWidth, 1)
    self.nextButton:setFrame(nextFrame)

    local indexX = self.navPanelSpacing + self.navButtonsWidth + 1
    local indexWidth = nextX - indexX
    local indexFrame = Rect:newRaw(indexX, middleY, indexWidth, 1)
    self.indexLabel:setFrame(indexFrame)
  end
end

function GuiPaginator:handleFrameUpdate()
  getmetatable(getmetatable(self)).handleFrameUpdate(self)

  local pageHeight = self.frame.size.height - self.navPanelHeight
  local pageFrame = Rect:newRaw(1, 1, self.frame.size.width, pageHeight)
  local navFrame = Rect:newRaw(1, pageHeight + 1, self.frame.size.width, self.navPanelHeight or 0)
  self.pageContainer:setFrame(pageFrame)
  self.navContainer:setFrame(navFrame)
end

function GuiPaginator:setPages(pages, newIndex)
  if newIndex == nil then newIndex = 1 end
  self.pages = pages
  self:showPage(newIndex)
end

function GuiPaginator:showPage(index)
  if index > #self.pages then return end

  if self.currentPageIndex ~= nil then
    self.pages[self.currentPageIndex]:removeFromParent()
  end
  self.currentPageIndex = index
  self.pageContainer:addChild(self.pages[index])

  local pageRect = Rect:newBounds(self.pageContainer.frame)
  self.pages[index]:setFrame(pageRect)

  self.indexLabel.text = tostring(self.currentPageIndex) .. " / " .. tostring(#self.pages)
  self:setNeedRender(false)
end

function GuiPaginator:showPrevPage()
  if self.currentPageIndex > 1 then
    self:showPage(self.currentPageIndex - 1)
  else
    self:showPage(#self.pages)
  end
end

function GuiPaginator:showNextPage()
  if self.currentPageIndex < #self.pages then
    self:showPage(self.currentPageIndex + 1)
  else
    self:showPage(1)
  end
end
 
function GuiPaginator:__tostring()
  return "<Paginator frame: " .. tostring(self.frame) .. ">"
end