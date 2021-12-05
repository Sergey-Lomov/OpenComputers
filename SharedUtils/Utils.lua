serialization = require("serialization")
term = require("term")
computer = require("computer")
event = require("event")

utils = {
	errorColor = 0xFF0000,
    infoColor = 0xAAAAAA
}

function utils:pr(e)
	for k,v in pairs(e) do print(k,v) end
end

function utils:loadFrom(fileName)
    local serialized = ""
    local file = io.open(fileName, "r")
    if file ~= nil then
        file:close()
        for line in io.lines(fileName) do
            serialized = serialized .. line
        end
    else 
        serialized = "{}"
    end
    
    return serialization.unserialize(serialized)
end

function utils:saveTo(fileName, entity)
    local file = io.open(fileName, "w")
    local serialized = serialization.serialize(entity)
    file:write(serialized)
    file:close()
end

function utils:showMessage(message, color)
    local gpu = term.gpu()
    local initialColor = gpu.getForeground()
    gpu.setForeground(color)
    print(message)
    gpu.setForeground(initialColor)
end

function utils:showError(message)
	self:showMessage(message, self.errorColor)
end

function utils:showInfo(message)
    self:showMessage(message, self.infoColor)
end

function shortTraceback()
    local level = 1
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        if info.what == "C" then   -- is a C function?
            print(level, "C function")
        else   -- a Lua function
            print(string.format("[%s]:%d", info.short_src, info.currentline))
        end
        level = level + 1
    end
end

function utils:profile(func)
    local startTime = os.time()
    local startEnergy = computer.energy()
    func()
    local timeDiff = os.time() - startTime
    local energyDiff = computer.energy() - startEnergy
    print("Time (millisec): " .. tostring(timeDiff) .. " energy: " .. tostring(energyDiff))
end

function utils:profileEvents()
    while true do
        print(event.pull())
    end
end

return utils