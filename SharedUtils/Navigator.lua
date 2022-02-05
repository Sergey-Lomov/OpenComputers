local robot = require("robot")
local utils = require("utils")

local stateFile = "nav_state"

Orientation = {
    north = {x = 0, z = -1, code = 0},
    east = {x = 1, z = 0, code = 1},
    south = {x = 0, z = 1, code = 2},
    west = {x = -1, z = 0, code = 3},
}

function Orientation:fromCode(code)
    if code == self.north.code then
        return self.north
    elseif code == self.south.code then
        return self.south
    elseif code == self.east.code then
        return self.east
    elseif code == self.west.code then
        return self.west
    else
        utils:showError("Try to create orientation from invalid code")
    end
end

local navigator = {
   x = 0,
   y = 0,
   z = 0,
   face = Orientation.north,
   cruiseY=nil,
   voiceLog = false
}

function navigator:report(message)
    if not self.voiceLog then return end

    local chat = component.chat
    if chat ~= nil then
        chat.say(message)
    end
end

function navigator:moveByAxis (axis, to, lessFace, largeFace, routine)
    local targetFace = self.face
    if self[axis] == to then
        return
    elseif self[axis] < to then
        targetFace = lessFace
    elseif self[axis] > to then
        targetFace = largeFace
    end
    
    self:faceTo(targetFace)
    while self[axis] ~= to do
        self:safeForward(routine)
    end
end

function navigator:moveByX(to, routine)
    self:moveByAxis("x", to, Orientation.east, Orientation.west, routine)
end

function navigator:moveByZ(to, routine)
    self:moveByAxis("z", to, Orientation.south, Orientation.north, routine)
end

function navigator:safeUp(routine)
    if robot.up() then
        self.y = self.y + 1
        self:saveState()
        if routine ~= nil then routine() end
    end
end

function navigator:safeDown(routine)
    if robot.down() then
        self.y = self.y - 1
        self:saveState()
        if routine ~= nil then routine() end
    end
end
    
function navigator:safeForward(routine)
    if robot.forward() then
        self.x = self.x + self.face.x
        self.z = self.z + self.face.z
        self:saveState()
        if routine ~= nil then routine() end
    end
end

function navigator:safeRight()
    if robot.turnRight() then
        local newCode = self.face.code + 1
        if newCode > Orientation.west.code then
            newCode = Orientation.north.code
        end
        self.face = Orientation:fromCode(newCode)
    end
    
    self:saveState()
end

function navigator:safeLeft()
    if robot.turnLeft() then
        local newCode = self.face.code - 1
        if newCode < Orientation.north.code then
            newCode = Orientation.west.code
        end
        self.face = Orientation:fromCode(newCode)
    end
    
    self:saveState()
end

function navigator:safeAround()
    if robot.turnAround() then
        if self.face == Orientation.north then
            self.face = Orientation.south
        elseif self.face == Orientation.south then
            self.face = Orientation.north
        elseif self.face == Orientation.east then
            self.face = Orientation.west
        elseif self.face == Orientation.west then
            self.face = Orientation.east
        else
            utils:showError("Unsupported face orientation in safeAround")
        end
    end
    
    self:saveState()
end

function navigator:faceTo(target)
    if type(target) == "number" then
        target = Orientation:fromCode(target)
    end

    local delta = target.code - self.face.code

    if delta == 0 then
        return
    elseif delta == 2 or delta == -2 then
        self:safeAround()
    elseif delta == 1 or delta == -3 then -- Delta -3 is turn right from west to north
        self:safeRight()
    else
        self:safeLeft()
    end
end

function navigator:rawGoTo(target, routine)
    -- Vertical movement
    if self.y < target.y then
        while self.y ~= target.y do
            self:safeUp(routine)
        end 
    elseif self.y > target.y then
        while self.y ~= target.y do
            self:safeDown(routine)
        end 
    end
    
    self:moveByX(target.x, routine)
    self:moveByZ(target.z, routine)
end

function navigator:saveState()
    local state = {
        x = self.x,
        y = self.y,
        z = self.z,
        faceCode = self.face.code,
        cruiseHeight = self.cruiseHeight
    }
    utils:saveTo(stateFile, state)
end

function navigator:restoreState()
    local state = utils:loadFrom(stateFile)
    self.x = state.x or 0
    self.y = state.y or 0
    self.z = state.z or 0
    self.face = Orientation:fromCode(state.faceCode or 0)
    self.cruiseHeight = state.cruiseHeight
end

-- Public methods

function navigator:init()
    self:restoreState()
end

function navigator:nullify()
    self.x = 0
    self.y = 0
    self.z = 0
    
    -- Robot should be faced to north
    self.face = Orientation.north

    self:saveState()
end

function navigator:goTo(target, routine)
    self:report("Go to: " .. tostring(target.x) .. " ".. tostring(target.y) .. " ".. tostring(target.z))

    local cruiseHeight = navigator.cruiseHeight
    if cruiseHeight ~= nil then
        local point1 = {x = self.x, y = cruiseHeight, z = self.z}
        local point2 = {x = target.x, y = cruiseHeight, z = target.z}
       navigator:rawGoTo(point1, routine)
       navigator:rawGoTo(point2, routine)
       navigator:rawGoTo(target, routine)
    else
       navigator:rawGoTo(target, routine)
    end
end

function navigator:snakeFill(from, to, routine)
    if from.y ~= to.y then
        utils:showError("Snake fill moving is impossible for points with different Y")
        return
    end

    self.cruiseHeight = nil
    local finishX = to.x
    if (from.z - to.z + 1) % 2 == 0 then
        finishX = from.x
    end
    local finish = {x = finishX, z = to.z}

    self:goTo(from)
    if routine ~= nil then routine() end

    local completed = false
    while not completed do
        -- Move whole line by x
        local x = 0
        if self.x == from.x then 
            x = to.x
        else
            x = from.x
        end
        local nextPoint = {x = x, y = self.y, z = self.z}
        self:goTo(nextPoint, routine)
        
        finished = self.x == finish.x and self.z == finish.z
        if finished then break end

        -- Move one step by z
        local nextZ = self.z + 1
        if to.z < from.z then
            nextZ = self.z - 1
        end

        nextPoint = {x = self.x, y = self.y, z = nextZ}
        self:goTo(nextPoint, routine)
        finished = self.x == finish.x and self.z == finish.z
    end
end

function navigator:runRoute(route, routine)
    for i = 1, #route do
        self:rawGoTo(route[i], routine)
    end
end

function navigator:runRouteReverse(route, routine)
    for i = #route, 1, -1 do
        self:rawGoTo(route[i], routine)
    end
end

navigator:init()

return navigator