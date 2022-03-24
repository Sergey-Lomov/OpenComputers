require 'utils'
require 'ui/base/gui_screen'
require 'ui/objects/gui_text_field'
require 'ui/objects/gui_button'
require 'ui/objects/gui_panel'
require 'ui/geometry/rect'
 
ml = require 'ui/base/main_loop'
term = require 'term'
 
local fullRect = Rect:fullscreenRect(term.gpu())
s = GuiScreen:new(fullRect, 0x000000)
s:showInBorders()

p1 = GuiPanel:new(Rect:newRaw(6, 6, 40, 9), 0x440044, "Demo panel")
p1:showInBorders()
p1.onFrameUpdate = function(p)
	tf1:setFrame(Rect:newRaw(2, 2, p.frame.size.width - 2, 1))
	b1:setFrame(Rect:newRaw(2, 4, p1.frame.size.width - 2, 5))
end
s:addChild(p1)

tf1 = GuiTextField:new(Rect:newRaw(2, 2, p1.frame.size.width - 2, 1))
tf1:showOutBorders()
tf1.placeholder = "Search..."
p1:addChild(tf1)

b1 = GuiButton:new(Rect:newRaw(2, 4, p1.frame.size.width - 2, 5), nil, "Push me top grow up!")
b1.selectedBackground = 0x222222
b1.action = function() 
	p1:setFrame(Rect:newRaw(6, 6, p1.frame.size.width + 1, 9))
end
p1:addChild(b1)
p1:showInBorders()

ml:pushScreen(s)
ml:start()