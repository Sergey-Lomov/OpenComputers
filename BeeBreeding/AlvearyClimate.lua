require("red_out")
require("range")
utils = require ("utils")

TempLevel = {
	["icy"] = Range:new(-20, 6),
	["cold"] = Range:new(7, 34),
	["normal"] = Range:new(35, 84),
	["warm"] = Range:new(85, 99),
	["hot"] = Range:new(100, 199),
	["hellish"] = Range:new(200)
}
	
HumidLevel = {
	["arid"] = Range:new(0, 29),
	["normal"] = Range:new(30, 84),
	["damp"] = Range:new(85, 100)
}


configFile = "climate_config"

climateController = {
	heaterEffect = {temp = 19, humid = 0},
	fanEffect = {temp = -19, humid = 0},
	lavaEffect = {temp = 9, humid = -19},
	aquaEffect = {temp = -9, humid = 19},

	heaters = {}, --Red outs for controll heaters
	fans = {}, --Red outs for controll fans
	lavas = {}, --Red outs for controll hydrators lava filling
	aquas = {}, --Red outs for controll hydrators aqua filling
	drenage = {}, -- Red out for removing liquids from hedrators after breeding finish
	
	default = {temp = 0, humid = 0},
	current = {temp = 0, humid = 0}
}

function climateController:apply(tempCode, humidCode)
	local aquaCounter = 0
	local lavaCounter = 0
	local fanCounter = 0
	local heaterCounter = 0

	local temp = self.current.temp
	local humid = self.current.humid

	local requiredTempLevel = TempLevel[tempCode]
	local requiredHumidLevel = HumidLevel[humidCode]

	while not requiredHumidLevel:contains(humid) do
		if humid > requiredHumidLevel.max then
			lavaCounter = lavaCounter + 1
			temp = temp + self.lavaEffect.temp
			humid = humid + self.lavaEffect.humid
		else
			aquaCounter = aquaCounter + 1
			temp = temp + self.aquaEffect.temp
			humid = humid + self.aquaEffect.humid
		end
	end

	while not requiredTempLevel:contains(temp) do
		if temp < requiredTempLevel.min then
			if (temp + self.heaterEffect.temp) <= requiredTempLevel.max then
				heaterCounter = heaterCounter + 1
				temp = temp + self.heaterEffect.temp
				humid = humid + self.heaterEffect.humid
			else
				lavaCounter = lavaCounter + 1
				temp = temp + self.lavaEffect.temp
				humid = humid + self.lavaEffect.humid
			end
		else
			if (temp + self.heaterEffect.temp) >= requiredTempLevel.min then
				fanCounter = fanCounter + 1
				temp = temp + self.fanEffect.temp
				humid = humid + self.fanEffect.humid
			else
				aquaCounter = aquaCounter + 1
				temp = temp + self.aquaEffect.temp
				humid = humid + self.aquaEffect.humid
			end
		end
	end

	print("Used heters: " .. heaterCounter)
	print("Used fans: " .. fanCounter)
	print("Used lavas: " .. lavaCounter)
	print("Used aquas: " .. aquaCounter)

	if aquaCounter > #self.aquas then
		return {result = "error", description = "Not enought water hydrators"}
	elseif lavaCounter > #self.lavas then
		return {result = "error", description = "Not enought lava hydrators"}
	elseif fanCounter > #self.fans then
		return {result = "error", description = "Not enought fans"}
	elseif heaterCounter > #self.heaters then
		return {result = "error", description = "Not enought heaters"}
	end

	self:setModificators(heaterCounter, self.heaters)
	self:setModificators(fanCounter, self.fans)
	self:setModificators(aquaCounter, self.aquas)
	self:setModificators(lavaCounter, self.lavas)

	self.current.temp = temp
	self.current.humid = humid

	return {result = "success"}
end

function climateController:setModificators(count, redOuts)
	for index, redOut in pairs(redOuts) do
		if index <= count then
			redOut:enable()
		else
			redOut:disable()
		end
	end
end

function climateController:stop()
	self:setModificators(0, self.heaters)
	self:setModificators(0, self.fans)
	self:setModificators(0, self.aquas)
	self:setModificators(0, self.lavas)

	self.current.temp = self.default.temp
	self.current.humid = self.default.humid
end

function climateController:startDrenage()
	self.drenage:enable()
end

function climateController:stopDrenage()
	self.drenage:disable()
end

function climateController:init()
	local config = utils:loadFrom(configFile)

	self.fans = RedOut:fromRawArray(config.fans)
	self.heaters = RedOut:fromRawArray(config.heaters)
	self.lavas = RedOut:fromRawArray(config.lavas)
	self.aquas = RedOut:fromRawArray(config.aquas)
	self.drenage = RedOut:fromRaw(config.drenage)

	self.default.temp = config.temp
	self.default.humid = config.humid
	self.current.temp = config.temp
	self.current.humid = config.humid
end

climateController:init()

return climateController