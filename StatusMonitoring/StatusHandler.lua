require("utils")
require("status_shared")
require("red_out")

local event = require("event")
local computer = require("computer")
local term = require("term")
local serialization = require("serialization")
local unicode = require("unicode")
local component = require("extended_component")
local ui = require("uimanager")

local configFile = "statusConfig"
local stateFile = "status_state"
local invalidPingId = "status_system_invalid_ping"

local gpu = term.gpu()

local statusHandler = {
	timer = nil,
	redAlertTimer = nil,

	-- Stored in state file
	successes = {},
	warnings = {},
	problems = {},
	pingWaiters = {},

	-- Configured from config
	updateFrequency = 10,
	screenWidth = 60,
	screenHeight = 20,
	alarmRange = 120,
	alertBlinkFrequency = 1,
	defaultAvailableDelay = 300,

	lambs = {
		success = {},
		warning = {},
		problem = {},
	},
}

Phrases = {
	pingTitle = "Роботы / Микроконтроллеры",
	successesTitle = "Успехи",
	warningsTitle = "Проблемы",
	problemsTitle = "Критические проблемы",
    pingFailed = "Потеряна связь с ",
    invalidPing = "Неверный пакет пинга: ",
    alreadyStarted = "Менеджер уже запущен",
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
function statusHandler:getAlarm()
	local alarm = component.safePrimary("os_alarm")
	if alarm ~= nil and self.alarmRange ~= nil then
		alarm.setRange(self.alarmRange)
	end
	return alarm
end

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

function statusHandler:handlePing(ping)
	if ping.id == nil or ping.title == nil then
		local serialized = serialization.serialize(ping)
		self.problems[invalidPingId] = Phrases.invalidPing .. tostring(serialized)
		return
	end

	local waiter = self.pingWaiters[ping.id]
	if waiter == nil then
		self.pingWaiters[ping.id] = {}
		waiter = self.pingWaiters[ping.id]
	end

	waiter.title = ping.title
	waiter.allowableDelay = ping.allowableDelay or self.defaultAvailableDelay
	waiter.lastPing = computer.uptime()
	self.problems[ping.id] = nil

	self:saveState()
end

function statusHandler:cancelPing(id)
	self.problems[id] = nil
	self.pingWaiters[id] = nil
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
	self:updateNotifiers()
	
	if ui:isTextColorRestorable() then
		ui:restoreInitialTextColor()
	end

	ui:cursorToBottom()
end

function statusHandler:removeWaiterByTitle(title)
	for id, waiter in pairs(self.pingWaiters) do
		if waiter.title == title then
			self.pingWaiters[id] = nil
			self.problems[id] = nil
		end
	end
	self:saveState()
end

function statusHandler:updateAndShowPingWaiters()
	if next(self.pingWaiters) == nil then return end

	ui:setTextColor(Colors.title)
	ui:printHeader(Phrases.pingTitle, "=")

	local statuses = {}

	for id, waiter in pairs(self.pingWaiters) do
		local isFailed = false
		local allowableTime = waiter.lastPing + waiter.allowableDelay
		
		if computer.uptime() > allowableTime then
			local message = Phrases.pingFailed .. waiter.title
			self:handleStatus(StatusMessageType.PROBLEM, id, message)
			isFailed = true
		end

		local status = {isFailed = isFailed, title = waiter.title}
		table.insert(statuses, status)
	end

	local comparator = function(s1, s2) return unicode.lower(s1.title) < unicode.lower(s2.title) end
	table.sort(statuses, comparator)

	local width, _ = gpu.getResolution()
	local col2X = width / 2
	local _, initY = term.getCursor()
	for index, status in pairs(statuses) do
		local color = status.isFailed and Colors.pingFailed or Colors.pingSuccess
		ui:setTextColor(color)
		local x = (index - 1) % 2 * col2X + 1
		local y = (index - 1) / 2 + initY 
		gpu.set(x, y, status.title)
	end

	term.setCursor(1, math.ceil(#statuses / 2) + initY)
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

function statusHandler:updateNotifiers()
	local haveSuccesses = next(self.successes) ~= nil
	local haveWarnings = next(self.warnings) ~= nil
	local haveProblems = next(self.problems) ~= nil

	component.modem.broadcast(notifiersPort, haveSuccesses, haveWarnings, haveProblems)
	
	RedOut.setStatusForAll(haveSuccesses, self.lambs.success)
	RedOut.setStatusForAll(haveWarnings, self.lambs.warning)

	-- Handle problems
	local alarm = self:getAlarm()
	if alarm ~= nil then
		local alarmFunc = haveProblems and alarm.activate or alarm.deactivate
		alarmFunc()
	end

	if haveProblems then
		RedOut.setStatusForAll(haveProblems, self.lambs.problem)
		if self.redAlertTimer == nil then
			local blinkAlert = function()
				RedOut.invertAll(self.lambs.problem)
			end
			self.redAlertTimer = event.timer(self.alertBlinkFrequency, blinkAlert, math.huge)
		end
	else
		RedOut.setStatusForAll(false, self.lambs.problem)
		if self.redAlertTimer ~= nil then
			event.cancel(self.redAlertTimer)
			self.redAlertTimer = nil
		end
	end
end

function statusHandler:handleModemEvent(...)
	local _,_,_,_,_,type,data = table.unpack { ... }

    if type == StatusMessageType.PING then
    	local payload = serialization.unserialize(data)
        self:handlePing(payload)
    elseif type == StatusMessageType.CANCEL_PING then
        self:cancelPing(data)
    elseif type == StatusMessageType.CANCEL then
        self:cancelStatus(data)
    elseif type == StatusMessageType.SUCCESS or type == StatusMessageType.WARNING or type == StatusMessageType.PROBLEM then
    	data = string.gsub(data, "\n", " ")
    	local payload = serialization.unserialize(data)
        self:handleStatus(type, payload.id, payload.message)
    end
end

function statusHandler:loadConfig()
	local config = utils:loadFrom(configFile)

	self.updateFrequency = config.updateFrequency
	self.screenWidth = config.screenWidth
	self.screenHeight = config.screenHeight
	self.alarmRange = config.alarmRange
	self.alertBlinkFrequency = config.alertBlinkFrequency
	self.defaultAvailableDelay = config.defaultAvailableDelay or self.defaultAvailableDelay

	self.lambs.success = RedOut:fromRawArray(config.successLambs)
	self.lambs.warning = RedOut:fromRawArray(config.warningLambs)
	self.lambs.problem = RedOut:fromRawArray(config.problemLambs)
end

-- This wrapper should be used for cancel listening
local function handleModemEvent(...)
	statusHandler:handleModemEvent(...)
end

-- Public methods

function statusHandler:start()
	if self.timer ~= nil then
		utils:showError(Phrases.alreadyStarted)
		return
	end

	self:loadConfig()

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

	if self.redAlertTimer ~= nil then
		event.cancel(self.redAlertTimer)
		self.redAlertTimer = nil
	end
	RedOut.setStatusForAll(false, self.lambs.success)
	RedOut.setStatusForAll(false, self.lambs.warning)
	RedOut.setStatusForAll(false, self.lambs.problem)

	local alarm = self:getAlarm()
	if alarm ~= nil then alarm.deactivate() end

	ui:restoreScreenSize()
end

return statusHandler