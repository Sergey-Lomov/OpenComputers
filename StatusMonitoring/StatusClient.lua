require("utils")
require("status_shared")

local computer = require("computer")
local component = require("extended_component")
local serialization = require("serialization")

local historyFile = "statusHistory"

local client = {
	modem = nil,
	minPingInterval = 15,
	lastPing = 0,
	pingId = 0,
	pingTitle = "",
	pingAllowableDelay = 30,
	statusStrength = nil,
	history = {},
	historyLimit = 20
}

function client:init()
	self.modem = component.safePrimary("modem")
	if self.modem == nil then
		utils:showError("Status client require modem component")
		return
	end

	self.history = utils:loadFrom(historyFile)
end

function client:broadcast(status, payload)
	local initialRange = 0
	local useStrengthConstaint = self.modem.isWireless() and self.statusStrength ~= nil
	if useStrengthConstaint then
		initialRange = self.modem.getStrength()
		self.modem.setStrength(self.statusStrength)
	end
	
	self.modem.broadcast(statusSystemPort, status, payload)
	
	if useStrengthConstaint then
		self.modem.setStrength(initialRange)
	end
end

function client:sendStatus(status, id, message)
	if self.modem == nil then return end
	local payload = {id = id, message = message}
	local serialized = serialization.serialize(payload)
	self:broadcast(status, serialized)

	self.history[id] = true
	utils:saveTo(historyFile, self.history)
end

function client:sendSuccess(id, message)
	self:sendStatus(StatusMessageType.SUCCESS, id, message)
end

function client:sendWarning(id, message)
	self:sendStatus(StatusMessageType.WARNING, id, message)
end

function client:sendProblem(id, message)
	self:sendStatus(StatusMessageType.PROBLEM, id, message)
end

function client:cancelStatus(id, filterByHistory)
	if filterByHistory == nil then filterByHistory = true end
	if filterByHistory and self.history[id] == nil then return end

	if self.modem == nil then return end
	self:broadcast(StatusMessageType.CANCEL, id)
	self.history[id] = nil
	utils:saveTo(historyFile, self.history)
end

function client:sendPing(forced)
	forced = forced or false

	if self.modem == nil then return end
	local isToFast = computer.uptime() - self.lastPing < self.minPingInterval
	if isToFast and not forced then return end

	local payload = {
		id = self.pingId,
		title = self.pingTitle,
		allowableDelay = self.pingAllowableDelay
	}
	local serialized = serialization.serialize(payload)

	self:broadcast(StatusMessageType.PING, serialized)
	self.lastPing = computer.uptime()
end

function client:cancelPing()
	if self.modem == nil then return end
	self:broadcast(StatusMessageType.CANCEL_PING, self.pingId)
	self.lastPing = 0
end

client:init()

return client