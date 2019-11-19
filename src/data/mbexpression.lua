local inspect = require('inspect')

local MBExpressionResult = require('data/mbexpressionresult')

--[[
An expression is really just an "interface" for a few common properties and
methods.
--]]

MBExpression = {}

-----------------------

MBExpression.FreeVector = {}

function MBExpression.FreeVector:new(default)
    local newObj = {
        value = lovr.math.newVec3(default or vec3(1, 1, 1)),
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function MBExpression.FreeVector:evaluate()
    return MBExpressionResult:new(self.value, MBExpressionResult.TYPE_VECTOR)
end

function MBExpression.FreeVector:set(v)
    self.value:set(v)
    return self.value
end

-----------------------

MBExpression.AddVecs = {}

function MBExpression.AddVecs:new(left, right)
    newObj = {left = left, right = right}
    self.__index = self
    return setmetatable(newObj, self)
end

function MBExpression.AddVecs:evaluate()
    leftResult = self.left:evaluate()
    rightResult = self.right:evaluate()

    if
        leftResult.type ~= MBExpressionResult.TYPE_VECTOR
        or rightResult.type ~= MBExpressionResult.TYPE_VECTOR
    then
        return MBExpressionResult:new("Expected two vectors, got " .. leftResult.type .. " and " .. rightResult.type)
    end

    return MBExpressionResult:new(leftResult.value + rightResult.value, MBExpressionResult.TYPE_VECTOR)
end

-----------------------

MBExpression.CrossVecs = {}

function MBExpression.CrossVecs:new(left, right)
    newObj = {left = left, right = right}
    self.__index = self
    return setmetatable(newObj, self)
end

function MBExpression.CrossVecs:evaluate()
    leftResult = self.left:evaluate()
    rightResult = self.right:evaluate()

    if
        leftResult.type ~= MBExpressionResult.TYPE_VECTOR
        or rightResult.type ~= MBExpressionResult.TYPE_VECTOR
    then
        return MBExpressionResult:new("Expected two vectors, got " .. leftResult.type .. " and " .. rightResult.type)
    end

    return MBExpressionResult:new(vec3(leftResult.value):cross(rightResult.value), MBExpressionResult.TYPE_VECTOR)
end

-----------------------

for name, class in pairs(MBExpression) do
    assert(class.evaluate, name .. " has no evaluate method")
end

return MBExpression
