require "items_config_fingerprint"

local core = require "me_manager_core"
local unicode = require "unicode"
local term = require "term"
local ui = require("uimanager")
local gpu = term.gpu()

Colors = {
	title = 0xFFFFFF,
	problem = 0xFF0000,
    default = 0xBBBBBB,
}

Modes = {
	command = 0,
	showQueue = 1
}

local Phrases = {
	craftingRequestsTitle = "Создается",
	waitingRequestsTitle = "Очередь",
	allDone = "Кол-во всех предметов в норме",
	handleItemsFormat = "%d предметов проверено"
}

local managercl = {
	queueShowing = {
		priorityPosition = 0,
		amountPosition = 0,
		priorityRightSpace = 14,
		amountRightSpace = 8
	},
	mode = Modes.showQueue
}

function managercl:selectChestItems()
	local views = core:chestItems()
	term.clear()
	for index, view in ipairs(views) do
		print(tostring(index) .. "\t" .. view.amount .. "\t" .. view.title)
	end
	print("Enter 0 to cancel item selection")
	return tonumber(term.read())
end

function managercl:setLoadingTestItem(index)
	if index == nil then 
		index = managercl:selectChestItems()
		if index == 0 then return end
	end

	local item = core:chestItem(index)
	local fingerprint = ItemsConfigFingerprint:new(item.id,item. damage, item.nbtHash, item.title)
	core:setLoadingTestItem(fingerprint)
end

function managercl:addItem(index)
	if index == nil then 
		index = managercl:selectChestItems()
		if index == 0 then return end
	end

	local item = core:chestItem(index)
	local fingerprint = ItemsConfigFingerprint:new(item.id,item. damage, item.nbtHash, item.title)
	local config = {}

	print("Enter critical level (may be empty)")
	local criticalLevel = tonumber(term.read())
	if criticalLevel ~= nil and criticalLevel >= 0 then 
		config.problem = criticalLevel
	end

	::enter_warning::
	print("Enter warning level (may be empty)")
	local warningLevel = tonumber(term.read())
	if warningLevel ~= nil and warningLevel >= 0 then 
		local normalisedCritical = criticalLevel or -1
		if warningLevel <= normalisedCritical then
			print("Warning level should be biger then critical")
			goto enter_warning
		else
			config.warning = warningLevel
		end
	end

	print("Enter DESTROY level (may be empty)")
	local destroyLevel = tonumber(term.read())
	if destroyLevel ~= nil and destroyLevel >= 0 then 
		print("Please enter \'destroy\' to aaprove destory level")
		local code = term.read():sub(1, -2)
		if code == "destroy" then
			config.destroy = destroyLevel
		end
	end

	print("Would you add autocrafting? (y/n)")
	local addAutocraft = term.read():sub(1, -2)
	if addAutocraft == "y" or addAutocraft == "Y" then
		local craft = {}
		print("Enter item autocraft limit")
		craft.limit = tonumber(term.read())
		print("Autocraft priority. 1(lower) is default")
		craft.priority = tonumber(term.read()) or 1
		print("Enter autocraft max portion (may be empty)")
		craft.portion = tonumber(term.read())

		config.craft = craft
	end

	core:setItemConfig(fingerprint, config)
end

function managercl:showRequests(title, list, fromY)
	fromY = fromY or 1
	local priorityX = self.queueShowing.priorityPosition
	local amountX = self.queueShowing.amountPosition

	ui:setTextColor(Colors.title)
	term.setCursor(1, fromY)
	ui:printHeader(title, "=")

	for index, request in ipairs(list) do
		local color = request.isProblem and Colors.problem or Colors.default
		ui:setTextColor(color)

		local currentY = fromY + index
		gpu.set(1, currentY, request.filter.label) 
		gpu.set(priorityX, currentY, tostring(request.priority))
		gpu.set(amountX, currentY, tostring(request.amount))
	end

	return fromY + #list + 1
end

function managercl:showAllDone()
	local width, height = gpu.getResolution()
	
	ui:setTextColor(Colors.title)
	local y = height / 2 - 1
	local x = (width - unicode.len(Phrases.allDone)) / 2
	gpu.set(x, y, Phrases.allDone) 

	ui:setTextColor(Colors.default)
	local report = string.format(Phrases.handleItemsFormat, #core.itemsConfig)
	local y = height / 2
	local x = (width - unicode.len(report)) / 2
	gpu.set(x, y, report)
end

function managercl:showQueue(crafting, waiting)
	term.clear()

	local y = 1
	
	if #crafting > 0 then
		y = self:showRequests(Phrases.craftingRequestsTitle, crafting)
	end

	if #waiting > 0 then
		y = self:showRequests(Phrases.waitingRequestsTitle, waiting, y)
	end

	if #waiting == 0 and #crafting == 0 then
		local report = string.format(Phrases.handleItemsFormat, #core.itemsConfig)
		ui:showLinesCentered({Phrases.allDone, report}, {Colors.title, Colors.default})
	end

	if ui:isTextColorRestorable() then
		ui:restoreInitialTextColor()
	end

	ui:cursorToBottom()
end

function managercl:toCommand()
	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end

	term.clear()

	self.mode = Modes.command
end

function managercl:toQueueShow(width, height)
	if width ~= nil and height ~= nil then
		ui:setScreenSize(width, height)
	end

	local width, _  = gpu.getResolution()
	self.queueShowing.priorityPosition = width - self.queueShowing.priorityRightSpace
	self.queueShowing.amountPosition = width - self.queueShowing.amountRightSpace

	self.mode = Modes.showQueue
end

function managercl:start(width, height)
	core.queue.onQueueUpdate = function (crafting, waiting)
		if self.mode == Modes.showQueue then
			if core.problem ~= nil then
				term.clear()
				ui:showLinesCentered({core.problem}, {Colors.problem})
			else
				self:showQueue(crafting, waiting)
			end		
		end
	end

	self:toQueueShow(width, height)
	core:start()
end

function managercl:stop()
	core:stop()

	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end
end

return managercl