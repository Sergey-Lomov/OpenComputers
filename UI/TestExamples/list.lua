require 'utils'
require 'ui/base/gui_screen'
require 'ui/objects/gui_list'
require 'ui/objects/title_details_list_cell'
require 'ui/geometry/rect'
 
ml = require 'ui/base/main_loop'
term = require 'term'
 
local fullRect = Rect:fullscreenRect(term.gpu())
s = GuiScreen:new(fullRect, 0x000000)
s:showInBorders()

models = {
	{title = "title 1", details = "details 1"},
	{title = "title 2", details = "details 2"},
	{title = "title 2.1", details = "details 2.1"},
	{title = "title 3", details = "details 3"},
	{title = "title 4", details = "details 4"},
	{title = "title 5", details = "details 5"},
	{title = "title 6", details = "details 6"},
	{title = "title 7", details = "details 7"},
	{title = "title 8", details = "details 8"},
	{title = "title 9", details = "details 9"},
	{title = "title 10", details = "details 10"}
}
l1 = GuiList:new(Rect:newRaw(6, 6, 40, 10), nil, TitleDetailsListCell, models)
l1:showOutBorders()
l1.onCellSelection = function(cell, model) print(model.title) end
s:addChild(l1)

ml:pushScreen(s)
ml:start()