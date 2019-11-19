MBObjectList = {}

function MBObjectList:new()
    local newObj = {
        objs = {},
        idCounter = 0,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function MBObjectList:add(obj)
    local id = self.idCounter
    self.objs[id] = obj
    self.idCounter = self.idCounter + 1
    return id, obj
end

function MBObjectList:get(id)
    return self.objs[id]
end

return MBObjectList
