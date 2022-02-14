require 'utils'
require 'extended_table'

local component = require "component"

local statsPort = 5784
local configFile = "config"
local statsFile = "stats"
local dbUpdateFrequency = 60

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
	lastDBUpdate = 0,
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
			stableDuration = 0,
			points = {{time = 0, items={}}},
			pointInterval = 60,
			maxPoints = 60,
			registrationTime = utils:realWorldSeconds()
		}
		self.providers[data.id] = provider
	end

	provider.title = data.title
	provider.maxDelay = data.maxDelay
	provider.maxDelay = data.maxPoints or provider.maxPoints
	provider.pointInterval = data.pointInterval or provider.pointInterval

	self:updateDB()
end

function manager:updateDB(forced)
	if forced == nil then forced = false end

	local timeToUpdate = utils:realWorldSeconds() - self.lastDBUpdate > dbUpdateFrequency
	if timeToUpdate or forced then
		self.lastDBUpdate = utils:realWorldSeconds()
		utils:saveTo(statsFile, self.providers)
	end
end

function manager:production(provider, title)
	local firstPoint = provider.points[1]
	local lastPoint = provider.points[#provider.points]
	local firstCount = firstPoint.items[title] or 0
	local lastCount = lastPoint.items[title] or 0

	return (lastCount - firstCount) / (lastPoint.time - firstPoint.time)
end

function manager:addPoint(provider)
	local newPoint = {
		time = provider.stableDuration,
		items = table.mapByKey(provider.items, "stableTotal")
	}

	if #provider.points >= provider.maxPoints then
		table.remove(provider.points, 1)
	end
	table.insert(provider.points, newPoint)
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
	
	for label, amount in pairs(data.items) do
		local item = provider.items[label] or {total = 0, stableTotal = 0}
		item.total = item.total + amount

		if isStableStream then
			item.stableTotal = item.stableTotal + amount
		end

		provider.items[label] = item
	end

	if isStableStream then
		provider.stableDuration = provider.stableDuration + delay
		local lastTime = provider.points[#provider.points].time 
		if provider.stableDuration - lastTime >= provider.pointInterval then
			self:addPoint(provider)
		end
	end

	provider.lastStatsUpdate = currentTime
	self:updateDB()
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