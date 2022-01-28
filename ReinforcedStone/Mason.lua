require("utils")

local sides = require("sides")
local robot = require("robot")
local component = require("component")
local icExtender = require("ic_extender")
local status = require("status_client")

local inventory = component.inventory_controller
icExtender:extend(inventory)

local rs = component.redstone

local configFile = "config"
local waitingStep = 2

local Id = {
	sand = "minecraft:sand",
	sprayer = "IC2:itemFoamSprayer",
	scaffold = "IC2:blockIronScaffold",
	drill = "GraviSuite:advDDrill",
	stone = "IC2:blockAlloy",
}

local mason = {
	config = {},
	iteration = 1
}

function mason:init()
	self.config = utils:loadFrom(configFile)

	status.pingId = inventory.address
	status.pingTitle = self.config.pingTitle
	status.pingAllowableDelay = self.config.pingAllowableDelay
	status.statusStrength = self.config.statusStrength
end

function mason:useSand(name)
	self:prepareAndSelect(Id.sand, true)
	inventory.equip()
	robot.use()
end

function mason:placeSprayer(name)
	self:prepareAndSelect(Id.sprayer, false)
	robot.place() -- Yep, we have possibility to place sprayer without equip
end

function mason:placeScaffold(name)
	self:prepareAndSelect(Id.scaffold, true)
	robot.place()
end

function mason:swingDrill(name)
	self:prepareAndSelect(Id.drill, false)
	inventory.equip()
	robot.swing()
end

function mason:prepareAndSelect(name, tryToSuck)
	local reported = false
	local slot = inventory:firstInternalSlotWhere("name", name)
	while slot == nil do
		status:sendPing()

		if tryToSuck then
			if not reported then
				print("Try to suck: " .. name)
				reported = true
			end

			local sourceSlot = inventory:firstSlotWhere(self.config.inSide, "name", name)
			if sourceSlot ~= nil then
				slot = inventory:firstInternalEmptySlot()
				robot.select(slot)
				inventory.suckFromSlot(self.config.inSide, sourceSlot)
			end
		else
			slot = inventory:firstInternalSlotWhere("name", name)
		end
	end

	robot.select(slot)
end

function mason:pushOutDrop()
	local slot = inventory:firstInternalSlotWhere("name", Id.stone)
	while slot ~= nil do
		local targetSlot = inventory:firstEmptySlot(self.config.outSide)
		robot.select(slot)
		inventory.dropIntoSlot(self.config.outSide, targetSlot)
		slot = inventory:firstInternalSlotWhere("name", Id.stone)
	end
end

function mason:pushOutTools()
	local emptySlot = inventory:firstInternalEmptySlot()
	robot.select(emptySlot)
	inventory.equip()

	rs.setOutput(self.config.toolsSignalSide, 15)
	os.sleep(self.config.toolsOutDelay)
	rs.setOutput(self.config.toolsSignalSide, 0)

	self.iteration = 1
end

function mason:start()
	status:sendPing(true)

	while true do
		status:sendPing()

		self:placeScaffold()
		self:placeSprayer()
		self:useSand()
		self:swingDrill()

		self.iteration = self.iteration + 1
		if self.iteration == self.config.iterationsLimit then
			self:pushOutDrop()
			self:pushOutTools()
		end
	end
end

mason:init()
return mason