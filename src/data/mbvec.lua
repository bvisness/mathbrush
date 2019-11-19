local inspect = require('inspect')

local MBExpression = require('data/mbexpression')
local MBExpressionResult = require('data/mbexpressionresult')

MBVec = {}

MBVec.PARENT_TIP = 'tip'
MBVec.PARENT_TAIL = 'tail'

VEC_COLORS = {
    0xaaaaff,
    0xffaaaa,
    0xaaffaa,
    0xffaaff,
    0xaaffff,
}
currentColor = 1

-- All arguments must be _expressions_, not just values.
function MBVec:new(valueExpr, posExpr)
    local initialValue = valueExpr:evaluate().value
    local initialPos = posExpr:evaluate().value

    local newObj = {
        valueExpr = valueExpr,
        posExpr = posExpr,

        computedValue = initialValue,
        computedPos = initialPos,

        color = VEC_COLORS[currentColor],
    }
    self.__index = self

    currentColor = (currentColor % #VEC_COLORS) + 1

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

return MBVec
