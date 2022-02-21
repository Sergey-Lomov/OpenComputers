-- Screen is top level GuiObject
require 'ui/base/drawer'
require 'ui/base/events_manager'
require 'ui/base/gui_object'
require 'ui/base/border_engine'
require 'ui/base/border_style'

GuiScreen = GuiObject:new()
GuiScreen.__index = GuiScreen
GuiScreen.typeLabel = "GuiScreen"

function GuiScreen:new(gpu, background)
	if gpu == nil then
		error("Missed gpu on screen creation")
	end

	local screen = GuiObject:new()
	setmetatable(screen, self)

	local width, height = gpu.getResolution()
	screen.frame = Rect:newRaw(1, 1, width, height)
	screen.background = background or 0x000000
	screen.drawer = Drawer:new(gpu)

	EventsManager:appendScreen(screen)

	return screen
end

function GuiScreen:render()
	self:drawBy(self.drawer)
	self.borderEngine:drawBy(self.drawer, self.background)
	-- Temporal
	self.drawer.gpu.setBackground(0)
end

------------------- GuiObject extension
function GuiObject:getScreen()
	local current = self
	while current ~= nil and getmetatable(current) ~= GuiScreen do
		current = current.parent
	end
	return current
end