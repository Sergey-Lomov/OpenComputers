require 'ui/utils/asserts'
 
BorderStyle = {}
BorderStyle.typeLabel = "BorderStyle"
 
-- Public
 
function BorderStyle:new(noPatternSymbol, symbols)
  local style = {}
  self.__index = self
  setmetatable(style, self)
 
  style.noPatternSymbol = noPatternSymbol or ""
  style.symbols = symbols or {}
 
  return style
end
 
function BorderStyle:pattern(top, left, right, bottom)
  return (top and "1" or "0") .. (left and "1" or "0") .. (right and "1" or "0") .. (bottom and "1" or "0")
end
 
function BorderStyle:addSymbol(top, left, right, bottom, symbol)
  local pattern = self:pattern(top, left, right, bottom)
  self.symbols[pattern] = symbol
end
 
function BorderStyle:verticalSymbol()
  local pattern = self:pattern(true, false, false, true)
  return self.symbols[pattern]
end
 
function BorderStyle:horizontalSymbol()
  local pattern = self:pattern(false, true, true, false)
  return self.symbols[pattern]
end
 
-- Styles
BorderStyle.single = BorderStyle:new("", {
  ["0000"] = " ", ["0001"] = "│", ["0010"] = "─", ["0011"] = "┌",
  ["0100"] = "─", ["0101"] = "┐", ["0110"] = "─", ["0111"] = "┬",
  ["1000"] = "│", ["1001"] = "│", ["1010"] = "└", ["1011"] = "├",
  ["1100"] = "┘", ["1101"] = "┤", ["1110"] = "┴", ["1111"] = "┼"
})
 
BorderStyle.double = BorderStyle:new("", {
  ["0000"] = " ", ["0001"] = "║", ["0010"] = "═", ["0011"] = "╔",
  ["0100"] = "═", ["0101"] = "╗", ["0110"] = "═", ["0111"] = "╦",
  ["1000"] = "║", ["1001"] = "║", ["1010"] = "╚", ["1011"] = "╠",
  ["1100"] = "╝", ["1101"] = "╣", ["1110"] = "╩", ["1111"] = "╬"
})
 
BorderStyle.bold = BorderStyle:new("", {
  ["0000"] = " ", ["0001"] = "┃", ["0010"] = "━", ["0011"] = "┏",
  ["0100"] = "━", ["0101"] = "┓", ["0110"] = "━", ["0111"] = "┳",
  ["1000"] = "┃", ["1001"] = "┃", ["1010"] = "┗", ["1011"] = "┣",
  ["1100"] = "┛", ["1101"] = "┫", ["1110"] = "┻", ["1111"] = "╋"
})
 
BorderStyle.dash = BorderStyle:new("", {
  ["0000"] = " ", ["0001"] = "┊", ["0010"] = "┄", ["0011"] = "┌",
  ["0100"] = "┄", ["0101"] = "┐", ["0110"] = "┄", ["0111"] = "┬",
  ["1000"] = "┊", ["1001"] = "┊", ["1010"] = "└", ["1011"] = "├",
  ["1100"] = "┘", ["1101"] = "┤", ["1110"] = "┴", ["1111"] = "┼"
})
 
BorderStyle.boldDash = BorderStyle:new("", {
  ["0000"] = " ", ["0001"] = "┋", ["0010"] = "┅", ["0011"] = "┏",
  ["0100"] = "┅", ["0101"] = "┓", ["0110"] = "┅", ["0111"] = "┳",
  ["1000"] = "┋", ["1001"] = "┋", ["1010"] = "┗", ["1011"] = "┣",
  ["1100"] = "┛", ["1101"] = "┫", ["1110"] = "┻", ["1111"] = "╋"
})
 
BorderStyle.default = BorderStyle.single