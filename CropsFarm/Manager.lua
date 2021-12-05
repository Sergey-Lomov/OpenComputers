serialization = require("serialization")
component = require("component")
computer = require("computer")
event = require("event")
term = require("term")
shared = require("shared")
status = require("status_client")

perchesFile = "perches" -- Contains ID and relative coords of all perches components
kindsFile = "kinds" -- Contains level for getting seeds for all kind of plants
weedKind = "weed"

broadcastRange = 16
linesPerPerch = 3 -- How many lines uses to present info about perch at screen
columnsPerPerch = 8 -- How many columns uses to present info about perch at screen
updateTimerStep = 2
uiUpdateRatio = 3 
uiClearRatio = 5
gainDisplacement = 0
growthDisplacement = 3
resistanceDisplacement = 6
weedCriticalSize = 3
weedProblemPostfix = "_weed"

weedConfig = {
    destroy = true,
    gain = 0,
    growth = 0,
    resistance = 0,
    maxSize = 5
}

-- String
Labels = {
    emptyKind = "  NONE  ",
    unsupportedKind = " UNSPEC ",
    missedPerch = " MISSED ",
    
    destroyResolution = "Destroy",
    getResolution = "Harwest",
    waitingResolution = "Growing",

    superWeedProblemMessage = "Обнаружен сорняк 3его размера"
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
    minX = 1000,
    minZ = 1000,
    maxX = -1000,
    maxZ = -1000,
    xOffset = 0,
    yOffset = 0,
    
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
    
    self.tasks = {}
    for id, position in pairs(perches) do
        local x = (position.x - self.minX) * columnsPerPerch + 1
        local z = (position.z - self.minZ) * linesPerPerch + 1
        
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
        -- Handle kind
        if kind == weedKind then
            kindConfig = weedConfig
            if size >= weedCriticalSize then
                local statusId = computer.address() .. weedProblemPostfix
                status:sendProblem(statusId, Labels.superWeedProblemMessage)
            end
        elseif kind == "" then
            gpu.setForeground(Colors.common)
            local label = farmTasksManager:formattedString(Labels.emptyKind)
            gpu.set(x, z + 1, label) 
            goto continue 
        elseif kindConfig == nil then
            gpu.setForeground(Colors.critical)
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
        
        -- Handle gain
        if gain < (kindConfig.gain or 0) then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.gain)    
        end
        gpu.set(x + gainDisplacement, z + 1, tostring(gain))
        
        -- Handle growth
        if growth < (kindConfig.growth or 0) then
            destroy = true
            gpu.setForeground(Colors.critical)
        else 
            gpu.setForeground(Colors.growth)    
        end
        gpu.set(x + growthDisplacement, z + 1, tostring(growth))
        
        -- Handle resistance
        if resistance < (kindConfig.resistance or 0) then
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