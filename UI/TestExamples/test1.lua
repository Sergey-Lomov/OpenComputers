require 'ui/base/gui_screen'
require 'ui/objects/gui_label'
require 'ui/utils/line_breaking'

local term = require 'term'

s = GuiScreen:new(term.gpu())
l1 = GuiLabel:new(Rect:new(10, 6, 20, 3), 0x440000, "Label text with big additional amount of chars")
l1.breakMode = LineBreakMode.none
s:addChild(l1)

l2 = GuiLabel:new(Rect:new(40, 6, 20, 3), 0x660066, "Label text with big additional amount of chars")
l2.breakMode = LineBreakMode.cut
s:addChild(l2)

l3 = GuiLabel:new(Rect:new(10, 16, 20, 3), 0x999900, "Label text with big additional amount of chars")
l3.breakMode = LineBreakMode.truncateTail
s:addChild(l3)

l4 = GuiLabel:new(Rect:new(40, 16, 20, 3), 0x009999, "Label text with big additional amount of chars")
l4.breakMode = LineBreakMode.charWrap
s:addChild(l4)

l5 = GuiLabel:new(Rect:new(10, 26, 20, 3), 0x004499, "Label text with big additional amount of chars")
l5.breakMode = LineBreakMode.wordWrap
s:addChild(l5)

s:render()