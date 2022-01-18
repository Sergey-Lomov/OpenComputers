local component = require ("component")
local utils = require ("utils")

function component.shortProxy(shortId)
	local id = component.get(shortId)
	if id == nil then
		utils:showError("Can't find full id for short: " .. shortId)
		return nil
	end
	return component.proxy(id)
end

function component.safePrimary(type)
	if component.isAvailable(type) then
		return component[type]
	else
		return nil
	end
end

return component