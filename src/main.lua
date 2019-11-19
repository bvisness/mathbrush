local inspect = require('inspect')
local CrossGizmo = require('gizmos/crossgizmo')
local MBExpression = require('data/mbexpression')
local MBObjectList = require('data/mbobjectlist')
local MBRegionInfo = require('data/mbregioninfo')
local MBSphereRegion = require('data/mbsphereregion')
local MBVec = require('data/mbvec')

local REGION_VEC_SELECT = 'REGION_VEC_SELECT'
local REGION_VEC_VALUE = 'REGION_VEC_VALUE'
local REGION_VEC_POS = 'REGION_VEC_POS'
local REGION_VEC_SNAP_TIP = 'REGION_VEC_SNAP_TIP'
local REGION_VEC_SNAP_TAIL = 'REGION_VEC_SNAP_TAIL'

local REGION_2VEC_ADD_CROSS = 'REGION_2VEC_ADD_CROSS'

local VALUE_HANDLE_DISTANCE = 0.10

all_trackable_devices = {
    ['hand/left'] = {
        model = lovr.headset.newModel('hand/left'),
    },
    ['hand/right'] = {
        model = lovr.headset.newModel('hand/right'),
    }
}

vectors = MBObjectList:new()

function lovr.load()
    lovr.graphics.setBackgroundColor(0x333344)
end

regions = {}
lastTrigger = false
activeAction = nil
selectedVecs = {}
gizmos = {}
function lovr.update()
    gizmos = {}

    local handPos = vec3(lovr.headset.getPosition('hand/right'))
    local trigger = lovr.headset.isDown('hand/right', 'trigger')

    if trigger and not lastTrigger then
        assert(activeAction == nil)

        -- See if you are clicking on a region
        local selectedRegion, minDist = nil, -1
        for _, region in ipairs(regions) do
            inside, dist = region:checkPoint(handPos)
            if inside then
                if not selectedRegion or dist < minDist then
                    selectedRegion = region
                    minDist = dist
                end
            end
        end

        if selectedRegion then
            local t = selectedRegion.info.t
            if t == REGION_VEC_SELECT then
                local vecId = selectedRegion.info.data.vecId
                if not contains(selectedVecs, vecId) then
                    table.insert(selectedVecs, vecId)
                end
                activeAction = function() end
            elseif t == REGION_VEC_VALUE then
                local vecId = selectedRegion.info.data.vecId
                activeAction = function(handPos)
                    local pos = vectors:get(vecId).posExpr:evaluate().value
                    -- TODO: Handle error, I guess

                    local toHand = vec3(handPos) - vec3(pos) -- paranoia!
                    local handDistance = toHand:length()
                    local finalLength = handDistance + VALUE_HANDLE_DISTANCE
                    vectors:get(vecId).valueExpr:set(toHand * (finalLength / handDistance))
                end
            elseif t == REGION_VEC_POS then
                local vecId = selectedRegion.info.data.vecId
                local vecStartPos = lovr.math.newVec3(vectors:get(vecId).computedPos)
                local handStartPos = lovr.math.newVec3(handPos)
                activeAction = function(handPos)
                    -- TODO: Add ability to snap to other vectors
                    vectors:get(vecId).posExpr:set(vecStartPos + (handPos - handStartPos))
                end
            elseif t == REGION_2VEC_ADD_CROSS then
                local vec1Id = selectedRegion.info.data.vec1Id
                local vec2Id = selectedRegion.info.data.vec2Id

                vectors:add(MBVec:new(
                    multiVecReferenceExpression({vec1Id, vec2Id}, function(vecs)
                        return MBExpression.CrossVecs:new(
                            vecs[vec1Id].valueExpr,
                            vecs[vec2Id].valueExpr
                        )
                    end),
                    vecReferenceExpression(vec1Id, function(v)
                        return v.posExpr
                    end)
                ))

                activeAction = function() end

                selectedVecs = {}
            end
        end

        if not activeAction then
            -- None of the regions we clicked above triggered their own action.
            -- Make a new vector.

            local handStartPos = lovr.math.newVec3(handPos)

            local posExpr = MBExpression.FreeVector:new(handStartPos)
            if selectedRegion then
                local t = selectedRegion.info.t
                if t == REGION_VEC_SNAP_TAIL then
                    local parent = vectors:get(selectedRegion.info.data.vecId)
                    posExpr = parent.posExpr
                elseif t == REGION_VEC_SNAP_TIP then
                    posExpr = vecReferenceExpression(selectedRegion.info.data.vecId, function(v)
                        return MBExpression.AddVecs:new(v.posExpr, v.valueExpr)
                    end)
                end
            end

            local didAddVec = false
            local newVecId = -1

            activeAction = function(handPos)
                if not didAddVec and (handPos - handStartPos):length() > 0.02 then
                    didAddVec = true

                    newVecId = vectors:add(MBVec:new(
                        MBExpression.FreeVector:new(vec3(0, 0, 0)),
                        posExpr
                    ))
                elseif didAddVec then
                    assert(newVecId ~= -1)
                    vectors:get(newVecId).valueExpr:set(handPos - handStartPos)
                end
            end

            selectedVecs = {}
        end
    elseif not trigger and lastTrigger then
        activeAction = nil
    end

    if activeAction then
        activeAction(handPos)
    end

    regions = {}
    for id, vec in pairs(vectors.objs) do
        vec:update()
        table.insert(regions, MBSphereRegion:new(
            vec.computedPos + vec.computedValue / 2,
            0.07,
            MBRegionInfo:new(REGION_VEC_SELECT, {
                vecId = id,
            })
        ))
        if instanceof(vec.valueExpr, MBExpression.FreeVector) then
            table.insert(regions, MBSphereRegion:new(
                valueHandlePos(vec.computedValue, vec.computedPos),
                0.07,
                MBRegionInfo:new(REGION_VEC_VALUE, {
                    vecId = id,
                })
            ))
        end
        if instanceof(vec.posExpr, MBExpression.FreeVector) then
            table.insert(regions, MBSphereRegion:new(
                posHandlePos(vec.computedValue, vec.computedPos),
                0.07,
                MBRegionInfo:new(REGION_VEC_POS, {
                    vecId = id,
                })
            ))
        end
        table.insert(regions, MBSphereRegion:new(
            vec.computedPos,
            0.07,
            MBRegionInfo:new(REGION_VEC_SNAP_TAIL, {
                vecId = id,
            })
        ))
        table.insert(regions, MBSphereRegion:new(
            vec.computedPos + vec.computedValue,
            0.07,
            MBRegionInfo:new(REGION_VEC_SNAP_TIP, {
                vecId = id,
            })
        ))
    end

    if #selectedVecs == 2 then
        -- Check for cross product
        local v1 = vectors:get(selectedVecs[1])
        local v2 = vectors:get(selectedVecs[2])
        if (v2.computedPos - v1.computedPos):length() < 0.02 then
            local pos = v1.computedPos + vec3(v1.computedValue):cross(v2.computedValue):normalize() * 0.15
            table.insert(gizmos, CrossGizmo:new(pos, quat(vec3(v1.computedValue):normalize())))
            table.insert(regions, MBSphereRegion:new(
                pos,
                0.07,
                MBRegionInfo:new(REGION_2VEC_ADD_CROSS, {
                    vec1Id = selectedVecs[1],
                    vec2Id = selectedVecs[2],
                })
            ))
        end
    end

    lastTrigger = trigger
