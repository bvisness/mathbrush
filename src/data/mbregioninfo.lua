MBRegionInfo = {}

function MBRegionInfo:new(t, data)
    local newObj = {
        t = t,
        data = data,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

return MBRegionInfo
