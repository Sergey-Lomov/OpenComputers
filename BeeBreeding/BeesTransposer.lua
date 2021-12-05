component = require ("component")
analyzer = require ("bees_analyzer")
transposer = component.transposer

princessStackName = "Forestry:beePrincessGE"

transposer.incomeSide = nil
transposer.analyzerSide = nil
transposer.alvearySide = nil
transposer.alvearyPrincessSlot = 1
transposer.alvearyDroneSlot = 2

transposer.emptyIndex = function(side)
	for i = 1, self.getInventorySize(side), 1 do
		local stack = self.getStackInSlot(side, i)
		if stack == nil then return i end
	end
end

transposer.princessIndex = function(side)
	for i = 1, self.getInventorySize(side), 1 do
		local stack = self.getStackInSlot(side, i)
		if stack.name == princessStackName then
			return i
		end
	end
end

-- Income
transposer.incomeEmptyIndex = function()
	if self.incomeSide == nil then return nil end
	return self.emptyIndex(self.incomeSide)
end

transposer.incomePrincessIndex = function()
	if self.incomeSide == nil then return nil end
	return self.princessIndex(self.incomeSide)
end

transposer.getIncomeStack = function(index)
	if self.incomeSide == nil then return nil end
	return self.getStackInSlot(self.incomeSide, index)
end

--Alveary

transposer.alvearyPrincessIndex = function()
	if self.alvearySide == nil then return nil end
	return self.princessIndex(self.alvearySide)
end

transposer.getAlvearyPrincess = function(index)
	local index = self.alvearyPrincessIndex()
	if index == nil then return nil end
	return self.getStackInSlot(self.alvearySide, index)
end


-- Transfering

transposer.toAnalyzerFromIncome = function(index)
	if self.incomeSide == nil then return false end
	if self.analyzerSide == nil then return false end
	return self.transferItem(self.incomeSide, self.analyzerSide, 1, index, analyzer.inSlot) 
end

transposer.toAlvearyFromIncome = function(index)
	if self.incomeSide == nil then return false end
	if self.analyzerSide == nil then return false end
	
	local success = self.transferItem(self.incomeSide, self.alvearySide, 1, index, self.alvearyPrincessSlot)
	if not success then
		success = self.transferItem(self.incomeSide, self.alvearySide, 1, index, self.alvearyDroneSlot)
	end
	
	return success
end

transposer.toAlvearyFromAnalyzer = function(index)
	if self.alvearySide == nil then return false end
	if self.analyzerSide == nil then return false end
	
	local success = self.transferItem(self.analyzerSide, self.alvearySide, 1, analyzer.firstOutSlot, self.alvearyPrincessSlot)
	if not success then
		success = self.transferItem(self.analyzerSide, self.alvearySide, 1, analyzer.firstOutSlot, self.alvearyDroneSlot)
	end

	return success
end

transposer.toOutFromAlveary = function(index)
	if self.incomeSide == nil then return false end
	if self.analyzerSide == nil then return false end
	return self.transferItem(self.incomeSide, self.analyzerSide, 1, index, analyzer.inSlot) 
end

return transposer