require 'utils'
require 'extended_table'

local component = require 'component'
local event = require 'event'
local uuid = require 'uuid'
local status = require 'status_client'

local modem = component.modem
local localizationPort = 2654
local dictPort = 2653
local configFile = "config"
local noLocalizationId = "no_local_"

local Phrases = {
	invalidRequest = "Неверный запрос: ",
	invalidTaskId = "Получен ответ с незарегестрированым id задачи: ",
	missedLocalization = "Нет перевода для: ",
}

local TaskStates = {
	sourceToRu = 1,
	sourceToCode = 2,
	codeToRu = 3,
}

local service = {
	codeToRuAddress = nil,
	enToCodeAddress = nil,
	tasks = {}
}

function service:finishTask(task)
	for _, key in ipairs(task.keys) do
		if task.localized[key] == nil then
			local id = noLocalizationId .. key
			local message = Phrases.missedLocalization .. key
			status:sendWarning(id, message)
			task.localized[key] = key
		end
	end

	local serialized = serialization.serialize(task.localized)
	modem.send(task.requester, localizationPort, serialized)
	table[task.id] = nil
end

function service:handleFirstResponseFromRu(task, dict)
	task.localized = dict

	local missedKeys = {}
	for _, key in ipairs(task.keys) do
		if dict[key] == nil then
			table.insert(missedKeys, key)
		end
	end

	if #missedKeys == 0 then
		self:finishTask(task)
		return
	end

	task.state = TaskStates.sourceToCode
	local serialized = serialization.serialize(missedKeys)
	modem.send(self.enToCodeAddress, dictPort, task.id, serialized)
end

function service:handleSecondResponseFromRu(task, dict)
	for key, code in pairs(task.keysCodes) do
		task.localized[key] = dict[code]
	end 
	self:finishTask(task)
end

function service:handleResponseFromEn(task, dict)
	task.keysCodes = dict
	task.state = TaskStates.codeToRu

	local codes = {}
	for _, code in pairs(dict) do
		table.insert(codes, code)
	end

	local serialized = serialization.serialize(codes)
	modem.send(self.codeToRuAddress, dictPort, task.id, serialized)
end

function service:handleTranslationRequest(data, requester)
	local keys = serialization.unserialize(data)
	if keys == nil then 
		utils:showError(Phrases.invalidRequest .. data)
		return 
	end

	local taskId = uuid.next()
	local task = {
		id = taskId,
		state = TaskStates.sourceToRu,
		keys = keys,
		requester = requester,
	}
	self.tasks[taskId] = task

	modem.send(self.codeToRuAddress, dictPort, taskId, data)
end

local function handleModemEvent(...)
	service:handleModemEvent(...)
end

function service:handleModemEvent(...)
	local _, _, requester, port, _, data1, data2 = table.unpack { ... }
	
	if port == localizationPort then
		self:handleTranslationRequest(data1, requester)
		return
	end
		
	local task = self.tasks[data1]
	local dict = serialization.unserialize(data2)

	if task == nil then
		utils:showError(Phrases.invalidTaskId .. data1)
		return
	end

	if task.state == TaskStates.sourceToRu then
		self:handleFirstResponseFromRu(task, dict)
	elseif task.state == TaskStates.sourceToCode then
		self:handleResponseFromEn(task, dict)
	elseif task.state == TaskStates.codeToRu then
		self:handleSecondResponseFromRu(task, dict)
	end
end

function service:start()
	modem.open(dictPort)
	modem.open(localizationPort)
	event.listen("modem_message", handleModemEvent)
end

function service:stop()
	modem.close(dictPort)
	modem.close(localizationPort)
	event.ignore("modem_message", handleModemEvent)
end

function service:init()
	local config = utils:loadFrom(configFile)
	self.codeToRuAddress = config.codeToRuAddress
	self.enToCodeAddress = config.enToCodeAddress
end

service:init()

return service