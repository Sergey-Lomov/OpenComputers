-- Wireless notifiers controller v1.0

--local component = require 'component'
--local computer = require 'computer'

local modem = component.proxy(component.list("modem")())
local signal = component.proxy(component.list("redstone")())
local geo = component.proxy(component.list("geolyzer")())

local port = 4362
local updateFrequence = 0.1
local redBlinkFrequence = 1.5
local lastRedUpdate = computer.uptime()

local markerName = "minecraft:wool"
local redMeta = 14
local yellowMeta = 4
local greenMeta = 13

local redBlinkEnabled = false
local redSide = nil
local yellowSide = nil
local greenSide = nil

function searchSides()
	for side = 0, 5, 1 do
		local sideData = geo.analyze(side)
		if sideData.name ~= markerName then goto continue end
		
		if sideData.metadata == redMeta then 
			redSide = side
		elseif sideData.metadata == yellowMeta then 
			yellowSide = side
		elseif sideData.metadata == greenMeta then 
			greenSide = side
		end
		
		::continue::
	end
end 

function setup()
	searchSides()

	modem.open(port)

	if redSide == nil or greenSide == nil or yellowSide == nil then
		computer.beep(300, 0.5)
	else 
		computer.beep(900, 0.5)
	end
end

function setOut(side, power)
	if side == nil then return end

	if signal.getOutput(side) ~= power then
		signal.setOutput(side, power)
	end
end

function handleUpdate(green, yellow, red)
	redBlinkEnabled = red
	setOut(greenSide, green and 15 or 0)
	setOut(yellowSide, yellow and 15 or 0)
end

function updateRed()
	if computer.uptime() - lastRedUpdate < redBlinkFrequence then return end

	if not redBlinkEnabled then
		setOut(redSide, 0)
	else
		local power = 15 - signal.getOutput(redSide)
		signal.setOutput(redSide, power)
	end

	lastRedUpdate = computer.uptime()
end

function start()
	while true do
		local args = {computer.pullSignal(updateFrequence)}
		if args ~= nil and args[1] == "modem_message" then 
			handleUpdate(args[6], args[7], args[8]) 
		end

		updateRed()
	end
end

setup()
start()