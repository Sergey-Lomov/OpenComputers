require 'utils'
require 'extended_table'

local component = require 'component'
local event = require 'event'

local modem = component.modem
local localizationPort = 2654
local maxKeysInRequest = 25 -- Prevent problems with extrasize of packages
local cacheFile = "localizationCache"

local client = {
	cached = {},
	onUpdate = nil,
	processingKeys = {},
	loadingStub = "Translation ...",
}


function client:preload(keys)
	local cachedKeys = table.keys(self.cached)
	local uncached = table.subtractionArray(keys, cachedKeys)
	local required = table.subtractionArray(uncached, self.processingKeys)
	if #required > 0 then
		client:requestLocalization(required)
	end
end

function client:requestLocalization(keys)
	local keys = table.subtractionArray(keys, self.processingKeys)
	table.addAll(self.processingKeys, keys)

	local packageKeys = {}
	for _, key in ipairs(keys) do
		if #packageKeys < maxKeysInRequest then
			table.insert(packageKeys, key)
		else
			self:requestLocalizationPackage(packageKeys)
			packageKeys = {}
		end
	end

	if #packageKeys > 0 then
		self:requestLocalizationPackage(packageKeys)
	end
end

function client:requestLocalizationPackage(keys)
	local serialized = serialization.serialize(keys)
	modem.broadcast(localizationPort, serialized)
end

function client:localize(key, allowRemote)
	if allowRemote == nil then allowRemote = true end

	local localized = self.cached[key]
	if localized ~= nil then
		return localized
	elseif table.containsValue(self.processingKeys, key) then
		return self.loadingStub or key
	elseif allowRemote then
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
	if #dict ~= 0 then return end -- If data is array, this is not response by server, but request from another client

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
client:start()

return client