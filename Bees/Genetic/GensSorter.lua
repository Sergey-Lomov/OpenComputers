require 'extended_component'
require 'extended_table'

local utils = require("utils")
local status = require("status_client")
local ui = require("uimanager")
local term = require("term")
local component = require("component")

local nbtHashesFile = "hashes"
local stateFile = "state"
local configFile = "config"
local successStatusId = "gen_sorter_success"
local sequenceId = "Genetics:sequence"

local Phrases = {
	missedChest = "Входящий сундук не обнаружен",
	totalTransfered = "Всего генов обработано: ",
	originalTransfered = "Оригинальных генов: ",
	noNewGensFound = "Новых генов не обнаружено",
	newGensFound = "Новые гены: "
}

local Colors = {
	info = 0xFFFFFF,
	noNew = 0xBBBBBB,
    new = 0x00AA00,
}

local sorter = {
	handledHashes = {},
	state = {original = 0, total = 0},
	newGensCount = 0,
	frequency = 10,
	inChest = nil,
	analyzingSide = "UP",
	recyclingSide = "UP",
	timer = nil
}

function sorter:transferItems()
	if self.chest == nil then return end

	for i = 1, self.chest.getInventorySize(), 1 do
		local stack = self.chest.getStackInSlot(i)
		if stack == nil then goto continue end
		if stack.id ~= sequenceId then goto continue end

		local pushed = false
		if table.containsValue(self.handledHashes, stack.nbt_hash) then
			pushed = self.chest.pushItem(self.recyclingSide, i) > 0
		else
			pushed = self.chest.pushItem(self.analyzingSide, i) > 0 
			if pushed then
				self.newGensCount = self.newGensCount + 1
				self.state.original = self.state.original + 1
				
				table.insert(self.handledHashes, stack.nbt_hash)
				utils:saveTo(nbtHashesFile, self.handledHashes)

				pushed = true
			end
		end

		if pushed then
			self.state.total = self.state.total + 1
			utils:saveTo(stateFile, self.state)
		end

		::continue::
	end
end

function sorter:updateUI()
	term.clear()
	local totalString = Phrases.totalTransfered .. tostring(self.state.total)
	local originalString = Phrases.originalTransfered .. tostring(self.state.original)
	local lines = {totalString, originalString}
	local colors = {Colors.info, Colors.info}
	
	if self.newGensCount > 0 then
		local newString = Phrases.newGensFound .. tostring(self.newGensCount)
		table.insert(lines, newString)
		table.insert(colors, Colors.new)
	else
		table.insert(lines, Phrases.noNewGensFound)
		table.insert(colors, Colors.noNew)
	end

	ui:showLinesCentered(lines, colors)
end

function sorter:updateStatus()
	if self.newGensCount > 0 then
		local message = Phrases.newGensFound .. tostring(self.newGensCount)
		status:sendSuccess(successStatusId, message)
	else
		status:cancelStatus(successStatusId)
	end
end

function sorter:reviewed()
	self.newGensCount = 0
end

function sorter:init()
	local config = utils:loadFrom(configFile)
	self.handledHashes = utils:loadFrom(nbtHashesFile)
	
	self.state = utils:loadFrom(stateFile)
	self.state.original = self.state.original or 0
	self.state.total = self.state.total or 0

	self.frequency = config.frequency
	self.recyclingSide = config.recyclingSide
	self.analyzingSide = config.analyzingSide

	self.chest = component.shortProxy(config.inChestId)
	if self.chest == nil then
		utils:showError(Phrases.missedChest)
	end

	status.statusStrength = config.statusStrength
end

function sorter:routine()
	self:transferItems()
	self:updateUI()
	self:updateStatus()
end

function sorter:start(width, height)
	self.timer = event.timer(self.frequency, function() self:routine() end, math.huge)
	if width ~= nil and height ~= nil then
		ui:setScreenSize(width, height)
	end
end

function sorter:stop()
	if self.timer ~= nil then
		event.cancel(self.timer)
		self.timer = nil
	end

	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end
end

sorter:init()

return sorter