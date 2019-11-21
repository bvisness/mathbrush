MBMathResult = {}

MBMathResult.TYPE_SCALAR = 'scalar'
MBMathResult.TYPE_VECTOR = 'vector'
MBMathResult.TYPE_ERROR = 'error'

function MBMathResult:new(type, value)
    newObj = {
        type = type,
        value = value,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

return MBMathResult
