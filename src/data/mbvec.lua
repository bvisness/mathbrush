local inspect = require('inspect')

local MBMathResult = require('data/mbmathresult')

MBVec = {}

VEC_COLORS = {
    0xaaaaff,
    0xffaaaa,
    0xaaffaa,
    0xffaaff,
    0xaaffff,
}
currentColor = 1

function MBVec:new(value, pos, parentId, hidden)
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

        freeValue = lovr.math.newVec3(freeValue or vec3(0, 0, 0)),
        freePos = lovr.math.newVec3(freePos or vec3(0, 0, 0)),

        color = VEC_COLORS[currentColor],
        hidden = hidden or false,
    }

    -- increment color
    currentColor = (currentColor % #VEC_COLORS) + 1

    return setmetatable(newObj, self)
end

function vstring(v)
    return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
end

function MBVec:update(vectorList)
    local valueResult = self:valueFunc(vectorList)
    local posResult = self:posFunc(vectorList)

    -- handle evaluation errors and their updates here?

    self.computedValue:set(valueResult.value)
    self.computedPos:set(posResult.value)

    return valueResult.value, posResult.value
end

function MBVec:freeValueFunc()
    return MBMathResult:new(MBMathResult.TYPE_VECTOR, vec3(self.freeValue))
end

function MBVec:freePosFunc()
    return MBMathResult:new(MBMathResult.TYPE_VECTOR, vec3(self.freePos))
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

return MBVec
