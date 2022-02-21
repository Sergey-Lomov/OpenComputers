GuiEventType = {
	framesUpdate = 0,
	tap = 1
}

GuiEvent = {}
GuiEvent.__index = GuiEvent
GuiEvent.typeLabel = "GuiEvent"

function GuiEvent:new(type, handlingFunc)
	if type == nil then
		error("Missed type on gui event creation")
	end

	if handlingFunc == nil then
		error("Missed handling func on gui event creation")
	end

	local event = {}
	setmetatable(event, self)
	event.type = type
	event.handled = false
	event.handlingFunc = handlingFunc

	return event
end

-- Frames update event
FramesUpdateEvent = GuiEvent:new(GuiEventType.framesUpdate, "onFramesUpdate")
FramesUpdateEvent.__index = FramesUpdateEvent

function FramesUpdateEvent:new()
	local event = GuiEvent:new(GuiEventType.framesUpdate, "onFramesUpdate")
	setmetatable(event, self)
	return event
end

-- Tap event
TapEvent = GuiEvent:new(GuiEventType.tap, "onTap")
TapEvent.__index = TapEvent

function TapEvent:new(x, y, button)
	local event = GuiEvent:new(GuiEventType.tap, "onTap")
	setmetatable(event, self)
	
	event.x = x or 0
	event.y = y or 0
	event.button = button or 0

	return event
end