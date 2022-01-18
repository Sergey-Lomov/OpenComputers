utils = require ("utils")
utils = require ("income_interface")

climateController = require ("climate")
component = require ("extended_component")
transposer = require ("bees_transposer")
analyzer = require ("bees_analyzer")
dbExtender = require ("bees_database")

configFile = "config"
identsFile = "idents"

timing = {
	weddingDuration = 5,
	alvearyCheck = 1
}

alvearyController = {}

function alvearyController:init()
	local config = utils:loadFrom(configFile)

	self.targetPrincessDB = component.shortProxy(config.targetPrincessDB)
	self.droneDB = component.shortProxy(config.droneDB)
	self.naturalDB = component.shortProxy(config.naturalDB)
	self.unnaturalDB = component.shortProxy(config.unnaturalDB)
	self.alveary = component.items
	self.interface = component.me_interface

	self.identsClimates = utils:loadFrom(identsFile)

	dbExtender.extendBeeDatabase(self.droneDB)
	extendIncomeInterface(self.interface)
end


function alvearyController:prepareSourceDrone()
	local droneIndex = self.droneDB.indexForName(type)
	if droneIndex == nil then
		utils:showError("Failed to found drone of type")
		return 
	end

	local emptyIndex = transposer.incomeEmptyIndex()
	if emptyIndex == nil then
		utils:showError("No empty slot for export in income buffer")
		return nil
	end

	self.droneBus.setExportConfiguration(self.droneBusSide, self.droneDB.address, droneIndex)
	self.droneBus.exportIntoSlot(self.droneBusSide, emptyIndex) 
	return emptyIndex
end

function alvearyController:handleNewIdent(princessIndex, ident)
	local climate = nil

	transposer.toAnalyzerFromIncome(princessIndex)
	while true do
		os.sleep(1)
		local species = analyzer.analyzedSpecies()
		
		if species ~= nil then
			climate = {humidity = species.humidity, temperature = species.temperature}
			break 
		end

		if not analyzer.isWorking() then
			utils:showError("Analyzer is at ubnormal state")
			return
		end
	end

	self.idents[ident] = climate
	utils:saveTo(identsFile, self.idents)
	return climate
end

function alvearyController:createPrincess(type)
	
	self:prepareBreeding()
	os.sleep(timing.weddingDuration)
	if not self.alveary.canBreed() then
		local climate = self.idents[type]
		if climate == nil then 
			utils:showError("Can't get climate for type: " .. type)
			return
		end
		climateController.apply(climate.temperature, climate.humidity)
	end
	
	-- Wating untill breeding will be finished
	while self.alveary.getQueen() ~= nil do
		os.sleep(timing.alvearyCheck)
	end

	self:handleChilds(type)
end

function alvearyController:handleChilds(type)
	local princess = transposer.getAlvearyPrincess()
	if princess == nil then --Princess was die and get no new princesses
		utils:showInfo("Princess die. Retries with new princess.")
	end
end

function alvearyController:prepareBreeding(type)
	-- Get princess and info about climat requirements
	if not self.interface.setupPrincess() then
		utils:showError("Failed to prepare source princess")
		return 
	end

	local princessStack = transposer.getIncomeStack(self.interface.princessIndex)
	local ident = princessStack.individual.ident

	local speciesClimate = self.idents[ident]
	if speciesClimate == nil then
		speciesClimate = self:handleNewIdent(princessIndex, ident)
		if speciesClimate == nil then
			utils:showError("Failed to determine required climate")
		end
		transposer.toAlvearyFromAnalyzer()
	else
		transposer.toAlvearyFromIncome(princessIndex)
	end

	-- Get drone
	local droneIndex = self:prepareSourceDrone()
	if princessIndex == nil then
		utils:showError("Failed to prepare source drone")
		return 
	end
	transposer.toAlvearyFromIncome(droneIndex)
end

alvearyController:init()