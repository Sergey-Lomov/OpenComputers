require 'GuiScreen'
require 'GuiLabel'

local term = require 'term'

s = GuiScreen:new(term.gpu())
l1 = GuiLabel:new(Rect:new(10, 6, 20, 3), 0xAA0099, "Label 1 text")
s:addChild(l1)
s:render()