--Created by Serhii Lomov (S_Spirit)

---------------------------------- Configuration
inSide = 1 -- Items provider inventory
outSide = 1 -- Items consumer inventory
schemaSide = 0 -- Inventory which schema should be controlled

-- In this table may be specified slots, which should contains items in provider inventory. 
-- If slot of item not specified, or not contains necessary item, this item will be searched in all slots.
providersSlots = {
  ["IC2:reactorLithiumCell:1"] = 8,
  ["IC2:reactorUraniumDual:1"] = 9
}

-- This table contains list of slots, which should be controlled. If list is empty, program will controll all slots
controllSlots = {}

---------------------------------- Logic

transposer = component.proxy(component.list("transposer")())

schema = {}

function firstSlotWhere(side, key, value)
  local size = transposer.getInventorySize(side)
  if type(size) ~= "number" then
    computer.beep(900, 0.5)
    return nil
  end

  for i = 1, size, 1 do
    local stack = transposer.getStackInSlot(side, i)
    if stack ~= nil then
      if stack[key] == value then
        return i
      end
    end
  end
  return nil
end

function setup()
  if #controllSlots == 0 then
    local schemaSize = transposer.getInventorySize(schemaSide)
    if type(schemaSize) ~= "number" then
      computer.beep(300, 0.5)
      return false
    end

    for i = 1, schemaSize, 1 do
      table.insert(controllSlots, i)
    end
  end

  for _, i in ipairs(controllSlots) do
    local stack = transposer.getStackInSlot(schemaSide, i)
    if stack ~= nil then
      schema[i] = stack.name
    end
  end

  return true
end

function restoreElement(slot, name)
  local inSlot = providersSlots[name]
  if inSlot == nil then
    inSlot = firstSlotWhere(inSide, "name", name)
    if inSlot == nil then return end
  end
  return transposer.transferItem(inSide, schemaSide, 1, inSlot, slot)
end

function moveOut(slot, stack)
  return transposer.transferItem(schemaSide, outSide, stack.maxSize, slot)
end

function checkEmptiness(slot)
  local stack = transposer.getStackInSlot(schemaSide, slot)
  if stack == nil then return end
  moveOut(slot, stack)
end

function checkElement(slot, requiredName)
  local stack = transposer.getStackInSlot(schemaSide, slot)
  
  if stack == nil then 
    restoreElement(slot, requiredName)
    return
  end

  if stack.name ~= requiredName then
    if moveOut(slot, stack) then
      restoreElement(slot, requiredName)
    end
  end
end

function checkSchema()
  for _, i in ipairs(controllSlots) do
    local requiredName = schema[i]
    if requiredName == nil then
      checkEmptiness(i)
    else
      checkElement(i, requiredName)
    end
  end
end

function start()
  while true do
    computer.pullSignal(0.5)
    checkSchema()
  end
end

setup()
start()