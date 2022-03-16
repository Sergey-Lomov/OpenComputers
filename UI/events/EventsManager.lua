-- This manager is bridge between gui events system and OpenOS events system. Starts to listen events automatically.
local EventsManager = {}
package.loaded[...] = EventsManager
 
require 'ui/events/gui_event'
require 'ui/events/keyboard_handler'
local event = require 'event'
local main_loop = require 'ui/base/main_loop'
 
local function handleTap(...)
  local _, screen, x, y, button = table.unpack { ... }
  local tap = TapEvent:new(x, y, button)
  main_loop:topScreen():handleEvent(tap)
end
 
local function handleKey(...)
  local type, keyboard, char, code, sender = table.unpack { ... }
  local key = KeyEvent:new(type == "key_down", char, code, sender)
  KeyboardHandler:handleKey(key)
end
 
function EventsManager:startListening()
  event.listen("touch", handleTap)
  event.listen("key_up", handleKey)
  event.listen("key_down", handleKey)
end
 
function EventsManager:stopListening()
  event.ignore("touch", handleTap)
  event.ignore("key_up", handleKey)
  event.ignore("key_down", handleKey)
end
 
return EventsManager