local inspect = require('inspect')
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
function lovr.update()
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
                table.insert(selectedVecs, vecId)
                activeAction = function() end
            elseif t == REGION_VEC_VALUE then
                local vecId = selectedRegion.info.data.vecId
                activeAction = function(handPos)
                    local pos = vectors:get(vecId).posExpr:evaluate().value
                    -- TODO: Handle error, I guess
                    vectors:get(vecId).valueExpr:set(handPos - pos)
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
                        print(inspect(vecs))
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

            local newVecId = vectors:add(MBVec:new(
                MBExpression.FreeVector:new(vec3(0, 0, 0)),
                posExpr
            ))
            activeAction = function(handPos)
                vectors:get(newVecId).valueExpr:set(handPos - handStartPos)
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
            0.03,
            MBRegionInfo:new(REGION_VEC_SELECT, {
                vecId = id,
            })
        ))
        table.insert(regions, MBSphereRegion:new(
            valueHandlePos(vec.computedValue, vec.computedPos),
            0.03,
            MBRegionInfo:new(REGION_VEC_VALUE, {
                vecId = id,
            })
        ))
        table.insert(regions, MBSphereRegion:new(
            posHandlePos(vec.computedValue, vec.computedPos),
            0.03,
            MBRegionInfo:new(REGION_VEC_POS, {
                vecId = id,
            })
        ))
        table.insert(regions, MBSphereRegion:new(
            vec.computedPos,
            0.04,
            MBRegionInfo:new(REGION_VEC_SNAP_TAIL, {
                vecId = id,
            })
        ))
        table.insert(regions, MBSphereRegion:new(
            vec.computedPos + vec.computedValue,
            0.04,
            MBRegionInfo:new(REGION_VEC_SNAP_TIP, {
                vecId = id,
            })
        ))
    end

    if #selectedVecs == 2 then
        -- Check for cross product
        v1 = vectors:get(selectedVecs[1])
        v2 = vectors:get(selectedVecs[2])
        if (v2.computedPos - v1.computedPos):length() < 0.02 then
            table.insert(regions, MBSphereRegion:new(
                v1.computedPos + vec3(v1.computedValue):cross(v2.computedValue):normalize() * 0.15,
                0.03,
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
        local value = vec.computedValue
        local pos = vec.computedPos
        local length = math.max(0.01, value:length())

        local rot = quat(vec3(value):normalize())

        local mat = contains(selectedVecs, id) and selectedVecMaterial or vecMaterial

        lovr.graphics.cylinder(mat, pos + value / 2, length, rot, 0.01, 0.01)
    end

    for _, region in pairs(regions) do
        -- local c = lovr.graphics.getColor()
        -- lovr.graphics.setColor(0xff0000)

        lovr.graphics.sphere(regionMaterial, region.center, region.radius)

        -- lovr.graphics.setColor(c)
    end
end

function pose2mat4(x, y, z, angle, ax, ay, az)
    local pos = vec3(x, y, z)
    local rot = quat(angle, ax, ay, az)
    local scale = vec3(1, 1, 1)

    return mat4(pos, scale, rot)
end

function valueHandlePos(vecValue, vecPos)
    return vecPos + vecValue - (vec3(vecValue):normalize() * 0.10)
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
