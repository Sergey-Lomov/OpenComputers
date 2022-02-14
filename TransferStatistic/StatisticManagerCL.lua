require 'utils'
require 'extended_table'

local term = require 'term'
local event = require 'event'
local unicode = require 'unicode'
local keyboard = require 'keyboard'
local ui = require 'uimanager'
local core = require 'statistic_manager'
local localizer = require 'local_client'

local gpu = term.gpu()
local configFile = "config"

local Modes = {
	VALUABLE = 1,
	CAROUSEL = 2,
	LAST = 2
}

local Phrases = {
	onboardTime = "Общее время в системе:",
	sessionTime = "Текущая сессия статистики:",
	itemsTitle = "Производство",
	nameColTitle = "Название",
	totalColTitle = "Всего",
	perMinColTitle = "В мин.",
	perHourColTitle = "В час",
	noData = "Нет данных",
	moreItems = "...",
	loadingStub = "Переводится..."
}

local Colors = {
	title = 0xFFFFFF,
	defaultInfo = 0xAAAAAA
}

local presenter = {
	providers = {},
	currentProvider = nil,
	crouselStepTime = nil,
	crouselPauseTime = nil,
	mode = Modes.VALUABLE,

	config = nil
}

function presenter:updateProviderView(providerView, provider)
	local hasNew = false
	for title, item in pairs(provider.items) do
		local itemView = table.filteredByKeyValue(providerView.items, "title", title)[1]
		
		if itemView == nil then
			itemView = {
				title = title,
				priority = self.config.priorities[title] or 0,
			}
			table.insert(providerView.items, itemView)
			hasNew = true
		end

		itemView.total = item.total
		itemView.perMin = core:production(provider, title) * 60
		itemView.perHour = core:production(provider, title) * 3600
	end

	if hasNew then
		local comparator = function(i1, i2) 
			if i1.priority ~= i2.priority then
				return i1.priority > i2.priority
			else
				return unicode.lower(i1.title) < unicode.lower(i2.title) 
			end
		end
		table.sort(providerView.items, comparator)
	end
end

function presenter:reloadData()
	if core.providers == nil then
		utils:showError(Phrases.noData)
		return false
	end

	for id, provider in pairs(core.providers) do
		local providerView = table.filteredByKeyValue(self.providers, "id", id)[1]

		if providerView == nil then
			providerView = {
				id = id,
				title = provider.title,
				registrationTime = provider.registrationTime,
				sessionDuration = provider.sessionDuration,
				items = {},
			}
			table.insert(self.providers, providerView)
		end
		self:updateProviderView(providerView, provider)
	end

	return true
end

