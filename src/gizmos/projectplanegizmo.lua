ProjectOntoPlaneGizmo = {}

function ProjectOntoPlaneGizmo:new(pos)
    local newObj = {
        pos = lovr.math.newVec3(pos),
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function ProjectOntoPlaneGizmo:draw()
    lovr.graphics.setShader()
    printLabel("project", self.pos) -- TODO: This should probably be imported from somewhere
end

return ProjectOntoPlaneGizmo
