serialization = require("serialization")
component = require("component")
event = require("event")
computer = require("computer")
robot = require("robot")
sides = require("sides")
navigator = require("navigator")
shared = require("shared")
status = require("status_client")

inventory = component.inventory_controller
configFile = "config"
criticalEnergy = 0.25
richEnergy = 0.8
idleTime = 5
perchStack = 64
perchLimit = 2 -- If robot have only 2 perch in active slot it should return to charger for get more
pingAllowableDelay = 30
pingRange = 16

Commands = {
    stopWork = "стой",
    startWork = "продолжай",
    startCommunication = "на связь",
    finishCommunication = "конец связи",
    startReporting = "давай отчет",
    finishReporting = "хватит отчетов",
    showStatistic = "расскажи статистику"
}

Phrases = {
    workStarted = "Начинаю работу",
    workStopped = "Стою",
    communicationStarted = "На связи",
    approve = "Принял",
    unauthorized = "Ты еще кто %s? Я тебя не знаю",
    unspecCommand = "Что-то не пойму о чем ты. Я знаю: ",
    underConstruction = "Это еще не готово",
    
    waitingTasks = "Жду задачи от меинфрейма",
    getTasks = "Получил задачи",
    idle = "Заданий нет - передохну",
    goToWorkArea = "Заданий нет - возвращаюсь в зону работы",
    destroyAt = "Лечу уничтожать",
    harvestAt = "Лечу собирать",
    rechargeEnergyCritical = "Энергия критическая, лечу на зарядку",
    rechargeEnergyNotRich = "Подзаряжусь пока нечего делать",
    rechargePerches = "Кончились жёрдочки, пора на заправку",
    notEnoughCharged = "Продолжаю заряжаться"
}

farmBot = {
    tasks = {},
    configuration = {},
    active = false,
    currentTaskIndex = 1,
    idleTimerId = nil,
    rechargeTimerId = nil,
    voiceControl = false,
    voiceReporting = false,
    subscribedToChat = false,
    outOfArea = true,
}

local handleModemEvent = function(...)
    local _,_,_,_,_,code,data = table.unpack { ... }

    if code == MessagesCodes.STOP_BOT then
        farmBot.stop()
    elseif code == MessagesCodes.TASKS_BROADCAST then
        farmBot:handleTasksBroadcast(data)
    end
end

function farmBot:start()
    farmBot.active = true
    
    farmBot:updateConfig()
    navigator.cruiseHeight = farmBot.configuration.cruiseHeight
    navigator:restoreState()

    component.modem.open(shared.port)

    status.pingId = computer.address()
    status.pingRange = pingRange
    status:requestPingWaiting(farmBot.configuration.pingTitle, pingAllowableDelay)
    
    farmBot:startChatHandling() 
    farmBot:performNextAction(false)
end

function farmBot:updateConfig()
    farmBot.configuration = shared:loadFrom(configFile)
end

function farmBot:startChatHandling() 
    if self.subscribedToChat then return end
    
    handleChatEvent = function(...)
        local _,_,author,command = table.unpack { ... }
        farmBot:handleVoiceCommand(author, command)
    end
    
    event.listen("chat_message", handleChatEvent)
    self.subscribedToChat = true
end

function farmBot:stop()
    component.modem.close(shared.port)
    farmBot.active = false
    
    if farmBot.idleTimerId ~= nil then
        event.cancel(farmBot.idleTimerId)
    end
    
    if farmBot.rechargeTimerId ~= nil then
        event.cancel(farmBot.rechargeTimerId)
    end
    
    event.ignore("modem_message", handleModemEvent)
end

