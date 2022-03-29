 local MainLoop = {
  drawer = nil,
  screens = {},
  redrawFrequency = 0.05,
  redrawTime = nil,
  eventsManager = nil
}
package.loaded[...] = MainLoop

require 'ui/base/drawer'
require 'ui/events/events_manager'
local event = require 'event'
 
function MainLoop:topScreen()
  if #self.screens == 0 then 
    return nil 
  else
    return self.screens[#self.screens]
  end
end
 
local function redraw()
  local screen = MainLoop:topScreen()
  if screen ~= nil and MainLoop.drawer ~= nil then
    screen:drawBy(MainLoop.drawer)
  end

  -- Temporal
  drawer.gpu.setBackground(0)
end
 
function MainLoop:start(gpu)
  if gpu == nil then gpu = require('term').gpu() end
  if self.drawer == nil then self.drawer = Drawer:new(gpu) end
  if self.eventsManager == nil then self.eventsManager = require 'ui/events/events_manager' end
 
  self.redrawTime = event.timer(self.redrawFrequency, redraw, math.huge)
  self.eventsManager:startListening()
end
 
function MainLoop:stop(gpu)
  event.cancel(self.redrawTime)
  self.redrawTime = nil
  self.eventsManager:stopListening()
end
 
function MainLoop:pushScreen(screen)
  assert(screen ~= nil, "Try to push nil screen into main loop")
 
  local oldTop = self:topScreen()
  if oldTop ~= nil then oldTop:becameInactive() end
  
  table.insert(self.screens, screen)
  screen:becameActive()
 
  redraw()
end
 
return MainLoop