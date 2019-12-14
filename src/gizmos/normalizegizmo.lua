NormalizeGizmo = {}

function NormalizeGizmo:new(pos)
    local newObj = {
        pos = lovr.math.newVec3(pos),
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function NormalizeGizmo:draw()
    lovr.graphics.setShader()
    printLabel("normalize", self.pos) -- TODO: This should probably be imported from somewhere
end

return NormalizeGizmo
