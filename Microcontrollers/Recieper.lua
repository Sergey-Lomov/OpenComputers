-- Reciper v1.0

--local computer = require 'computer'
--local component = require 'component'
--local serialization = require 'serialization'

codes = {} codesMaxSize = {} fingerprints = {} recipes = {} outSides = {}

transposer = component.proxy(component.list("transposer")())
inSide = 2
handleableSlots = 8 -- Due to optimisation. To avoid time-valuable check of empty slots. All unhandleable slots should be filled by some items to prevent using by interface.
machineFirstIn = 1
machineLastIn = 2

function setup()
	requestData()

	for side = 0, 5, 1 do
		if side == inSide then goto continue end
		
		local inventorySize = transposer.getInventorySize(side)
		if type(inventorySize) == "number" then
			table.insert(outSides, side)
		end
		
		::continue::
	end

	for _, recipe in ipairs(recipes) do
		recipe.require = {}
		for _, item in ipairs(recipe.schema) do
			recipe.require[item.code] = recipe.require[item.code] or {total = 0, max = 0}
			local require = recipe.require[item.code]
			require.total = require.total + item.count
			require.max = math.max(require.max, item.count)
		end
	end

	for fingerprint, code in pairs(codes) do
		fingerprints[code] = fingerprint
	end
end

local port = 2327
local dataId = "induction_recipes"
local modem = component.proxy(component.list("modem")())
function requestData()
	if modem == nil then computer.beep(900, 3) return end
	modem.open(port)

	while true do
		modem.broadcast(port, dataId)
		local args = {computer.pullSignal(10)}

		if args[1] == "modem_message" and args[4] == port then
			codes, recipes = load(args[#args])()
			computer.beep(300, 3)
			modem.close(port)
			return
		end
	end
end

function recipesValidation()
	local uses = {}
	for _, recipe in ipairs(recipes) do
		for code, _ in pairs(recipe.require) do
			uses[code] = (uses[code] or 0) + 1
		end
	end

	for _, recipe in ipairs(recipes) do
		local multiuses = 0
		for code, _ in pairs(recipe.require) do
			if uses[code] > 1 then
				multiuses = multiuses + 1
			end
		end

		if multiuses > 1 then 
			handleRecipesConflict()
			return
		end
	end
end

function firstSlotByFingerprint(side, value)
	for i = 1, handleableSlots, 1 do
		local stack = transposer.getStackInSlot(side, i)
		if stack ~= nil then
			local fingerprint = stack.name .. ":" .. tostring(stack.damage)
			if fingerprint == value then
				return i
			end
		end
	end
	return nil
end

function getCounts()
	local counts = {}

	for index = 1, handleableSlots, 1 do
		local stack = transposer.getStackInSlot(inSide, index)
		if stack == nil then goto continue end

		local fingerprint = stack.name .. ":" .. tostring(stack.damage)
		local code = codes[fingerprint]
		if code == nil then handleInvalidResource() return end
		counts[code] = (counts[code] or 0) + stack.size
		codesMaxSize[code] = stack.maxSize

		::continue::
	end

	return counts
end

function selectRecipe(counts)
	local resultRecipe = nil
	local resultTimes = 0
	for _, recipe in ipairs(recipes) do
		local recipeTimes = math.huge
		for code, require in pairs(recipe.require) do
			local codeCount = counts[code] or 0
			local codeTimes = math.modf(codeCount / require.total)
			if codeTimes == 0 then
				goto continue
			end
			recipeTimes = math.min(recipeTimes, codeTimes)
		end

		if recipe.maxTimes == nil then
			local maxTimes = math.huge
			for code, require in pairs(recipe.require) do
				local codeTimes = math.modf(codesMaxSize[code] / require.max)
				maxTimes = math.min(maxTimes, codeTimes)
			end
			recipe.maxTimes = maxTimes
		end

		resultRecipe = recipe 
		resultTimes = recipeTimes
		break

		::continue::
	end

	return resultRecipe, resultTimes
end

function checkRecipeAtSide(recipe, side)
	local processingTimes = math.huge
	for index = machineFirstIn, machineLastIn, 1 do
		local stack = transposer.getStackInSlot(side, index)
		if stack == nil then 
			processingTimes = 0
			goto continue 
		end

		local fingerprint = stack.name .. ":" .. tostring(stack.damage)
		local stackCode = codes[fingerprint]
		if stackCode ~= recipe.schema[index].code then 
			return false, 0
		end

		local oneTimeCount = recipe.schema[index].count
		local itemTimes = math.modf(stack.size / oneTimeCount)
		processingTimes = math.min(processingTimes, itemTimes)

		::continue::
	end

	return true, processingTimes
end

function applyRecipeTransferToSide(recipe, side, times)
	for index, item in ipairs(recipe.schema) do
		local fingerprint = fingerprints[item.code]
		local countLeft = times * item.count
		while countLeft > 0 do
			local sourceSlot = firstSlotByFingerprint(inSide, fingerprint)
			local sourceCount = transposer.getSlotStackSize(inSide, sourceSlot)
			local transferCount = math.min(sourceCount, countLeft)
			local result = transposer.transferItem(inSide, side, transferCount, sourceSlot, index)
			if result then
				countLeft = countLeft - transferCount
			end
		end
	end
end

function transferItems(recipe, times)
	local totalTimes = times
	local validSides = {}
	for _, side in ipairs(outSides) do
		local available, processingTimes = checkRecipeAtSide(recipe, side)
		if not available then goto continue end
		local description = {side = side, times = processingTimes}
		table.insert(validSides, description)
		totalTimes = totalTimes + processingTimes
		::continue::
	end

	if #validSides == 0 then return end

	local averageTimes = totalTimes / #validSides
	local planedTimes = math.min(averageTimes, recipe.maxTimes)
	local roundCredit = 0
	for _, description in ipairs(validSides) do
		local sideTimes = planedTimes - description.times
		local roundedTimes = math.floor(sideTimes + roundCredit + 0.5)
		roundCredit = sideTimes - roundedTimes
		applyRecipeTransferToSide(recipe, description.side, roundedTimes)
	end
end

function handleIteration()
	local counts = getCounts()
	local recipe, times = selectRecipe(counts)
	if recipe == nil then return end
	transferItems(recipe, times)
end

function handleInvalidResource()
	-- Add status handling system call
	while true do
		computer.beep(600, 0.5) os.sleep(0.5)
	end
end

function handleRecipesConflict()
	while true do
		computer.beep(300, 1) os.sleep(0.5)
	end
end

function start()
	while true do
		computer.pullSignal(0.5)
		handleIteration()
	end
end

setup()
recipesValidation()
start()