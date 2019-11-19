CrossGizmo = {}

function CrossGizmo:new(pos, rot)
    local newObj = {
        pos = lovr.math.newVec3(pos),
        rot = lovr.math.newQuat(rot),
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function CrossGizmo:draw()
    lovr.graphics.setShader()
    lovr.graphics.print("x", self.pos, 0.1, self.rot)
end

return CrossGizmo
