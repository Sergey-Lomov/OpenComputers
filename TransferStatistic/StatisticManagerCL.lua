require 'utils'

local term = require 'term'
local event = require 'event'
local ui = require 'uimanager'
local core = require 'statistic_manager'

local gpu = term.gpu()
local perHourX = 25
local totalX = 32
local carouselStepDuration = 30

local Phrases = {
	totalWorkTime = "Общее время работы:",
	stableWorkTime = "Стабильный сбор данных: %d %s",
	itemsTitle = "Производство",
	nameColTitle = "Название",
	totalColTitle = "Всего",
	perHourColTitle = "В час",
	noData = "Нет данных"
}

local Colors = {
	title = 0xFFFFFF,
	info = 0xDDDDDD
}

local presenter = {
	providers = {},
	currentProvider = nil,
	crouselStepTime = nil,
	crouselPauseTime = nil
}

function presenter:reloadData()
	self.providers = {}
	for id, provider in pairs(core.providers) do
		local provider = {id = id, data = provider}
		table.insert(self.providers, provider)
	end
end

function presenter:showProvider(index, showIndex)
	local provider = self.providers[index]
	local title = provider.title
	if showIndex then 
		title = titel .. string.format(" %d/%d", index, #self.providers)
	end

	ui:setTextColor(Colors.title)
	ui:printHeader(title, "=")

	ui:setTextColor(Colors.info)
	local total = uitls:realWorldSeconds() - provider.data.registrationTime
	local totalString = Phrases.totalWorkTime .. ui:secondsToDHM(totalWork)
	local stableString = Phrases.stableWorkTime .. ui:secondsToDHM(provider.data.stableDuration)
	print(totalString)
	print(stableString)

	ui:setTextColor(Colors.title)
	ui:printHeader(Phrases.itemsTitle, "=")

	gpu.set(0, 5, Phrases.nameColTitle)
	gpu.set(totalX, y, Phrases.totalColTitle)
	gpu.set(perHourX, y, Phrases.perHourColTitle)

	local y = 6
	for label, stats in pairs(provider.data.items) do
		local totalString = ui:readableNumber(stats.total)
		local perHourString = ui:readableNumber(stats.stableTotal / provider.data.stableDuration)

		gpu.set(0, y, label)
		gpu.set(totalX, y, totalString)
		gpu.set(perHourX, y, perHourString)
		y = y + 1
	end 
end

function presenter:showNext()
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

function presenter:showPrev()
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

function presenter:startCarousel()
	if self.carouselStepTimer ~= nil then
		return
	end

	self:showNext()
	self.carouselStepTimer = event.timer(carouselStepDuration, function() self:showNext() end, math.huge)
end

function presenter:stopCarousel()
	if self.carouselStepTimer == nil then return end
	event.cancel(self.carouselStepTimer)
end

local function handleKey(...)
	local _,_,_, code = table.unpack { ... }

	if code == 205 then
		presenter:stopCarousel()
		presenter:showNext()
	elseif code == 203 then
		presenter:stopCarousel()
		presenter:showPrev()
	elseif code == 57 then
		if presenter.carouselStepTimer == nil then 
			presenter:startCarousel()
		else
			presenter:stopCarousel()
		end
	end
end

function presenter:start(width, height)
	if width ~= nil and height ~= nil then
		ui:setScreenSize(width, height)
	end

	core:start()

	event.listen("key_up", handleKey)
	self:startCarousel()
end

function presenter:stop()
	if ui:isScreenSizeRestorable() then
		ui:restoreScreenSize()
	end

	core:stop()

	event.ignore("key_up", handleKey)
	self:stopCarousel()
end

function presenter:init()
	core.onUpdate = function()
		self:reloadData()
		self:showProvider(self.currentProvider, true)
	end

	self:reloadData()
end

presenter:init()
return presenter