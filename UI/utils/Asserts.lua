local messageFormat = "bad argument #%d (%s expected, got %s)"
 
function typeAssert(value, requiredType, paramIndex)
  if type(requiredType) == "string" then
    local message = string.format(messageFormat, paramIndex, requiredType, type(value))
    assert(type(value) == requiredType, message)
  else
    local provided = type(value)
    if provided == "table" then
      provided = value.typeLabel or "unknown(povided)"
    end
 
    local require = requiredType.typeLabel or "unknown(required)"
    local message = string.format(messageFormat, paramIndex, require, provided)
    assert(getmetatable(value) == requiredType, message)
  end
end