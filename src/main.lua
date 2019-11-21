local inspect = require('inspect')
local CrossGizmo = require('gizmos/crossgizmo')
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
selectedVecs = {}
activeAction = nil
activeVecs = {}
gizmos = {}
function lovr.update()
    gizmos = {}

    local handPos = vec3(lovr.headset.getPosition('hand/right'))
    local trigger = lovr.headset.isDown('hand/right', 'trigger')

    if trigger and not lastTrigger then
        assert(activeAction == nil)

        -- See if you are clicking on a region
        local selectedRegion = getRegionsContainingPoint(regions, handPos)[1]

        if selectedRegion then
            local t = selectedRegion.info.type
            if t == REGION_VEC_SELECT then
                local vecId = selectedRegion.info.data.vecId
                if not contains(selectedVecs, vecId) then
                    table.insert(selectedVecs, vecId)
                end
                activeAction = function() end
            elseif t == REGION_VEC_VALUE then
                local vecId = selectedRegion.info.data.vecId
                local vecStartValue = lovr.math.newVec3(vectors:get(vecId).computedValue)
                local handStartPos = lovr.math.newVec3(handPos)
                activeAction = function(handPos)
                    local v = vectors:get(vecId)
                    v:makeFreeValue()
                    v.freeValue:set(vecStartValue + (handPos - handStartPos))
                end
            elseif t == REGION_VEC_POS then
                local vecId = selectedRegion.info.data.vecId
                local vecStartPos = lovr.math.newVec3(vectors:get(vecId).computedPos)
                local handStartPos = lovr.math.newVec3(handPos)
                activeAction = function(handPos)
                    local newPos = vecStartPos + (handPos - handStartPos)
                    local snapRegions = groupBy(getRegionsContainingPoint(regions, newPos), function(v) return v.info.type end)

                    local tips = snapRegions[REGION_VEC_SNAP_TIP]
                    local tails = snapRegions[REGION_VEC_SNAP_TAIL]

                    local v = vectors:get(vecId)
                    if tips then
                        v.posFunc = posFuncSnapToTip(tips[1].info.data.vecId)
                    else
                        v:makeFreePos()
                        v.freePos:set(
                            (tips and tips[1].center)
                            or (tails and tails[1].center)
                            or newPos
                        )
                    end
                end
                activeVecs = {vecId}
            elseif t == REGION_2VEC_ADD_CROSS then
                local vec1Id = selectedRegion.info.data.vec1Id
                local vec2Id = selectedRegion.info.data.vec2Id

                vectors:add(MBVec:new(
                    function(_, vecs)
                        -- TODO: Check for errors and wrong result types
                        local v1value = vecs:get(vec1Id):valueFunc(vecs)
                        local v2value = vecs:get(vec2Id):valueFunc(vecs)
                        return vec3(v1value):cross(v2value)
                    end,
                    function(_, vecs)
                        -- TODO: Check for errors
                        return vecs:get(vec1Id):posFunc(vecs)
                    end
                ))

                activeAction = function() end

                selectedVecs = {}
            end
        end

        if not activeAction then
            -- None of the regions we clicked above triggered their own action.
            -- Make a new vector.

            if lovr.headset.isDown('hand/right', 'menu') then
                vectors:add(MBVec:newPoint(handPos))
            else
                local handStartPos = lovr.math.newVec3(handPos)
                local posFunc = nil

                if selectedRegion then
                    local t = selectedRegion.info.type
                    if t == REGION_VEC_SNAP_TAIL then
                        local other = vectors:get(selectedRegion.info.data.vecId)
                        if other:isFreePos() then
                            posFunc = other.freePos
                        else
                            posFunc = other.posFunc
                        end
                    elseif t == REGION_VEC_SNAP_TIP then
                        local vecId = selectedRegion.info.data.vecId
                        posFunc = posFuncSnapToTip(vecId)
                    end
                end

                local didAddVec = false
                local newVecId = -1

                activeAction = function(handPos)
                    if not didAddVec and (handPos - handStartPos):length() > 0.02 then
                        didAddVec = true

                        newVecId = vectors:add(MBVec:new(
                            handPos - handStartPos,
                            posFunc or handStartPos
                        ))
                    elseif didAddVec then
                        assert(newVecId ~= -1)
                        vectors:get(newVecId).freeValue:set(handPos - handStartPos)
                    end
                end
            end

            selectedVecs = {}
        end
    elseif not trigger and lastTrigger then
        activeAction = nil
        activeVecs = {}
    end

    if activeAction then
        activeAction(handPos)
    end

    regions = {}
    for id, vec in pairs(vectors.objs) do
        vec:update(vectors)

        if vec:isPoint() then
            table.insert(regions, MBSphereRegion:new(
                vec.computedValue,
                0.07,
                MBRegionInfo:new(REGION_VEC_VALUE, {
                    vecId = id,
                })
            ))
            table.insert(regions, MBSphereRegion:new(
                vec.computedValue,
                0.07,
                MBRegionInfo:new(REGION_VEC_SNAP_TIP, {
                    vecId = id,
                })
            ))
        else
            table.insert(regions, MBSphereRegion:new(
                vec.computedPos + vec.computedValue / 2,
                0.07,
                MBRegionInfo:new(REGION_VEC_SELECT, {
                    vecId = id,
                })
            ))
            table.insert(regions, MBSphereRegion:new(
                valueHandlePos(vec.computedValue, vec.computedPos),
                0.07,
                MBRegionInfo:new(REGION_VEC_VALUE, {
                    vecId = id,
                })
            ))
            table.insert(regions, MBSphereRegion:new(
                posHandlePos(vec.computedValue, vec.computedPos),
                0.07,
                MBRegionInfo:new(REGION_VEC_POS, {
                    vecId = id,
                })
            ))
            if not contains(activeVecs, id) then
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
        end
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
        local value = vec.computedValue
        local pos = vec.computedPos

        vecMaterial:setColor(vec.color)
        local mat = contains(selectedVecs, id) and selectedVecMaterial or vecMaterial

        if vec:isPoint() then
            lovr.graphics.sphere(mat, pos + value, 0.02)
        else
            local TIP_LENGTH = 0.07

            local length = math.max(0.01, value:length() - 0.05)
            local rot = quat(vec3(value):normalize())

            lovr.graphics.cylinder(mat, pos + vec3(value):normalize() * length / 2, length, rot, 0.01, 0.01)
            lovr.graphics.cylinder(
                mat,
                pos + value - vec3(value):normalize() * TIP_LENGTH / 2,
                TIP_LENGTH, rot, 0, 0.03
            )
        end
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
    return vecPos + vecValue - (vec3(vecValue):normalize() * 0.10)
