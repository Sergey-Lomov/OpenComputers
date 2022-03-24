-- This manager control focus switching and key event routing
local keyboard = require 'keyboard'
 
KeyboardHandler = {
  responders = {},
  responderIndex = nil,
}
 
function KeyboardHandler:handleKey(key)
  if key.isDown and #self.responders > 0 and key.code == keyboard.keys.tab then
    self:selectNextResponder()
    return
  end
 
  key.isControl = keyboard.isControl(key.char)
  self.responders[self.responderIndex]:onKey(key)
end

function KeyboardHandler:setResponderIndex(index)
  if self.responderIndex == index then return end

  if self.responderIndex ~= nil then
    self.responders[self.responderIndex]:firstResponderWasReleased()
  end

  self.responderIndex = index

  if self.responderIndex ~= nil then
    self.responders[self.responderIndex]:firstResponderWasBecame()
  end
end
 
function KeyboardHandler:selectNextResponder()
  if #self.responders == 0 then
    self:setResponderIndex(nil)
    return
  end

  if self.responderIndex == nil then
    self:setResponderIndex(1)
  elseif self.responderIndex == #self.responders then
    self:setResponderIndex(nil)
  else
    self:setResponderIndex(self.responderIndex + 1)
  end
end
 
function KeyboardHandler:clearResponders()
  self:setResponderIndex(nil)
  self.responders = {}
end

function KeyboardHandler:setFirstResponder(responder)
  if responder == nil then 
    self:setResponderIndex(nil)
    return 
  end

  for index, iterResponder in ipairs(self.responders) do
    if responder == iterResponder then
      self:setResponderIndex(index)
    end
  end
end
 
function KeyboardHandler:setResponders(responders)
  self:setResponderIndex(nil)
  self.responders = responders
 
  local sort = function(r1, r2)
    return (r1.responderOrder or 0) < (r2.responderOrder or 0)
  end
  table.sort(self.responders, sort)
end
 
function KeyboardHandler:isFirstResponder(responder)
  if self.responderIndex == nil then return false end
  return self.responders[self.responderIndex] == responder
end