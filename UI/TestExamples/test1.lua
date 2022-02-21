require 'ui/base/gui_screen'
require 'ui/objects/gui_label'
require 'ui/utils/line_breaking'

local term = require 'term'

s = GuiScreen:new(term.gpu())
l1 = GuiLabel:new(Rect:newRaw(10, 6, 20, 3), 0x440000, "Label text with big additional amount of chars")
l1.breakMode = LineBreakMode.none
s:addChild(l1)

s:render()