require 'utils'
require 'ui/base/gui_screen'
require 'ui/objects/gui_label'
require 'ui/utils/line_breaking'
require 'ui/base/events_manager'

local term = require 'term'

tapHandler = function(label, tap) 
	if tap.button == 0 then
		label.frame.size.width = label.frame.size.width + 1
	else
		label.frame.size.width = label.frame.size.width - 1
	end
	label:handleFrameUpdate()
	s:render()
end

s = GuiScreen:new(term.gpu())
l1 = GuiLabel:new(Rect:newRaw(10, 6, 20, 3), 0x440000, "Label text with big additional amount of chars")
l1.breakMode = LineBreakMode.none
l1.onTap = tapHandler
s:addChild(l1)

l2 = GuiLabel:new(Rect:newRaw(10, 12, 20, 3), 0x660066, "Label text with big additional amount of chars")
l2.breakMode = LineBreakMode.cut
l2.onTap = tapHandler
s:addChild(l2)

l3 = GuiLabel:new(Rect:newRaw(10, 18, 20, 3), 0x999900, "Label text with big additional amount of chars")
l3.breakMode = LineBreakMode.truncateTail
l3.onTap = tapHandler
s:addChild(l3)

l4 = GuiLabel:new(Rect:newRaw(10, 24, 20, 3), 0x009999, "Label text with big additional amount of chars")
l4.breakMode = LineBreakMode.charWrap
l4.onTap = tapHandler
s:addChild(l4)
l4:showOutBorders()

l5 = GuiLabel:new(Rect:newRaw(10, 30, 20, 3), 0x004499, "Label text with big additional amount of chars")
l5.breakMode = LineBreakMode.wordWrap
l5.onTap = tapHandler
s:addChild(l5)

s:showInBorders()
s:render()