end

function posHandlePos(vecValue, vecPos)
    return vecPos + (vec3(vecValue):normalize() * 0.05)
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

-- Gets all regions containing p, sorted by distance, closest to furthest.
function getRegionsContainingPoint(regions, p)
    local containingRegions = {}

    for _, region in ipairs(regions) do
        inside, dist = region:checkPoint(p)
        if inside then
            table.insert(containingRegions, {
                region = region,
                dist = dist,
            })
        end
    end

    table.sort(containingRegions, function(a, b) return a.dist < b.dist end)

    local result = {}
    for i, v in ipairs(containingRegions) do
        result[i] = v.region
    end

    return result
end

function filter(t, f)
    local result = {}
    for _, v in ipairs(t) do
        if f(v) then
            table.insert(result, v)
        end
    end
    return result
end

function groupBy(t, f)
    local result = {}
    for _, v in ipairs(t) do
        local key = f(v)
        if not result[key] then
            result[key] = {}
        end
        table.insert(result[key], v)
    end
    return result
end

function map(t, f)
    local result = {}
    for i, v in ipairs(t) do
        result[i] = f(v)
    end
    return result
end

function posFuncSnapToTip(vecId)
    return function(_, vecs)
        local v = vecs:get(vecId)
        local val = v:valueFunc(vecs)
        local pos, absolute = v:posFunc(vecs)
        return pos + val, absolute
    end
end
