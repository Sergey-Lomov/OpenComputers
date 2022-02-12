require 'utils'

local component = require 'component'
local event = require 'event'

local dictPort = 2653
local dictionaryFile = "dict"

local service = {
	dict = {},
	dictSize = 0
}

local function handleModemEvent(...)
	service:handleModemEvent(...)
end

function service:handleModemEvent(...)
	local _, _, requester, _, _, id, data = table.unpack { ... }
	local keys = serialization.unserialize(data)
	if keys == nil then return end

	local result = {}
	for _, key in ipairs(keys) do
		result[key] = self.dict[key]
	end

	local serialized = serialization.serialize(result)
	component.modem.send(requester, dictPort, id, serialized)
end

function service:start()
	print("Start dictionary loading")
	self.dict = utils:loadFrom(dictionaryFile, {}, true)
	print("Finish dictionary loading")
	
	for k, v in pairs(self.dict) do 
		self.dictSize = self.dictSize + 1
	end
	
	component.modem.open(dictPort)
	event.listen("modem_message", handleModemEvent)

	print("Service started")
end

function service:stop()
	component.modem.close(dictPort)
	event.ignore("modem_message", handleModemEvent)
end

return service