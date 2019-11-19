local MBExpression = require('data/mbexpression')
local MBExpressionResult = require('data/mbexpressionresult')

MBVec = {}

MBVec.PARENT_TIP = 'tip'
MBVec.PARENT_TAIL = 'tail'

-- All arguments must be _expressions_, not just values.
function MBVec:new(valueExpr, posExpr)
    local initialValue = valueExpr:evaluate().value
    local initialPos = posExpr:evaluate().value

    local newObj = {
        valueExpr = valueExpr,
        posExpr = posExpr,

        computedValue = initialValue,
        computedPos = initialPos,
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function vstring(v)
    return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
end

function MBVec:update()
    local valueResult = self.valueExpr:evaluate()
    local posResult = self.posExpr:evaluate()

    -- handle evaluation errors and their updates here?

    self.computedValue = valueResult.value
    self.computedPos = posResult.value

    return valueResult.value, posResult.value
end

function vecReferenceExpression(vecList, vecId, f)
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
