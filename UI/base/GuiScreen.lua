-- Screen is top level GuiObject
require 'ui/base/drawer'
require 'ui/base/events_manager'
require 'ui/base/gui_object'

GuiScreen = GuiObject:new()
GuiScreen.__index = GuiScreen

function GuiScreen:new(gpu, background)
	if gpu == nil then
		error("Missed gpu on screen creation")
	end

	local screen = GuiObject:new()
	setmetatable(screen, self)

	local width, height = gpu.getResolution()
	screen.frame = Rect:new(0, 0, width, height)
	screen.background = background or 0x000000
	screen.drawer = Drawer:new(gpu)

	EventsManager:appendScreen(screen)

	return screen
end

function GuiScreen:render()
	self:drawBy(self.drawer)
end