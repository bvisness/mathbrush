TogglePlaneGizmo = {}

function TogglePlaneGizmo:new(pos, isAlreadyPlane)
    local newObj = {
        pos = lovr.math.newVec3(pos),
        isAlreadyPlane = isAlreadyPlane,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function TogglePlaneGizmo:draw()
    lovr.graphics.setShader()
    printLabel(self.isAlreadyPlane and "Hide Plane" or "Show Plane", self.pos) -- TODO: Make this not global
end

return TogglePlaneGizmo
