local serialization = require 'serialization'

function validate(fileName)
    if fileName == nil then
        self:showError("Validation called with missed file name")
        return {}
    end

    local file = io.open(fileName, "r")
    if file ~= nil then
        file:close()
        local index = 1
        for line in io.lines(fileName) do
            local result = validateLine(line)
            print(tostring(index) .. ": " .. tostring(result))
            os.sleep(0)
            index = index + 1
        end
    end
end

function validateLine(line)
    local wrapped = "{" .. line .. "}"
    local dict = serialization.unserialize(wrapped)
    return dict ~= nil
end