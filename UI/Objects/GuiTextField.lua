require 'ui/base/gui_object'
require 'ui/events/keyboard_handler'
require 'ui/objects/cursor'
local unicode = require 'unicode'
local keyboard = require 'keyboard'
 
GuiTextField = GuiObject:new()
GuiTextField.__index = GuiTextField
GuiTextField.typeLabel = "GuiTextField"
GuiTextField.defaultTextColor = 0xFFFFFF
GuiTextField.placeholderColor = 0x888888
 
function GuiTextField:new(frame, background, text)
  local field = GuiObject:new(frame, background)
  setmetatable(field, self)
 
  field.text = text or ""
  field.cursor = Cursor:new()
  field.cursorPos = 1
  field.textColor = GuiTextField.defaultTextColor
  field.placeholder = nil
  field.placeholderColor = GuiTextField.placeholderColor
  
  field.onFinishEditing = nil -- This may be handler with onr parameter - field itself

  field.cursor.isHidden = true
  field:addChild(field.cursor)
 
  return field
end

function GuiTextField:setCursorPosition(pos)
  pos = math.min(pos, unicode.len(self.text) + 1, self.frame.size.width)
  pos = math.max(1, pos)
  if pos == self.cursorPos then return end

  self.cursorPos = pos
  self.cursor.frame.origin.x = pos
  local underchar = unicode.sub(self.text, pos, pos)
  if underchar == "" then underchar = " " end
  self.cursor:setUnderchar(underchar)
  self:setNeedRender(false)
end
 
function GuiTextField:drawSelf(drawer)
  getmetatable(getmetatable(self)).drawSelf(self, drawer)

  local origin = self.frame.origin
  local background = self:inheritedBackground() 
  if self.text == "" and not KeyboardHandler:isFirstResponder(self) then 
    drawer:drawText(origin.x, origin.y, self.placeholder, background, self.placeholderColor)
  else 
    drawer:drawText(origin.x, origin.y, self.text or "", background, self.textColor)
  end
end

function GuiObject:firstResponderWasBecame()
  self.cursor.isHidden = false
  self:setCursorPosition(unicode.len(self.text) + 1)
end
 
function GuiTextField:firstResponderWasReleased()
  self.cursor.isHidden = true
  if self.onFinishEditing ~= nil then self.onFinishEditing(self) end
  self:setNeedRender(false)
end
 
function GuiTextField:onTap(tap)
  if KeyboardHandler:isFirstResponder(self) then
    self:setCursorPosition(tap.x)
  else
    self:becameFirstResponder()
    self:setNeedRender(false)
  end
end
 
function GuiTextField:onKey(key)
  if not key.isDown then return end
 
  if key.code == keyboard.keys.left then
    self:setCursorPosition(self.cursorPos - 1)
  elseif key.code == keyboard.keys.right then
    self:setCursorPosition(self.cursorPos + 1)
  elseif not key.isControl then
    self:insert(unicode.char(key.char))
  elseif key.code == keyboard.keys.enter then
    self:releaseFirstResponder()
  elseif key.code == keyboard.keys.back then
    self:handleBackspace()
  elseif key.code == keyboard.keys.delete then
    self:handleDelete()
  end
end
 
function GuiTextField:insert(str)
  local left = unicode.sub(self.text, 1, self.cursorPos - 1)
  local right = unicode.sub(self.text, self.cursorPos)
  local estimatedText = left .. str .. right
  self.text = unicode.sub(estimatedText, 1, self.frame.size.width - 1)
  local newPosition = unicode.len(left .. str) + 1
  self:setCursorPosition(newPosition)
end

function GuiTextField:handleBackspace()
  if self.cursorPos == 1 then return end

  local left = unicode.sub(self.text, 1, self.cursorPos - 2)
  local right = unicode.sub(self.text, self.cursorPos)
  self.text = left .. right
  self:setCursorPosition(self.cursorPos - 1)
end

function GuiTextField:handleDelete()
  local left = unicode.sub(self.text, 1, self.cursorPos)
  local right = unicode.sub(self.text, self.curscursorPosor + 2)
  self.text = left .. right
  self:setNeedRender(false)
end
 
function GuiTextField:__tostring()
  return "<TextField text: " .. self.text .. " frame: " .. tostring(self.frame) .. ">"
end