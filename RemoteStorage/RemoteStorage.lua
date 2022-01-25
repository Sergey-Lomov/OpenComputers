require 'utils'

local term = require("term")
local event = require("event")
local serialization = require("serialization")
local filesystem = require("filesystem")
local component = require("component")
local ui = require("uimanager")

local port = 2327
local dataFolder = "data"
local screenSize = {width = 30, height = 7}

local Phrases = {
	runned = "Данные доступны",
	resources = "Пакетов данных: ",
}

local Colors = {
	status = 0xFFFFFF,
	info = 0xBBBBBB,
}

if not component.isAvailable("modem") then
	utils:showError("Modem is required to data storage work")
	return
end

function handleModemEvent(...)
	local _, _, requester, _, _, id = table.unpack { ... }

	local path = dataFolder .. "/" .. id
	local data = utils:rawTextFrom(path)
	component.modem.send(requester, port, data)
end

function start()
	event.listen("modem_message", handleModemEvent)
	component.modem.open(port)
	
	ui:setScreenSize(screenSize.width, screenSize.height)

	local dataFolderPath = "home/" .. dataFolder
	if not filesystem.get("home").exists(dataFolderPath) then
		filesystem.get("home").makeDirectory(dataFolderPath)
	end

	term.clear()
	local dataCount = #filesystem.get("home").list(dataFolderPath)
	local status = Phrases.resources .. tostring(dataCount)
	ui:showLinesCentered({Phrases.runned, status}, {Colors.status, Colors.info})
end

function stop()
	event.ignore("modem_message", handleModemEvent)
	component.modem.close(port)

	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end
end