function farmBot:handleVoiceCommand(author, message)

    local usersList = farmBot.configuration.voiceUsers
    local chat = component.chat
    
    if string.find(message, farmBot.configuration.voicePrefix) ~= 1 then
        -- Message not addressed to robot
        return
    end
    local command = string.gsub(message, farmBot.configuration.voicePrefix, "")
    
    local authorized = false
    for user in string.gmatch(usersList, '([^,]+)') do
        authorized = authorized or (user == author)
    end
    
    if not authorized then 
        print("Unauthorizerd")
        local phrase = string.format(Phrases.unauthorized, author)
        chat.say(pharse)
        return
    end

    if command == Commands.startCommunication then
        farmBot.voiceControl = true
        chat.say(Phrases.communicationStarted)
    elseif not farmBot.voiceControl then
        -- Voice controll disabled - bot ignore all commands
        return
    elseif command == Commands.finishCommunication then
        farmBot.voiceControl = false
        chat.say(Phrases.approve)
    elseif command == Commands.stopWork then
        farmBot:stop()
        chat.say(Phrases.workStopped)
    elseif command == Commands.startWork then
        farmBot:start()
        chat.say(Phrases.workStarted)
    elseif command == Commands.startReporting then
        farmBot.voiceReporting = true
        chat.say(Phrases.approve)
    elseif command == Commands.finishReporting then
        farmBot.voiceReporting = false
        chat.say(Phrases.approve)
    elseif command == Commands.showStatistic then
        chat.say(Phrases.underConstruction)
    else 
        local help = table.concat({
            Commands.startCommunication,
            Commands.finishCommunication,
            Commands.startWork,
            Commands.stopWork, 
            Commands.startReporting,
            Commands.finishReporting,
            Commands.showStatistic
        }, ", ")
        chat.say(Pharases.unspecCommand .. help)
    end
end

function farmBot:report(message)
    local full = tostring(os.time()) .. " " .. message
    print(full)
    if farmBot.voiceReporting then
        component.chat.say(full)
    end
end

function farmBot:reportTask(task)
    local workPhrase = Phrases.destroyAt
    if task.work == Works.GET_SEEDS then
        workPhrase = Phrases.harvestAt
    end
    
    local message = workPhrase .. " x: " .. task.position.x .. " z: " .. task.position.z
    print(message)
    if farmBot.voiceReporting then
        component.chat.say(message)
    end
end

function farmBot:performNextAction(tasksUpdated)
    if not farmBot.active then 
        print("Stoped")
        return 
    end
    
    status:sendPing()

    local energy = computer.energy() / computer.maxEnergy()
    local nextTaskIndex = self.currentTaskIndex + 1
    local nextTask = self.tasks[nextTaskIndex]
    
    if (energy <= criticalEnergy) then
        -- Enery low - need to charge first after all
        farmBot:report(Phrases.rechargeEnergyCritical)
        farmBot:goToCharge()
    elseif (farmBot:perchesCount() <= perchLimit) then
        -- Not enought perches
        farmBot:report(Phrases.rechargePerches)
        farmBot:goToCharge()
    elseif nextTask ~= nil then
        -- Energy enought and bot have a tasks, so let's do next
        farmBot:reportTask(nextTask)
        farmBot:executeTask(nextTask)
    elseif not tasksUpdated then
        -- Energy enough but bot has done all tasks, so let's wait tasks broadcast from mainframe
        farmBot:report(Phrases.waitingTasks)
        event.listen("modem_message", handleModemEvent)
    elseif energy <= richEnergy then
        -- Energy enough, but not very much. Bot has done all tasks and mainframe provide no tasks for now. So let's charge to avoid idle.
        farmBot:report(Phrases.rechargeEnergyNotRich)
        farmBot:goToCharge()
    elseif farmBot.outOfArea then
        -- Have no tasks. Lets go back to work area for avoid long trevel when tasks will be
        farmBot:goToWorkArea()
    else
        -- Energy at high level, bot has done all tasks and be in work area. So let's wait a new tasks broadcast.
        farmBot:wait()
    end
end

function farmBot:perchesCount()
    -- Regarding to spec, first 4 index for robot.count() should be related to belt slots. But game still return to me inventory slots.
    -- So uses this trick for check count of items in tool slot
    inventory.equip()
    local perchCount = robot.count()
    inventory.equip()
    return perchCount
end

function farmBot:wait()
        farmBot:report(Phrases.idle)
        idlePosition = {x = navigator.x, y = farmBot.configuration.workHeight or 0, z = navigator.z}
        navigator:goTo(idlePosition)
        event.listen("modem_message", handleModemEvent)
end

