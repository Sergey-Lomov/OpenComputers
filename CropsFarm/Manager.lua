serialization = require("serialization")
component = require("component")
computer = require("computer")
event = require("event")
term = require("term")
shared = require("shared")
status = require("status_client")
sides = require("sides")

local perchesFile = "perches" -- Contains ID and relative coords of all perches components
local kindsFile = "kinds" -- Contains level for getting seeds for all kind of plants
local weedKind = "weed"

local broadcastRange = 16
local linesPerPerch = 3 -- How many lines uses to present info about perch at screen
local columnsPerPerch = 8 -- How many columns uses to present info about perch at screen
local updateTimerStep = 2
local uiUpdateRatio = 3 
local uiClearRatio = 5
local gainDisplacement = 3
local growthDisplacement = 0
local resistanceDisplacement = 6
local weedCriticalSize = 3
local weedProblemPostfix = "_weed"
local prevent24Growth = false

weedConfig = {
    destroy = true,
    gain = {},
    growth = {},
    resistance = {},
    maxSize = 5
}

-- String
Labels = {
    emptyKind = "  NONE  ",
    unsupportedKind = " UNSPEC ",
    missedPerch = " MISSED ",
    exraGrowth = "EXT GR",
    
    destroyResolution = "Destroy",
    getResolution = "Harwest",
    waitingResolution = "Growing",

    superWeedProblemMessage = "Обнаружен сорняк критического размера"
}

-- Colors
Colors = {
    critical = 0xFF0000,
    warning = 0xAAAA00,
    common = 0x999999,
    unspec = 0x6666FF,
    success = 0x009900,
    secondayInfo = 0x666666,
    gain = 0xAAAA00,
    growth = 0x00AA00,
    resistance = 0x00AAAA,
}

farmTasksManager = {
    tasks = {},
    
    initTermWidth = 0,
    initTermHeight = 0,
    minX = 10000,
    minZ = 10000,
    maxX = -10000,
    maxZ = -10000,
    xOffset = 0,
    yOffset = 0,
    displaySide = sides.south, -- Pnly south and north supported for now
    
    updateTimerId = nil
}

-- This table is stub for gpu for avoid big amount of if-then-end in code, which may update UI or not
gpuStub = {
    fill = function (...) end,
    set = function (...) end,
    setForeground = function (...) end,
    getForeground = function (...) return 0xFFFFFF end
}


function farmTasksManager:readPerches()
    return shared:loadFrom(perchesFile)
end

function farmTasksManager:readKinds()
    return shared:loadFrom(kindsFile)
end

function farmTasksManager:showTasks()
    for id, task in pairs(self.tasks) do
        local work = "Unknown"
        if task.work == Works.DESTROY then
            work = "Destroy"
        elseif task.work == Works.GET_SEEDS then
            work = "Get seeds"
        end
        
        local description = string.format("%d %s x: %d  y: %d  z: %d", id, work, task.position.x, task.position.y, task.position.z)
        print(description)
    end
end
    
function farmTasksManager:formattedString(str)
    local result = str
    
    if string.len(str) > columnsPerPerch then
        result = string.sub(str, 1, columnsPerPerch - 1)
        result = result .. "…"
    end
    
    return result
end
    
function farmTasksManager:uiCoordForPosition(position)
    local x = 0
    local z = 0
    local width = self.maxX - self.minX
    local height = self.maxZ - self.minZ

    if self.displaySide == sides.north then
        x = (position.x - self.minX) * columnsPerPerch + 1
        z = (position.z - self.minZ) * linesPerPerch + 1
    elseif self.displaySide == sides.south then
        x = (width - (position.x - self.minX)) * columnsPerPerch + 1
        z = (height - (position.z - self.minZ)) * linesPerPerch + 1
    end

    return x, z
end

