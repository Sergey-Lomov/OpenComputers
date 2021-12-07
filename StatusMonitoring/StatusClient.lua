require("utils")
require("status_shared")

local computer = require("computer")
local component = require("component")
local serialization = require("serialization")

local client = {
	modem = nil,
	minPingInterval = 15,
	lastPing = 0,
	pingId = 0,
	pingTitle = "",
	pingAllowableDelay = 30,
	statusStrength = nil
}

local function initClient()
	if next(component.list("modem")) == nil then
		utils:showError("Status client require modem component")
		return
	else
		client.modem = component.modem
	end
end

function client:broadcast(status, payload)
	local initialRange = self.modem.getStrength()
	if self.statusStrength ~= nil then
		self.modem.setStrength(self.statusStrength)
	end
	
	self.modem.broadcast(statusSystemPort, status, payload)

	self.modem.setStrength(initialRange)
end

function client:sendStatus(status, id, message)
	if self.modem == nil then return end
	local payload = {id = id, message = message}
	local serialized = serialization.serialize(payload)
	self:broadcast(status, serialized)
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

function client:cancelStatus(id)
	if self.modem == nil then return end
	self:broadcast(StatusMessageType.CANCEL, id)
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

initClient()

return client