-- This manager control focus switching and key event routing
local keyboard = require 'keyboard'
 
KeyboardHandler = {
  responders = {},
  responderIndex = nil,
}
 
function KeyboardHandler:handleKey(key)
  if self.responderIndex == nil then
    if #self.responders > 0 and key.code == keyboard.keys.tab then
      self:selectNextResponder()
      return
    end
  end
 
  key.isControl = keyboard.isControl(key.char)
  self.responders[self.responderIndex]:onKey(key)
end
 
function KeyboardHandler:selectNextResponder()
  if self.responderIndex ~= nil then
    self.responders[self.responderIndex]:firstResponderWasReleased()
  end
 
  if self.responderIndex == nil or responderIndex == #self.responders then
    self.responderIndex = 1
  else
    self.responderIndex = self.responderIndex + 1
  end
 
  self.responders[self.responderIndex]:firstResponderWasBecame()
end
 
function KeyboardHandler:clearResponders()
  if self.responderIndex ~= nil then
    self.responders[self.responderIndex]:firstResponderWasReleased()
  end
 
  self.responders = {}
  self.responderIndex = nil
end
 
function KeyboardHandler:setResponders(responders)
  self.responders = responders
 
  local sort = function(r1, r2)
    return (r1.responderOrder or 0) < (r2.responderOrder or 0)
  end
  table.sort(self.responders, sort)
  
  self.responderIndex = nil
end
 
function KeyboardHandler:setFirstResponder(responder)
  if responder == nil then self.responderIndex = nil return end
  for index, iterResponder in ipairs(self.responders) do
    if responder == iterResponder then
      self.responderIndex = index
      responder:firstResponderWasBecame()
    end
  end
end
 
function KeyboardHandler:isFirstResponder(responder)
  if self.responderIndex == nil then return false end
  return self.responders[self.responderIndex] == responder
end