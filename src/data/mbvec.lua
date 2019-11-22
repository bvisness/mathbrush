local inspect = require('inspect')

MBVec = {}

VEC_COLORS = {
    0xaaaaff,
    0xffaaaa,
    0xaaffaa,
    0xffaaff,
    0xaaffff,
}
currentColor = 1

VEC_LABELS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
currentLabel = 1

function MBVec:new(value, pos, isPoint)
    local freeValue, freePos = nil, nil

    if type(value) ~= 'function' then
        freeValue = value
    end
    if type(pos) ~= 'function' then
        freePos = pos
    end

    self.__index = self
    local newObj = {
        valueFunc = freeValue and self.freeValueFunc or value,
        posFunc = freePos and self.freePosFunc or pos,

        computedValue = lovr.math.newVec3(0, 0, 0),
        computedPos = lovr.math.newVec3(0, 0, 0),
        computedExpr = '(not computed)',

        freeValue = lovr.math.newVec3(freeValue or vec3(0, 0, 0)),
        freePos = lovr.math.newVec3(freePos or vec3(0, 0, 0)),

        label = VEC_LABELS:sub(currentLabel, currentLabel),
        color = VEC_COLORS[currentColor],
    }

    -- increment stuff
    currentLabel = (currentLabel % #VEC_LABELS) + 1
    currentColor = (currentColor % #VEC_COLORS) + 1

    return setmetatable(newObj, self)
end

function MBVec:newPoint(value)
    return MBVec:new(value, MBVec.pointPosFunc)
end

function vstring(v)
    return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
end

function MBVec:update(vectorList)
    local value, expr = self:valueFunc(vectorList)
    local pos = self:posFunc(vectorList)

    -- handle evaluation errors and their updates here?

    self.computedValue:set(value)
    self.computedPos:set(pos)
    self.computedExpr = expr or 'NO EXPRESSION RETURNED'

    return value, pos
end

function MBVec:freeValueFunc()
    return vec3(self.freeValue), self.label
end

function MBVec:freePosFunc()
    return vec3(self.freePos), false, 'freepos?'
end

function MBVec:pointPosFunc()
    return vec3(0, 0, 0), true, 'pointpos?'
end

function MBVec:makeFreeValue()
    self.freeValue = self.computedValue
    self.valueFunc = self.freeValueFunc
end

function MBVec:makeFreePos()
    self.freePos = self.computedPos
    self.posFunc = self.freePosFunc
end

function MBVec:isFreeValue()
    return self.valueFunc == self.freeValueFunc
end

function MBVec:isFreePos()
    return self.posFunc == self.freePosFunc
end

function MBVec:isPoint()
    return self.posFunc == self.pointPosFunc
end

return MBVec
