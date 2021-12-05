require("utils")

computer = require("computer")
term = require("term")
event = require("event")
component = require ("extended_component")

configFile = "config"
logFile = "itemsLog"

itemsLogger = {
	startDate = nil,
	startCounts = {},
	currentCounts = {},
	timer = nil,

	frequency = 60,
	db = nil,
	dbSize = 0,
	controller = nil
}

layout = {
	cols = {1, 25, 35, 45, 53},
	increasingColor = 0x009900,
	decreasingColor = 0x990000,
	stableColor = 0x999999
}

function itemsLogger:init()
	local config = utils:loadFrom(configFile)
	
	self.db = component:shortProxy(config.database)
	self.dbSize = config.databaseSize
	self.controller = component:shortProxy(config.controller)
	self.frequency = config.frequency
end

function itemsLogger:updateCounts(updateStartCounts)
	for index = 1, self.dbSize, 1 do
		local dbStack = self.db.get(index)
		if dbStack == nil then 
			goto continue 
		end

		local count = self:getCountForDbStack(dbStack)
		local label = dbStack.label
		self.currentCounts[label] = count
		
		if updateStartCounts then
			self.startCounts[label] = count
		end

		::continue::
	end
end

function itemsLogger:getCountForDbStack(dbStack)
	local filter = {label = dbStack.label, name = dbStack.name}
	local meStacks = self.controller.getItemsInNetwork(filter)
	local count = 0
	for meIndex = 1, #meStacks, 1 do
		count = count + meStacks[meIndex].size
	end

	return count
end

function itemsLogger:showReport()
	gpu = term.gpu()
	term.clear()
	local initColor = gpu.getForeground()

	local duration = computer.uptime() - self.startTime
	local hours = math.floor(duration / 3600)
	local minutes = math.floor((duration - hours * 3600) / 60)
	local seconds = math.floor((duration - hours * 3600 - minutes * 60))
	print ("Loggin still active: " .. tostring(hours) .. ":" .. tostring(minutes) .. ":" .. tostring(seconds))

	local row = 2
	for index = 1, self.dbSize, 1 do
		local dbStack = self.db.get(index)
		if dbStack == nil then 
			goto continue 
		end

		self:addReportRow(dbStack.label, duration, row)
		row = row + 1
		::continue::
	end

	term.setCursor(1, row)
	gpu.setForeground(initColor)
end

function itemsLogger:addReportRow(label, duration, row)
	local diff = self.currentCounts[label] - self.startCounts[label]
	local perSec = diff / duration
	if perSec > 0 then
		gpu.setForeground(layout.increasingColor)
	elseif perSec == 0 then
		gpu.setForeground(layout.stableColor)
	else
		gpu.setForeground(layout.decreasingColor)
	end

	gpu.set(layout.cols[1], row, label)
	gpu.set(layout.cols[2], row, string.format("%.2f", perSec * 3600))
	gpu.set(layout.cols[3], row, string.format("%.2f", perSec * 60))
	gpu.set(layout.cols[4], row, string.format("%.2f", perSec))
end

function itemsLogger:start(verbose)
	self.startTime = computer.uptime()
	self.startCounts = {}

	itemsLogger:updateCounts(true)
	if verbose then 
		itemsLogger:showReport()
	end

	updateLog = function() 
		itemsLogger:updateCounts(false) 
		if verbose then 
			itemsLogger:showReport()
		end
	end

	self.timer = event.timer(self.frequency, updateLog, math.huge)
	print("Started logging")
end

function itemsLogger:stop()
	event.cancel(self.timer)
	self.timer = nil
	print("Stopped logging")
end

itemsLogger:init()
return itemsLogger