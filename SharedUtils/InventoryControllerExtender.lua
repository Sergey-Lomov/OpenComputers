robot = require("robot")
component = require("component")

local icExtender = {}

local unloadWaiting = 3

function icExtender:extend(ic)

	function ic:firstSlotWhere(side, key, value)
		for i = 1, robot.inventorySize(), 1 do
			local stack = self.getStackInSlot(side, i)
			if stack ~= nil then
				if stack[key] == value then
					return i
				end
			end
		end
		return nil
	end

	function ic:firstInternalSlotWhere(key, value)
		for i = 1, robot.inventorySize(), 1 do
			local stack = self.getStackInInternalSlot(i)
			if stack ~= nil then
				if stack[key] == value then
					return i
				end
			end
		end
		return nil
	end

	function ic:firstEmptySlot(side)
		for i = 1, ic.getInventorySize(side) do
			local stack = self.getStackInSlot(side, i)
			if stack == nil then
				return i
			end
		end
		return nil
	end

	function ic:firstInternalEmptySlot()
		for i = 1, robot.inventorySize(), 1 do
			local stack = self.getStackInInternalSlot(i)
			if stack == nil then
				return i
			end
		end
		return nil
	end

	function ic:getCounts(side) -- Use nil side for robot inventory
		local counts = {}
		
		local size = 0
		if side ~= nil then
			size = ic.getInventorySize(side)
		else 
			size = robot.inventorySize()
		end

		for index = 1, size, 1 do
			local stack = nil

			if side ~= nil then
				stack = ic.getStackInSlot(side, index)
			else 
				stack = ic.getStackInInternalSlot(index)
			end

			if stack ~= nil then
				counts[stack.name] = (counts[stack.name] or 0) + stack.size
			end
		end

		return counts
	end

	function ic:unload(side, validator)
		local size = ic.getInventorySize(side)
		if size == nil then
			print("Try to undload to invalid side")
			return false
		end

		for i = 1, robot.inventorySize() do
			local isEmpty = robot.count(i) == 0
			local valid = true
			if validator ~= nil and not isEmpty then
				local stack = ic.getStackInInternalSlot(i)
				valid = validator(i, stack)
			end

			if isEmpty or not valid then goto continue end

			local target = self:firstEmptySlot(side)
			if target == nil then
				os.sleep(unloadWaiting)
				target = self:firstEmptySlot(side)
				if target == nil then
					print("Inventory for unloading is full")
					return
				end
			end

			robot.select(i)
			ic.dropIntoSlot(side, target)

			::continue::
		end

		return true
	end
end

return icExtender