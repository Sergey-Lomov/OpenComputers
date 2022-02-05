require 'utils'

local component = require "component"

local statsPort = 5784
local configFile = "config"
local statsFile = "stats"

StatsMessageType = {
	REGISTRATION = 0,
	STATS = 1
}

Phrases = {
	noModem = "Modem required",
	statsForMissedId = "Get stats for unregistered id"
}

local manager = {
	config = nil,
	providers = {},
	onError = nil, -- Callback with one string parameter - error message
	onUpdate = nil, -- Callback with no parameters
}

function manager:init()
	manager.config = utils:loadFrom(configFile)
	manager.providers = utils:loadFrom(statsFile)
end

-- This wrapper should be used for cancel listening
local function handleModemEvent(...)
	manager:handleModemEvent(...)
end

function manager:handleRegistration(data)
	local provider = self.providers[data.id]
	if provider == nil then
		provider = {
			items = {},
			lastStatsUpdate = 0,
			sessionDuration = 0,
			registrationTime = utils:realWorldSeconds()
		}
		self.providers[data.id] = provider
	end

	provider.title = data.title
	provider.maxDelay = data.maxDelay

	utils:saveTo(statsFile, self.providers)
end

function manager:handleStats(data)
	local provider = self.providers[data.id]
	if provider == nil then
		if self.onError ~= nil then self.onError(Phrases.statsForMissedId) end
		return
	end

	local currentTime = utils:realWorldSeconds()
	local delay = currentTime - provider.lastStatsUpdate
	local isStableStream = delay <= provider.maxDelay
	if isStableStream then
		provider.sessionDuration = provider.sessionDuration + delay
	end

	for label, amount in pairs(data.items) do
		local item = provider.items[label] or {total = 0, stableTotal = 0}
		item.total = item.total + amount

		if isStableStream then
			item.stableTotal = item.stableTotal + amount
		end

		provider.items[label] = item
	end

	provider.lastStatsUpdate = currentTime

	utils:saveTo(statsFile, self.providers)
end

function manager:handleModemEvent(...)
	local _, _, _, _, _, code, data = table.unpack { ... }

    if code == StatsMessageType.REGISTRATION then
    	local payload = serialization.unserialize(data)
        self:handleRegistration(payload)
    elseif code == StatsMessageType.STATS then
    	local payload = serialization.unserialize(data)
    	self:handleStats(payload)
    end

    if self.onUpdate ~= nil then self.onUpdate() end
end

function manager:start()
	local modem = component.modem
	if not modem then 
		if self.onError ~= nil then self.onError(Phrases.noModem) end
		return false, Phrases.noModem 
	end

	modem.open(statsPort)
	event.listen("modem_message", handleModemEvent)
end

function manager:stop()
	component.modem.close(statsPort)
	event.ignore("modem_message", handleModemEvent)
end

manager:init()
return manager