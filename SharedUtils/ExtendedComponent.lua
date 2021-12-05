component = require ("component")
utils = require ("utils")

function component:shortProxy(shortId)
	local id = self.get(shortId)
	if id == nil then
		utils:showError("Can't find full id for short: " .. shortId)
		return nil
	end
	return self.proxy(id)
end

return component