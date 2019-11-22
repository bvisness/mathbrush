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
    local freeValue = nil

    if type(value) ~= 'function' then
        freeValue = value
    end

    self.__index = self
    local newObj = {
        valueFunc = freeValue and self.freeValueFunc or value,

        computedValue = lovr.math.newVec3(0, 0, 0),
        computedPos = lovr.math.newVec3(0, 0, 0),
        computedExpr = '(not computed)',

        freeValue = lovr.math.newVec3(freeValue or vec3(0, 0, 0)),
        freePos = lovr.math.newVec3(type(pos) ~= 'number' and pos or vec3(0, 0, 0)),
        parentId = type(pos) == 'number' and pos or nil,

        label = VEC_LABELS:sub(currentLabel, currentLabel),
        color = VEC_COLORS[currentColor],
        isPoint = isPoint or false,
    }

    -- increment stuff
    currentLabel = (currentLabel % #VEC_LABELS) + 1
    currentColor = (currentColor % #VEC_COLORS) + 1

    return setmetatable(newObj, self)
end

function MBVec:newPoint(value)
    return MBVec:new(value, vec3(0, 0, 0), true)
end

function vstring(v)
    return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
end

function MBVec:update(vectorList)
    local value, expr = self:valueFunc(vectorList)
    local pos = self:getPos(vectorList)

    -- handle evaluation errors and their updates here?

    self.computedValue:set(value)
    self.computedPos:set(pos)
    self.computedExpr = expr or 'NO EXPRESSION RETURNED'

    return value, pos
end

function MBVec:freeValueFunc()
    return vec3(self.freeValue), self.label
end

function MBVec:makeFreeValue()
    self.freeValue = self.computedValue
    self.valueFunc = self.freeValueFunc
end

function MBVec:isFreeValue()
    return self.valueFunc == self.freeValueFunc
end

function MBVec:getPos(vecs)
    if self.parentId then
        local parent = vecs:get(self.parentId)
        return parent:getPos(vecs) + parent:valueFunc(vecs)
    else
        return self.freePos
    end
end

function MBVec:getPosArgument()
    if self.parentId then
        return self.parentId
    else
        return self.freePos
    end
end

return MBVec
