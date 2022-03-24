require 'utils'
require 'ui/base/gui_screen'
require 'ui/objects/gui_text_field'
require 'ui/objects/gui_button'
require 'ui/geometry/rect'
 
ml = require 'ui/base/main_loop'
term = require 'term'
 
local fullRect = Rect:fullscreenRect(term.gpu())
s = GuiScreen:new(fullRect, 0x000000)

tf1 = GuiTextField:new(Rect:newRaw(3, 3, 30, 1))
tf1:showOutBorders()
tf1.placeholder = "Search..."
s:addChild(tf1)

b1 = GuiButton:new(Rect:newRaw(3, 6, 30, 5), nil, "Push me")
b1.selectedBackground = 0x222222
b1.action = function() b1:setText(b1.label.text .. " more!") end
s:addChild(b1)
b1:showInBorders()

s:showInBorders()

ml:pushScreen(s)
ml:start()