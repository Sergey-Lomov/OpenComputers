require("utils")

sides = require("sides")
robot = require("robot")
component = require("component")
icExtender = require("ic_extender")

ic = component.inventory_controller
icExtender:extend(ic)
rs = component.redstone

configFile = "config"
waitingStep = 2


mason = {
	config = {},
	iteration = 1
}

function mason:init()
	self.config = utils:loadFrom(configFile)
end

function mason:useSand(name)
	self:prepareAndSelect("minecraft:sand", true)
	ic.equip()
	robot.use()
end

function mason:placeSprayer(name)
	self:prepareAndSelect("IC2:itemFoamSprayer", false)
	robot.place() -- Yep, we have possibility to place sprayer without equip
end

function mason:placeScaffold(name)
	self:prepareAndSelect("IC2:blockIronScaffold", true)
	robot.place()
end

function mason:swingDrill(name)
	self:prepareAndSelect("GraviSuite:advDDrill", false)
	ic.equip()
	robot.swing()
end

function mason:prepareAndSelect(name, tryToSuck)
	local reported = false
	local slot = ic:firstInternalSlotWhere("name", name)
	while slot == nil do
		if tryToSuck then
			if not reported then
				print("Try to suck: " .. name)
				reported = true
			end

			local sourceSlot = ic:firstSlotWhere(self.config.inSide, "name", name)
			if sourceSlot ~= nil then
				slot = ic:firstInternalEmptySlot()
				robot.select(slot)
				ic.suckFromSlot(self.config.inSide, sourceSlot)
			end
		else
			slot = ic:firstInternalSlotWhere("name", name)
		end
	end

	robot.select(slot)
end

function mason:pushOutDrop()
	local slot = ic:firstInternalSlotWhere("name", "IC2:blockAlloy")
	while slot ~= nil do
		local targetSlot = ic:firstEmptySlot(self.config.outSide)
		robot.select(slot)
		ic.dropIntoSlot(self.config.outSide, targetSlot)
		slot = ic:firstInternalSlotWhere("name", "IC2:blockAlloy")
	end
end

function mason:pushOutTools()
	local emptySlot = ic:firstInternalEmptySlot()
	robot.select(emptySlot)
	ic.equip()

	rs.setOutput(self.config.toolsSignalSide, 15)
	os.sleep(self.config.toolsOutDelay)
	rs.setOutput(self.config.toolsSignalSide, 0)

	self.iteration = 1
end

function mason:start()
	while true do
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