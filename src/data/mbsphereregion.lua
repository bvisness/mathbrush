MBSphereRegion = {}

function MBSphereRegion:new(center, radius, info)
    local newObj = {
        center = lovr.math.newVec3(center),
        radius = radius,
        info = info,
        enabled = true,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function MBSphereRegion:checkPoint(point)
    if not self.enabled then
        return false, 0
    end

    dist = (point - self.center):length()
    if dist <= self.radius then
        return true, dist
    else
        return false, 0
    end
end

return MBSphereRegion
