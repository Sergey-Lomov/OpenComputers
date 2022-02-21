require 'utils'
require 'ui/base/border_style'
require 'ui/base/gui_object'
require 'ui/base/gui_screen'
require 'ui/base/events_manager'

local term = require 'term'

tapHandler = function(label, tap) 
	if tap.button == 0 then
		label.frame.origin.x = label.frame.origin.x + 1
	else
		label.frame.origin.x = label.frame.origin.x - 1
	end
	label:handleFrameUpdate()
	s:render()
end

s = GuiScreen:new(term.gpu())
v1 = GuiObject:new(Rect:newRaw(4, 4, 21, 20), 0x777700)
v1.onTap = tapHandler
s:addChild(v1)

v2 = GuiObject:new(Rect:newRaw(2, 2, 6, 18), 0x007777)
v2.onTap = tapHandler
v1:addChild(v2)

v3  = GuiObject:new(Rect:newRaw(12, 2, 6, 18), 0x770077)
v3.onTap = tapHandler
v1:addChild(v3)

v4 = GuiObject:new(Rect:newRaw(30, 10, 10, 10), 0x999900)
v4.onTap = tapHandler
s:addChild(v4)


s:showInBorders()
v1:showInBorders()
v1:showOutBorders()
v1:setBorderStyle(BorderStyle.double)
v2:showOutBorders()
v3:showOutBorders()
v4:showOutBorders()

s.onTap = function(screen, tap)
	s.drawer.drawText(1, 1, "x:" .. tap.x .. " y:" .. tap.y, 0x000000, 0x999999)
end

s:render()