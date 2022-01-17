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

-- Adapt event for child. Return nil if child should not handle this event. For example touch out of child frame.
function GuiObject:eventForChild(event, child)
	if event.type == GuiEventType.tap then
		if not child.frame:contains(event.x, event.y) then return nil end

		local x = event.x - child.frame.x
		local y = event.y - child.frame.y
		return TapEvent:new(x, y, event.button)
	else
		return event
	end
end

function GuiObject:handleEvent(event)
	for i = #self.childs, 1, -1 do
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