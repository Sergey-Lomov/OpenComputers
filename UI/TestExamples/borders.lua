require 'utils'
require 'ui/base/gui_screen'
require 'ui/base/events_manager'
require 'ui/geometry/grid_line'

local term = require 'term'

p1 = nil
p2 = nil

s = GuiScreen:new(term.gpu())
be = s.borderEngine

addLine = function(x1, y1, x2, y2, render)
	be:addLineCoords(x1, y1, x2, y2)
	if render == nil or render then
		s:render()
	end
end

s.onTap = function(screen, tap)
	if tap.button == 0 then
		p1 = Point:new(tap.x, tap.y)
	else
		p2 = Point:new(tap.x, tap.y)
	end

	if p1 ~= nil and p2 ~= nil then
		s.borderEngine:addLinePoints(p1, p2)
		p1 = nil
		p2 = nil
		s:render()
	end
end

s:render()