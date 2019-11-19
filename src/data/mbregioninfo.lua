MBRegionInfo = {}

function MBRegionInfo:new(type, data)
    local newObj = {
        type = type,
        data = data,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

return MBRegionInfo