function presenter:showProvider(index, showIndex)
	term.clear()

	local provider = self.providers[index]
	local title = provider.title
	if showIndex then 
		title = title .. string.format(" %d/%d", index, #self.providers)
	end

	ui:setTextColor(Colors.title)
	ui:printHeader(title, "=")

	local col2X = self.config.col2X
	local col3X = self.config.col3X
	local col4X = self.config.col4X

	ui:setTextColor(Colors.defaultInfo)
	local totalDuration = utils:realWorldSeconds() - provider.registrationTime
	gpu.set(1, 2,  Phrases.onboardTime)
	gpu.set(col3X, 2,  ui:secondsToDHM(totalDuration))
	gpu.set(1, 3,  Phrases.sessionTime)
	gpu.set(col3X, 3,  ui:secondsToDHM(provider.sessionDuration))

	term.setCursor(1, 5)
	ui:setTextColor(Colors.title)
	ui:printHeader(Phrases.itemsTitle, "=")

	gpu.set(1, 6, Phrases.nameColTitle)
	gpu.set(col2X, 6, Phrases.perMinColTitle)
	gpu.set(col3X, 6, Phrases.perHourColTitle)
	gpu.set(col4X, 6, Phrases.totalColTitle)

	self:showItems(provider.items, 7, false)

	ui:cursorToBottom()
	ui:restoreInitialTextColor()
end

function presenter:showValuable()
	term.clear()

	ui:setTextColor(Colors.title)
	gpu.set(1, 1, Phrases.itemsTitle)
	gpu.set(self.config.col2X, 1, Phrases.perMinColTitle)
	gpu.set(self.config.col3X, 1, Phrases.perHourColTitle)
	gpu.set(self.config.col4X, 1, Phrases.totalColTitle)

	local y = 3
	for _, provider in pairs(self.providers) do
		term.setCursor(1, y)
		ui:setTextColor(Colors.title)
		ui:printHeader(provider.title, "=")

		y = self:showItems(provider.items, y + 1, true)
		y = y + 1
	end

	term.setCursor(1, y + 2)
	ui:setTextColor(Colors.title)
	print("Free memory: " .. tostring(math.modf(computer.freeMemory() / 1000)) .. " / " .. tostring(math.modf(computer.totalMemory() / 1000)))

	ui:cursorToBottom()
	ui:restoreInitialTextColor()
end

function presenter:showItems(items, y, onlyValuable)
	for _, item in pairs(items) do
		if onlyValuable and item.priority == 0 then goto continue end
		
		if y == self.config.height - 1 then
			ui:setTextColor(color or Colors.defaultInfo)
			gpu.set(1, y, Phrases.moreItems)
			return y
		end

		local color = self.config.colors[item.priority] 
		ui:setTextColor(color or Colors.defaultInfo)

		local title = localizer:localize(item.title)
		title = ui:removeControlMarks(title)
		gpu.set(1, y, title)
		gpu.set(self.config.col2X, y, ui:readableNumber(item.perMin))
		gpu.set(self.config.col3X, y, ui:readableNumber(item.perHour))
		gpu.set(self.config.col4X, y, ui:readableNumber(item.total))
		y = y + 1

		::continue::
	end

	return y
end

function presenter:nextMode()
	if self.mode == Modes.CAROUSEL then self:stopCarousel() end

	if self.mode == Modes.LAST then
		self.mode = 1
	else
		self.mode = self.mode + 1
	end

	if self.mode == Modes.CAROUSEL then self:startCarousel() end
	self:updateView()
end

function presenter:nextProvider()
	if #self.providers == 0 then
		utils:showError(Phrases.noData)
		return
	end

	self.currentProvider = (self.currentProvider or 0) + 1
	if self.currentProvider > #self.providers then
		self.currentProvider = 1
	end

	self:showProvider(self.currentProvider, true)
end

function presenter:prevProvider()
	if #self.providers == 0 then
		utils:showError(Phrases.noData)
		return
	end

	self.currentProvider = (self.currentProvider or #self.providers) - 1
	if self.currentProvider < 1 then
		self.currentProvider = #self.providers
	end

	self:showProvider(self.currentProvider, true)
end

function presenter:updateView()
	if #self.providers == 0 then
		utils:showError(Phrases.noData)
		return
	end

	if self.mode == Modes.VALUABLE then
		self:showValuable()
	elseif self.mode == Modes.CAROUSEL then
		self.currentProvider = self.currentProvider or 1
		self:showProvider(self.currentProvider, true)
	end
end

function presenter:startCarousel()
	if self.carouselStepTimer ~= nil then
		return
	end

	local duration = self.config.carouselStepDuration
	self.carouselStepTimer = event.timer(duration, function() self:nextProvider() end, math.huge)
end

function presenter:stopCarousel()
	if self.carouselStepTimer == nil then return end
	event.cancel(self.carouselStepTimer)
	self.carouselStepTimer = nil
end

function presenter:start()
	if self.config.width ~= nil and self.config.height ~= nil then
		ui:setScreenSize(self.config.width, self.config.height)
	end

	core:start()

	if self:reloadData() then
		self:updateView()
	end
end

function presenter:stop()
	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end

	core:stop()

	if self.carouselStepTimer ~= nil then
		self:stopCarousel()
	end
end

function presenter:init()
	self.config = utils:loadFrom(configFile)
	self.config.priorities = self.config.priorities or {}
	self.config.colors = self.config.colors or {}

	localizer.onUpdate = self.updateView
	localizer.loadingStub = Phrases.loadingStub

	core.onUpdate = function()
		if self:reloadData() then
			self:updateView()
		end
	end

	core.onError = function(error)
		utils:showError(error)
	end
end

presenter:init()
return presenter