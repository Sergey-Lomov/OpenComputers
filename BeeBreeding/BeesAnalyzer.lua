component = require ("component")
analyzer = component.forestry_analyzer

analyzer.inSlot = 3
analyzer.firstOutSlot = 9

analyzer.analyzedSpecies = function()
	local stack = self.getStackInSlot(self.firstOutSlot)
	return stack.individual.active.species
end

return  analyzer