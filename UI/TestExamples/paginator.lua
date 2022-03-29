require 'utils'
require 'ui/base/gui_screen'
require 'ui/objects/gui_paginator'
require 'ui/objects/gui_text_field'
require 'ui/objects/gui_button'
require 'ui/objects/gui_panel'
require 'ui/objects/gui_label'
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

p2 = GuiLabel:new(nil, nil, "Page 2")
p3 = GuiLabel:new(nil, nil, "Page 3")

local prRect = fullRect:withGap(1)
pr = GuiPaginator:new(prRect, nil, {p1, p2, p3})
s:addChild(pr)

ml:pushScreen(s)
ml:start()