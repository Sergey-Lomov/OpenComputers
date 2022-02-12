require 'utils'
require 'extended_table'

local component = require 'component'
local event = require 'event'

local modem = component.modem
local localizationPort = 2654
local cacheFile = "localizationCache"

local client = {
	cached = {},
	onUpdate = nil,
	processingKeys = {},
	loadingStub = "Translation ...",
}

function client:requestLocalization(keys)
	local keys = table.subtraction(keys, self.processingKeys)
	table.addAll(self.processingKeys, keys)

	local serialized = serialization.serialize(keys)
	modem.broadcast(localizationPort, serialized)
end

function client:localize(key, useRemote)
	if useRemote == nil then useRemote = false end

	local localized = self.cached[key]
	if localized ~= nil then
		return localized
	elseif table.containsValue(self.processingKeys, key) then
		return self.loadingStub or key
	elseif useRemote then
		self:requestLocalization({[1] = key})
	end

	return key
end

local function handleModemEvent(...)
	client:handleModemEvent(...)
end

function client:handleModemEvent(...)
	local _, _, _, _, _, data = table.unpack { ... }

	local dict = serialization.unserialize(data)
	for key, value in pairs(dict) do
		table.removeByValue(self.processingKeys, key)
		self.cached[key] = value
	end

	utils:saveTo(cacheFile, self.cached)
	if self.onUpdate ~= nil then self.onUpdate() end
end

function client:start()
	modem.open(localizationPort)
	event.listen("modem_message", handleModemEvent)
end

function client:stop()
	modem.close(localizationPort)
	event.ignore("modem_message", handleModemEvent)
end

function client:init()
	client.cached = utils:loadFrom(cacheFile)
end

client:init()
return client