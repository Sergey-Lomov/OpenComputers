serialization = require("serialization")
term = require("term")
computer = require("computer")
event = require("event")

utils = {
	errorColor = 0xFF0000,
    warningColor = 0xFFFF00,
    infoColor = 0xAAAAAA
}

function utils:pr(e)
	for k,v in pairs(e) do print(k,v) end
end

function utils:rawTextFrom(fileName)
    if fileName == nil then
        self:showError("rawTextFrom called with missed file name")
        return {}
    end

    local file = io.open(fileName, "r")
    if file ~= nil then
        file:close()
        local text = ""
        for line in io.lines(fileName) do
            text = text .. line
        end

        return text
    end

    return nil
end

function utils:loadFrom(fileName, rawConverters)
    if fileName == nil then
        self:showError("loafFrom called with missed file name")
        return {}
    end

    local serialized = self:rawTextFrom(fileName) or "{}"
    local result = serialization.unserialize(serialized)
    local converters = rawConverters or {}
    if next(converters) == nil then return result end

    self:applyConverters(result, converters)
    return result
end

function utils:applyConverters(tab, converters)
    for key, value in pairs(tab) do
        if type(value) ~= "table" then goto continue end

        self:applyConverters(value, converters)
        local converter = converters[key] or {}
        local fromRawFunc = converter.fromRaw
        if fromRawFunc ~= nil then
            tab[key] = fromRawFunc(value)
        end

        ::continue::
    end
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

function utils:showWarning(message)
    self:showMessage(message, self.warningColor)
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

function utils:realWorldSeconds()
    return os.time() * 0.01389 -- os.time() returns time in in-game second, which should be * 1000 / 60 / 60 / 20 to get realworld seconds
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

return utils