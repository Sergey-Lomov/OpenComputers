require 'ExtendedTable'
require 'Rect'

GuiObject = {}
GuiObject.__index = GuiObject

-- Public

function GuiObject:new(frame, background)
	local object = {}
	setmetatable(object, self)

	object.frame = frame or Rect:new()
	object.background = background
	object.childs = {}
	object.parent = nil

	return object
end

function GuiObject:addChild(object)
	table.insert(self.childs, object)
	object.parent = self
end

function GuiObject:removeFromParent()
	table.removeByValue(self.parent.childs, self)
	self.parent = self
end
--[[
function GuiObject:pointToParentSpace(x, y, parent)
	local resultX = 0
	local resultY = 0

	local current = self
	repeat
		resultX = resultX + current.frame.x
		resultY = resultY + current.frame.y
		current = current.parent
		
		if current == nil then
			error("Try to convert point to coordinates space of unrelated object")
		end
	until current ~= parent

	return {x = resultX, y = resultY}
end]]--

function GuiObject:drawBy(drawer)
	if self.background ~= nil then
		drawer:drawBackRect(self.frame, self.background)
	end

	drawer:increaseOffset(self.frame.x, self.frame.y)
	for _, child in ipairs(self.childs) do
		child:drawBy(drawer)
	end
	drawer:decreaseOffset(self.frame.x, self.frame.y)
end

-- Event handling
function GuiObject:handleEvent(event)
	if self[event.handlingFunc] ~= nil then
		self[event.handlingFunc](event)
		if event.handled then return end
	end

	for _, child in ipairs(self.childs) do
		child:handleEvent(event)
		if event.handled then return end
	end
end