function farmBot:goToWorkArea()
    farmBot:report(Phrases.goToWorkArea)
    local idlePosition = farmBot.configuration.area[1]
    navigator:goTo(idlePosition)
    navigator.cruiseHeight = farmBot.configuration.workHeight
    farmBot.outOfArea = false
    farmBot:performNextAction(false)
end

function farmBot:handleTasksBroadcast(data) 
    event.ignore("modem_message", handleModemEvent)
    local allTasks = serialization.unserialize(data)
    farmBot.tasks = {}
    self.currentTaskIndex = 0
    
    local total = 0
    local inArea = 0
    for _, task in pairs(allTasks) do
        if farmBot:isPositionInWorkArea(task.position) then
            table.insert(farmBot.tasks, task)
            inArea = inArea + 1 
        end
     total = total + 1 
    end
    
    local message = Phrases.getTasks .. " (" .. tostring(inArea) .. " / " .. tostring(total) .. ")"
    farmBot:report(message)

    farmBot:performNextAction(true)
end

function farmBot:goToCharge()

    farmBot.outOfArea = true

    local charge = farmBot.configuration.charger
    navigator.cruiseHeight = farmBot.configuration.cruiseHeight
    local perchesFace = Orientation:fromCode(charge.perchesFace)
    local unloadingFace = Orientation:fromCode(charge.unloadingFace)

    navigator:goTo(charge.prePosition)
    navigator:rawGoTo(charge.position)
    inventory.dropIntoSlot(sides.down, 1)
    navigator:faceTo(perchesFace)

    while farmBot:perchesCount() < perchStack do
        os.sleep(1)
    end
    
    navigator:faceTo(unloadingFace)
    local slotIndex = 2 -- First slot reserved to switch with toll for check perches count
    while slotIndex <= robot.inventorySize() do
        robot.select(slotIndex)
        inventory.dropIntoSlot(sides.front, slotIndex)
        slotIndex = slotIndex + 1
    end
    robot.select(1)

    -- Some time system load perches into first slot until robot unloading
    if robot.count(1) ~= 0 then
        local emptyIndex = 2
        -- For now will not handle situation, when all slots are busy even after unload
        while robot.count(emptyIndex) ~= 0 do
            emptyIndex = emptyIndex + 1
        end
        robot.transferTo(emptyIndex)
    end
    inventory.suckFromSlot(sides.down, 1)
    
    navigator:rawGoTo(charge.postPosition)
    farmBot:performNextAction(false)
end

function farmBot:executeTask(task)
    
    local coords = task.position
    local work = "Unknown"
    if task.work == Works.DESTROY then
        work = "Destroy"
    elseif task.work == Works.GET_SEEDS then
        work = "Get seeds"
    end
    local descrpition = string.format("%s at x: %d  y: %d  z: %d", work, coords.x, coords.y, coords.z)
    print(descrpition)

    navigator:goTo(task.position)
    if farmBot.outOfArea then
        navigator.cruiseHeight = farmBot.configuration.workHeight
        farmBot.outOfArea = false
    end

    -- Destroy perches and waiting to avoid bug when robot put perches again early then fully destroy old
    robot.swingDown() 
    os.sleep(1.5)
    
    -- Some time between oild perches swing and new perches setting, eath became a grass. Robot should handle this scenario.
    
    ::set_perches::
    _, result = robot.detectDown()
    if result == "replaceable" then -- This means grass sprite
        robot.swingDown() -- Destroy grass
        inventory.equip() -- Equip hoe
        robot.useDown() -- Use hoe to ground
        inventory.equip() -- Equip perches
    end

    -- Try to set perches 
    robot.useDown()
    robot.useDown()
    os.sleep(1)

    _, result = robot.detectDown()
    if result ~= "solid" then -- Solid type means perches setted successfully
        goto set_perches
    end

    self.currentTaskIndex = self.currentTaskIndex + 1
    farmBot:performNextAction(false)
end

function farmBot:isPositionInWorkArea(position)
    local area = farmBot.configuration.area
    for _, point in pairs(area) do
        if point.x == position.x and point.y == position.y and point.z == position.z then
            return true
        end
    end
    return false
end

return farmBot