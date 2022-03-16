require 'ui/base/gui_object'
local unicode = require 'unicode'
local keyboard = require 'keyboard'
 
GuiTextField = GuiObject:new()
GuiTextField.__index = GuiTextField
GuiTextField.typeLabel = "GuiTextField"
GuiTextField.defaultTextColor = 0xFFFFFF
 
function GuiTextField:new(frame, background, text)
  local field = GuiObject:new(frame, background)
  setmetatable(field, self)
 
  field.text = text or ""
  field.cursor = 1
  field.cursorInverted = false
  field.textColor = GuiTextField.defaultTextColor
  
  field.onFinishEditing = nil -- This may be handler with onr parameter - field itself
 
  return field
end
 
function GuiTextField:drawBy(drawer)
  getmetatable(getmetatable(self)).drawBy(self, drawer)
 
  local text = unicode.sub(self.text, 1, self.frame.size.width)
  local origin = self.frame.origin
  drawer:drawText(origin.x, origin.y, text, self.background, self.textColor)
 
  if KeyboardHandler:isFirstResponder(self) then
    local cursorChar = unicode.sub(text, self.cursor, self.cursor)
    if cursorChar == "" then cursorChar = "█" end

    if self.cursorInverted then
      drawer:drawText(origin.x + self.cursor - 1, origin.y, cursorChar, self.textColor, self.background)
      self.cursorInverted = false
    else
      --drawer:drawText(origin.x + self.cursor - 1, origin.y, cursorChar, self.background, self.textColor)
      self.cursorInverted = true
    end
    self:setNeedRender() 
  end
end
 
function GuiObject:firstResponderWasBecame()
  self.cursor = unicode.len(self.text) + 1
  self:setNeedRender()
end
 
function GuiTextField:firstResponderWasReleased()
  if self.onFinishEditing ~= nil then self.onFinishEditing(self) end
end
 
function GuiTextField:onTap(tap)
  getmetatable(getmetatable(self)).drawBy(self, drawer)
 
  if KeyboardHandler:isFirstResponder(self) then
    self.cursor = tap.x
  else
    self:becameFirstResponder()
  end
end
 
function GuiTextField:onKey(key)
  if not key.isDown then return end
 
  if not key.isControl then
    self:insert(unicode.char(key.char))
    return
  end
 
  if key.code == keyboard.keys.enter then
    self:releaseFirstResponder()
  end
end
 
function GuiTextField:insert(str)
  local left = unicode.sub(self.text, 1, self.cursor)
  local right = unicode.sub(self.text, self.cursor + 1)
  self.text = left .. str .. right
  self.cursor = unicode.len(left .. str) + 1
end
 
function GuiTextField:__tostring()
  return "<TextField text: " .. self.text .. " frame: " .. tostring(self.frame) .. ">"
end