end

vecMaterial = lovr.graphics.newMaterial(0xdddddd)
selectedVecMaterial = lovr.graphics.newMaterial(0xffeeaa)
regionMaterial = lovr.graphics.newMaterial(0xaaaadd)
function lovr.draw()
    for i, hand in pairs(lovr.headset.getHands()) do
        all_trackable_devices[hand].model:draw(pose2mat4(lovr.headset.getPose(hand)))
    end

    for id, vec in pairs(vectors.objs) do
        local TIP_LENGTH = 0.07

        local value = vec.computedValue
        local pos = vec.computedPos
        local length = math.max(0.01, value:length() - 0.05)

        local rot = quat(vec3(value):normalize())

        vecMaterial:setColor(vec.color)
        local mat = contains(selectedVecs, id) and selectedVecMaterial or vecMaterial

        lovr.graphics.cylinder(mat, pos + vec3(value):normalize() * length / 2, length, rot, 0.01, 0.01)
        lovr.graphics.cylinder(
            mat,
            pos + value - vec3(value):normalize() * TIP_LENGTH / 2,
            TIP_LENGTH, rot, 0, 0.03
        )
    end

    -- for _, region in pairs(regions) do
    --     lovr.graphics.sphere(regionMaterial, region.center, region.radius)
    -- end

    for _, gizmo in ipairs(gizmos) do
        gizmo:draw()
    end
end

function pose2mat4(x, y, z, angle, ax, ay, az)
    local pos = vec3(x, y, z)
    local rot = quat(angle, ax, ay, az)
    local scale = vec3(1, 1, 1)

    return mat4(pos, scale, rot)
end

function valueHandlePos(vecValue, vecPos)
    return vecPos + vecValue - (vec3(vecValue):normalize() * VALUE_HANDLE_DISTANCE)
end

function posHandlePos(vecValue, vecPos)
    return vecPos + (vec3(vecValue):normalize() * 0.05)
end

function vecReferenceExpression(vecId, getExpression)
    return {
        evaluate = function()
            local vec = vectors:get(vecId)
            if not vec then
                return MBExpressionResult:new("referenced missing vector " .. vecId, MBExpressionResult.TYPE_ERROR)
            else
                return getExpression(vec):evaluate()
            end
        end,
    }
end

function multiVecReferenceExpression(vecIds, getExpression)
    return {
        evaluate = function()
            local vecs = {}
            for _, vecId in ipairs(vecIds) do
                local vec = vectors:get(vecId)
                if not vec then
                    return MBExpressionResult:new("referenced missing vector " .. vecId, MBExpressionResult.TYPE_ERROR)
                else
                    vecs[vecId] = vec
                end
            end

            return getExpression(vecs):evaluate()
        end
    }
end

function contains(t, v)
    for _, tv in ipairs(t) do
        if v == tv then
            return true
        end
    end

    return false
end

function instanceof (subject, super)
    super = tostring(super)
    local mt = getmetatable(subject)

    while true do
        if mt == nil then return false end
        if tostring(mt) == super then return true end

        mt = getmetatable(mt)
    end
end