updatesCounter = 0
function farmTasksManager:broadcastTasks()
    local perches = self:readPerches()
    local kinds = self:readKinds()
    --[[ Each kind have following keys:
            - destroy. If true, this kind of seed should be destroyed in any case.
            - gain. Seed will be destroyed if gain attribute less than specified.
            - growth. Seed will be destroyed if growth attribute less than specified.
            - resistance. Seed will be destroyed if resistance attribute less than specified.
            - maxSize. Size for collect seeds if crop have enough good attributes.
    ]]--
 
    local gpu = gpuStub
    local updateUI = updatesCounter % uiUpdateRatio == 0
    if updateUI then
        if updatesCounter % (uiClearRatio * uiUpdateRatio) == 0 then
            term.clear()
        end
        gpu = term.gpu()
    end
    
    local initialColor = gpu.getForeground()
    local criticalWeedDetected = false
    
    self.tasks = {}
    for id, position in pairs(perches) do
        local x, z = self:uiCoordForPosition(position)
        
        -- Clear view area
        gpu.fill(x, z, columnsPerPerch, linesPerPerch, " ")
        
        local crop = component.proxy(id)
        if crop == nil then 
            gpu.setForeground(Colors.warning)
            local label = farmTasksManager:formattedString(Labels.missedPerch)
            gpu.set(x, z + 1, label) 
            goto continue 
        end
        
        local kind = crop.getID()
        local kindConfig = kinds[kind]
        local size = crop.getSize()
        local gain = crop.getGain()
        local growth = crop.getGrowth()
        local resistance = crop.getResistance()

        destroy = false

        if prevent24Growth and growth >= 24 then
            gpu.setForeground(Colors.critical)
            local kindLabel = farmTasksManager:formattedString(kind)
            gpu.set(x, z, kindLabel)
            local paramsLabel = tostring(gain) .. " " .. tostring(growth) .. " " .. tostring(resistance)
            gpu.set(x, z + 1, paramsLabel)
            local extraGrowthLabel = farmTasksManager:formattedString(Labels.exraGrowth)
            gpu.set(x, z + 2, extraGrowthLabel) 
            
            local task = Task:new(nil, Works.DESTROY, position)
            table.insert(self.tasks, task)
            goto continue
        end

        -- Handle kind
        if kind == weedKind then
            kindConfig = weedConfig
            if size >= weedCriticalSize then
                criticalWeedDetected = true
            end
        elseif kind == "" then
            gpu.setForeground(Colors.common)
            local label = farmTasksManager:formattedString(Labels.emptyKind)
            gpu.set(x, z + 1, label) 
            goto continue 
        elseif kindConfig == nil then
            gpu.setForeground(Colors.unspec)
            local kindLabel = farmTasksManager:formattedString(kind)
            gpu.set(x, z, kindLabel)
            local paramsLabel = tostring(gain) .. " " .. tostring(growth) .. " " .. tostring(resistance)
            gpu.set(x, z + 1, paramsLabel)
            local unsupLabel = farmTasksManager:formattedString(Labels.unsupportedKind)
            gpu.set(x, z + 2, unsupLabel) 
            goto continue
        end
            
        -- Handle forced destroy
        if kindConfig.destroy then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.common)    
        end
        local kindLabel = farmTasksManager:formattedString(kind)
        gpu.set(x, z, kindLabel)
            
        -- Handle growth
        local minGrowth = kindConfig.growth.min or 0
        local maxGrowth = kindConfig.growth.max or math.huge
        if growth < minGrowth or growth > maxGrowth then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.growth)    
        end
        gpu.set(x + growthDisplacement, z + 1, tostring(growth))

        -- Handle gain
        local minGain = kindConfig.gain.min or 0
        local maxGain = kindConfig.gain.max or math.huge
        if gain < minGain or gain > maxGain then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.gain)    
        end
        gpu.set(x + gainDisplacement, z + 1, tostring(gain))
        
        -- Handle resistance
        local minResistance = kindConfig.resistance.min or 0
        local maxResistance = kindConfig.resistance.max or math.huge
        if resistance < minResistance or resistance > maxResistance then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.resistance)    
        end
        gpu.set(x + resistanceDisplacement, z + 1, tostring(resistance))
        
        if destroy then
            gpu.setForeground(Colors.critical)
            local label = farmTasksManager:formattedString(Labels.destroyResolution)
            gpu.set(x, z + 2, label)
            
            local task = Task:new(nil, Works.DESTROY, position)
            table.insert(self.tasks, task)
        elseif size >= kindConfig.maxSize then
            gpu.setForeground(Colors.success)
            local label = farmTasksManager:formattedString(Labels.getResolution)
            gpu.set(x, z + 2, label)
            
            local task = Task:new(nil, Works.GET_SEEDS, position)
            table.insert(self.tasks, task)
        else
            gpu.setForeground(Colors.common)
            local label = farmTasksManager:formattedString(Labels.waitingResolution)
            gpu.set(x, z + 2, label)
        end
        
        ::continue::
    end

    gpu.setForeground(Colors.secondayInfo)
    gpu.set(1,1, tostring(updatesCounter))
    updatesCounter = updatesCounter + 1

    gpu.setForeground(initialColor)

    local weedIssueId = computer.address() .. weedProblemPostfix
    if criticalWeedDetected then
        status:sendProblem(weedIssueId, Labels.superWeedProblemMessage)
    else 
        status:cancelStatus(weedIssueId, false)
    end

    local serialized = serialization.serialize(self.tasks)
    component.modem.broadcast(shared.port, MessagesCodes.TASKS_BROADCAST, serialized)
end

function farmTasksManager:start()
    component.modem.setStrength(broadcastRange)

    -- View configuration
    term.clear()
    self.initTermWidth, self.initTermHeight = term.getViewport()
    local perches = farmTasksManager:readPerches()
    
    for _, position in pairs(perches) do 
        if self.minX > position.x then self.minX = position.x end
        if self.maxX < position.x then self.maxX = position.x end
        if self.minZ > position.z then self.minZ = position.z end
        if self.maxZ < position.z then self.maxZ = position.z end
    end
    
    local width = (self.maxX - self.minX + 1) * columnsPerPerch
    local height = (self.maxZ - self.minZ + 1) * linesPerPerch + 1
    print(tostring(width) .. tostring(height))
    term.gpu().setResolution(width, height)
    term.setCursor(0, height)
      
    updateClosure = function()
        farmTasksManager:broadcastTasks()
    end
    self.updateTimerId = event.timer(updateTimerStep, updateClosure, math.huge)
    farmTasksManager:broadcastTasks()
end

function farmTasksManager:stop()
    if self.updateTimerId == nil then return end -- So start was not called
    
    self.tasks = {}
    term.gpu().setResolution(self.initTermWidth, self.initTermHeight)

    event.cancel(self.updateTimerId)
    self.updateTimerId = nil
end

return farmTasksManager