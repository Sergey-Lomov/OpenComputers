local incomeInterfaceExtender = {
	timing = {
		export = 1
	}
}

function incomeInterfaceExtender:extend(interface)

	interface.princessSlot = 1
	interface.droneSlot = 2

	function interface:setupPrincessFromDB(database, size)
		for index = 1, size, 1 do
			self.setInterfaceConfiguration(self.princessSlot, database, index)
			os.sleep(incomeInterfaceExtender.timing.export)
			if self.getStackInSlot(self.princessSlot) ~= nil then
				return true
			end
		end

		return false
	end

	function interface:setupDroneFromDB(database, type)
		local index = database.indexForName(type)
		if index == nil then return false end
		self.setInterfaceConfiguration(self.droneSlot, database, index)
		return true
	end
end

return incomeInterfaceExtender