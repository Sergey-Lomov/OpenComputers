-- Reciper v1.0

--local computer = require 'computer'
--local component = require 'component'

codes = {} 
cms = {} -- Max stack sizes for code
fps = {} -- Fingerprints
rs = {} -- Recipes
oss = {0} -- Out sides

tr = component.proxy(component.list("transposer")())
m = component.proxy(component.list("modem")())
m.setStrength(60)

inSide = 1
hss = 9 -- Handleable slots. Due to optimisation. To avoid time-valuable check of empty slots. All unhandleable slots should be filled by some items to prevent using by interface.
fi = 3 -- Machine first in slot
li = 11 -- Machine last in slot

sp = 4361 -- Status system port
pid = "gas1_id" -- Ping id
pt = "Сбор. цех 1" -- Ping title
crid = pid .. "_conflict_rec" -- Conflict recipes problem id
irid = pid .. "_invalid_res" -- Invalid resource problem id

dp = 2327 -- Data system port
dataId = "galaxy_assembler_recipes_1"

function setup()
	rDa()

	for _, recipe in ipairs(rs) do
		recipe.require = {}
		for _, item in ipairs(recipe.schema) do
			recipe.require[item.code] = recipe.require[item.code] or {total = 0, max = 0}
			local require = recipe.require[item.code]
			require.total = require.total + item.count
			require.max = math.max(require.max, item.count)
		end
	end

	for fingerprint, code in pairs(codes) do
		fps[code] = fingerprint
	end
end

function sPr(id, message) -- Send problem
	local data = string.format('{id="%s",message="%s"}', id, message)
	m.broadcast(sp, 2, data)
end

lastPing = 0
function sPi() -- Send ping
	if computer.uptime() - lastPing < 15  then return end
	local data = string.format('{id="%s",title="%s"}', pid, pt)
	m.broadcast(sp, 3, data)
	lastPing = computer.uptime()
end

function rDa() -- Request data
	m.open(dp)

	while true do
		m.broadcast(dp, dataId)
		local args = {computer.pullSignal(10)}

		if args[1] == "modem_message" and args[4] == dp then
			codes, rs = load(args[#args])()
			computer.beep(300, 3)
			m.close(dp)
			return
		end
	end
end

function vRe() -- Validate recipes
	local uses = {}
	for _, recipe in ipairs(rs) do
		for code, _ in pairs(recipe.require) do
			uses[code] = (uses[code] or 0) + 1
		end
	end

	for _, recipe in ipairs(rs) do
		local multiuses = 0
		for code, _ in pairs(recipe.require) do
			if uses[code] > 1 then
				multiuses = multiuses + 1
			end
		end

		if multiuses > 1 then 
			sPr(crid, pt .. ": конфликт рецептов")
			while true do
				computer.beep(300, 1)
				computer.pullSignal(0.5)
			end
		end
	end
end

function fsbf(side, value) -- First slot by fingerprint
	for i = 1, hss, 1 do
		local stack = tr.getStackInSlot(side, i)
		if stack ~= nil then
			local fingerprint = stack.name .. ":" .. tostring(stack.damage)
			if fingerprint == value then
				return i
			end
		end
	end
	return nil
end

function gCo() -- Get counts
	local counts = {}

	for index = 1, hss, 1 do
		local stack = tr.getStackInSlot(inSide, index)
		if stack == nil then goto continue end

		local fingerprint = stack.name .. ":" .. tostring(stack.damage)
		local code = codes[fingerprint]
		
		if code == nil then 
			sPr(irid, pt .. ": неизвестный ресурс")
			while true do
				computer.beep(600, 0.5)
				computer.pullSignal(0.5)
			end 
		end

		counts[code] = (counts[code] or 0) + stack.size
		cms[code] = stack.maxSize

		::continue::
	end

	return counts
end

function sRe(counts) -- Select recipe
	local resultRecipe = nil
	local resultTimes = 0
	for _, recipe in ipairs(rs) do
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
				local codeTimes = math.modf(cms[code] / require.max)
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

function cras(recipe, side) -- Check recipe at side
	local processingTimes = math.huge
	for index = fi, li, 1 do
		local stack = tr.getStackInSlot(side, index)
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

function artts(recipe, side, times) -- Aply recipe transfer to side
	for index, item in ipairs(recipe.schema) do
		local fingerprint = fps[item.code]
		local countLeft = times * item.count
		local targetIndex = index + fi - 1
		while countLeft > 0 do
			sPi()
			local sourceSlot = fsbf(inSide, fingerprint)
			local sourceCount = tr.getSlotStackSize(inSide, sourceSlot)
			local transferCount = math.min(sourceCount, countLeft)
			local result = tr.transferItem(inSide, side, transferCount, sourceSlot, targetIndex)
			if result then
				countLeft = countLeft - transferCount				
			end
		end
	end
end

function tIt(recipe, times) -- Transfefr items
	local totalTimes = times
	local validSides = {}
	for _, side in ipairs(oss) do
		local available, processingTimes = cras(recipe, side)
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
		artts(recipe, description.side, roundedTimes)
	end
end

function start()
	m.broadcast(sp, 4, crid)
	m.broadcast(sp, 4, irid)
	while true do
		local _, e = pcall( 
			function()
				while true do
					computer.pullSignal(0.5)
					sPi()
					local counts = gCo()
					local recipe, times = sRe(counts)
					if recipe ~= nil then tIt(recipe, times) end
				end
			end
		)
		sPr(pid .. "_crash", pt .. ": креш\n" .. tostring(e))
		computer.shutdown(true)
	end
end

setup()
vRe()
start()