require("utils")
require("status_shared")

local event = require("event")
local component = require("component")
local computer = require("computer")
local term = require("term")
local serialization = require("serialization")
local ui = require("uimanager")

local stateFile = "status_state"
local gpu = term.gpu()

local statusHandler = {
	successes = {},
	warnings = {},
	problems = {},
	lambs = {
		successes = nil,
		warnings = nil,
		problems = nil,
	},
	pingWaiters = {},
	timer = nil,

	updateFrequency = 10,
	screenWidth = 60,
	screenHeight = 20
}

Phrases = {
	pingTitle = "Роботы",
	successesTitle = "Успехи",
	warningsTitle = "Проблемы",
	problemsTitle = "Критические проблемы",
    pingFailed = "Потеряна связь с "
}

Colors = {
	title = 0xFFFFFF,
	problem = 0xFF0000,
    warning = 0xAAAA00,
    success = 0x00AA00,
    pingSuccess = 0x006600,
    pingFailed = 0x660000
}

-- Private methods
function statusHandler:saveState()
	local state = {
		successes = self.successes,
		warnings = self.warnings,
		problems = self.problems,
		pingWaiters = self.pingWaiters
	}
	utils:saveTo(stateFile, state)
end

function statusHandler:loadState()
	local state = utils:loadFrom(stateFile)
	self.successes = state.successes or {}
	self.warnings = state.warnings or {}
	self.problems = state.problems or {}
	self.pingWaiters = state.pingWaiters or {}
end

function statusHandler:handlePingRequest(request)
	local waiter = {
		title = request.title,
		allowableDelay = request.allowableDelay,
		lastPing = computer.uptime()
	}
	self.pingWaiters[request.id] = waiter
	self:saveState()
end

function statusHandler:handlePing(enityId)
	local waiter = self.pingWaiters[enityId]
	if waiter ~= nil then
		waiter.lastPing = computer.uptime()
		self:cancelStatus(enityId)
	end
	self:saveState()
end

function statusHandler:handleStatus(type, id, message)
	local typeTable = {}
	if type == StatusMessageType.SUCCESS then typeTable = self.successes
		elseif type == StatusMessageType.WARNING then typeTable = self.warnings
		elseif type == StatusMessageType.PROBLEM then typeTable = self.problems
	end

	if typeTable[id] ~= message then
		typeTable[id] = message
		self:saveState()
	end
end

function statusHandler:cancelStatus(id)
	self.successes[id] = nil
	self.warnings[id] = nil
	self.problems[id] = nil
	self:saveState()
end

function statusHandler:update()
	term.clear()
		
	self:updateAndShowPingWaiters()
	self:showStatuses()
	self:updateLambs()
	if ui:isTextColorRestorable() then
		ui:restoreInitialTextColor()
	end

	ui:cursorToBottom()
end

function statusHandler:removeWaiterByTitle(title)
	for id, waiter in pair(self.pingWaiters) do
		if waiter.title == title then
			self.pingWaiters[id] = nil
		end
	end
	self:saveState()
end

function statusHandler:updateAndShowPingWaiters()
	if next(self.pingWaiters) == nil then return end

	ui:setTextColor(Colors.title)
	ui:printHeader(Phrases.pingTitle, "=")

	for id, waiter in pairs(self.pingWaiters) do
		local color = Colors.pingSuccess
		local allowableTime = waiter.lastPing + waiter.allowableDelay
		
		if computer.uptime() > allowableTime then
			local message = Phrases.pingFailed .. waiter.title
			self:handleStatus(StatusMessageType.PROBLEM, id, message)
			color = Colors.pingFailed
		end

		ui:setTextColor(color)
		print(waiter.title)
	end
end

function statusHandler:showStatusesFromTable(statusesTable, title, color)
	if next(statusesTable) == nil then return end

	ui:setTextColor(Colors.title)
	ui:printHeader(title, "=")

	ui:setTextColor(color)
	for id, message in pairs(statusesTable) do
		print(message)
	end
end

function statusHandler:showStatuses()
	self:showStatusesFromTable(self.successes, Phrases.successesTitle, Colors.success)
	self:showStatusesFromTable(self.warnings, Phrases.warningsTitle, Colors.warning)
	self:showStatusesFromTable(self.problems, Phrases.problemsTitle, Colors.problem)
end

function statusHandler:updateLambs()

end

function statusHandler:handleModemEvent(...)
	local _,_,_,_,_,type,data = table.unpack { ... }
    if type == StatusMessageType.PING_REQUEST then
    	local payload = serialization.unserialize(data)
        self:handlePingRequest(payload)
    elseif type == StatusMessageType.PING then
        self:handlePing(data)
    elseif type == StatusMessageType.CANCEL then
        self:cancelStatus(data)
    else
    	local payload = serialization.unserialize(data)
        self:handleStatus(type, payload.id, payload.message)
    end
end

local function handleModemEvent(...)
	statusHandler:handleModemEvent(...)
end

-- Public methods

function statusHandler:start()
	self:loadState()
	for id, waiter in pairs(self.pingWaiters) do
		waiter.lastPing = computer.uptime()
		self.problems[id] = nil
	end

	ui:setScreenSize(self.screenWidth, self.screenHeight)

	event.listen("modem_message", handleModemEvent)
	component.modem.open(statusSystemPort)

	self.timer = event.timer(self.updateFrequency, function() self:update() end, math.huge)
	self:update()
end

function statusHandler:stop()
	event.ignore("modem_message", handleModemEvent)
	component.modem.close(statusSystemPort)
	event.cancel(self.timer)
	self.timer = nil

	ui:restoreScreenSize()
end

return statusHandler