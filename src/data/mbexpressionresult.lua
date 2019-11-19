MBExpressionResult = {}

MBExpressionResult.TYPE_SCALAR = 'scalar'
MBExpressionResult.TYPE_VECTOR = 'vector'
MBExpressionResult.TYPE_ERROR = 'error'

function MBExpressionResult:new(value, type)
    newObj = {
        value = value,
        type = type,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

return MBExpressionResult
