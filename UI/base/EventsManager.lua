-- This manager is bridge between gui events system and OpenOS events system. Starts to listen events automatically.
require 'GuiEvent'
local event = require 'event'

EventsManager = {
	guiScreens = {}
}

function EventsManager:appendScreen(screen)
	table.insert(self.guiScreens, screen)
end

local function handleTap(...)
	local _, screen, x, y, button = table.unpack { ... }
	local tap = TapEvent:new(x, y, button)
	for _, guiScreen in ipairs(EventsManager.guiScreens) do
		if guiScreen.drawer.gpu.getScreen() == screen then
			guiScreen:handleEvent(tap)
		end
	end
end

function EventsManager:startListening()
	event.listen("touch", handleTap)
end

function EventsManager:stopListening()
	event.ignore("touch", handleTap)
end

EventsManager:startListening()