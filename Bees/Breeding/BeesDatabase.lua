local beesDatabaseExtender = {
	defaultSize = 81
}

function beesDatabaseExtender:extend(db, size) 

	db.size = size or beesDatabaseExtender.defaultSize

	function db:indexForName(name)
		for i = 1, self.size, 1 do
			local stack = self.get(i)
			if stack ~= nil then
				if stack.individual.displayName == name then
					return i
				end
			end
		end
	end
end

return beesDatabaseExtender