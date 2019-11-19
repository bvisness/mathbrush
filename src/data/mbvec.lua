local MBExpression = require('data/mbexpression')
local MBExpressionResult = require('data/mbexpressionresult')

MBVec = {}

MBVec.PARENT_TIP = 'tip'
MBVec.PARENT_TAIL = 'tail'

-- All arguments must be _expressions_, not just values.
function MBVec:new(value, pos)
    local newObj = {
        value = value,
        pos = pos,

        lastValue = value:evaluate(),
        lastPos = pos:evaluate(),
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function MBVec:compute()
    local valueResult = self.value:evaluate()
    local posResult = self.pos:evaluate()

    -- handle evaluation errors and their updates here?

    self.lastValue = valueResult.value
    self.lastPos = posResult.value

    return valueResult.value, posResult.value
end

function VecReferenceExpression(vecList, vecId, f)
    return {
        evaluate = function()
            local vec = vecList:get(vecId)
            if vec == nil then
                return MBExpressionResult:new("referenced missing vector " .. vecId, MBExpressionResult.TYPE_ERROR)
            else
                return f(vec)
            end
        end,
    }
end

return MBVec
