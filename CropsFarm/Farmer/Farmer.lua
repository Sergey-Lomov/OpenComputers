local nav = require("navigator")
local utils = require("utils")
local computer = require("computer")
local icExtender = require("inventory_extender")
local status = require("status_client")

local configFile = "farmerConfig"

local farmer = {
	config = {},
	inventory = component.inventory_controller
}

function farmer:init()
	self.config = utils:loadFrom(configFile)
	icExtender:extend(self.inventory)
end

function farmer:start()
	status.pingId = self.inventory.address
	status.pingTitle = self.config.pingTitle
	status.pingAllowableDelay = self.config.pingAllowableDelay
	status.statusStrength = self.config.statusStrength
	status:sendPing(true)

	while true do
		self:runSession()
		self:recharge()		
	end
end

function farmer:recharge()
	 -- Time to time it is impossibly to charge robot to full energy
	nav:runRoute(self.config.toRechargeRoute)
	local energyFull = false
	while not energyFull do
		energyFull = computer.energy() >= computer.maxEnergy() * 0.95
		os.sleep(1)
	end

	nav:runRoute(self.config.fromRechargeRoute)
	status:sendPing()
end

function farmer:runSession()
	local needRecharge = false
	local energyLimit = computer.maxEnergy() * self.config.rechargeRate
	while not needRecharge do

		self:runRound()
		
		needRecharge = computer.energy() < energyLimit
		print("Energy: " .. tostring(computer.energy()) .. " limit: " .. energyLimit)
	end
end

function farmer:runRound()
	-- Harvest
	local target = self.config.fieldCorner2
	local source = self.config.fieldCorner1

	local navRoutine = function()
		robot.useDown()
	end
	nav:snakeFill(source, target, navRoutine)
	
	-- Push out drop
	nav:goTo(self.config.unloadPosition)
	local orientation = Orientation:fromCode(self.config.unloadFace)
	nav:faceTo(orientation)
	self.inventory:unload(self.config.unloadSide)
	status:sendPing()
end

farmer:init()
return farmer