serialization = require("serialization")

MessagesCodes = {
    STOP_BOT= 0,
    TASKS_BROADCAST = 2
}

Works = {
    DESTROY = 0,
    GET_SEEDS = 1
}

Task = { 
    work = Works.DESTROY,
    position = {x = 0, y = 0, z = 0}
}

function Task:new (obj, work, position)
   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self
   obj.work = work or Works.DESTROY
   obj.position = position or {x = 0, y = 0, z = 0}
   return obj
end

shared = {port = 14870}

function shared:loadFrom(fileName)
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

function shared:saveTo(fileName, entity)
    local file = io.open(fileName, "w")
    local serialized = serialization.serialize(entity)
    file:write(serialized)
    file:close()
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

return shared