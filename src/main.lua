local inspect = require('inspect')
local CrossGizmo = require('gizmos/crossgizmo')
local MBObjectList = require('data/mbobjectlist')
local MBRegionInfo = require('data/mbregioninfo')
local MBSphereRegion = require('data/mbsphereregion')
local MBVec = require('data/mbvec')
local NormalizeGizmo = require('gizmos/normalizegizmo')
local ProjectOntoPlaneGizmo = require('gizmos/projectplanegizmo')
local TogglePlaneGizmo = require('gizmos/planegizmo')
local valueFunctions = require('values')
local vmath = require('vmath')

local REGION_VEC_SELECT = 'REGION_VEC_SELECT'
local REGION_VEC_VALUE = 'REGION_VEC_VALUE'
local REGION_VEC_POS = 'REGION_VEC_POS'
local REGION_VEC_SNAP_TIP = 'REGION_VEC_SNAP_TIP'
local REGION_VEC_SNAP_TAIL = 'REGION_VEC_SNAP_TAIL'

local REGION_VEC_MAKE_NORMALIZED = 'REGION_VEC_MAKE_NORMALIZED'
local REGION_VEC_TOGGLE_PLANE = 'REGION_VEC_TOGGLE_PLANE'
local REGION_2VEC_ADD_CROSS = 'REGION_2VEC_ADD_CROSS'
local REGION_2VEC_PROJECT_PLANE = 'REGION_2VEC_PROJECT_PLANE'

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
sceneScale = 0.4
scenePos = lovr.math.newVec3(0, 0, 0)
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
                activeAction = actionVecValue(vecId, vecStartValue, handStartPos)
            elseif t == REGION_VEC_POS then
                local vecId = selectedRegion.info.data.vecId
                local vecStartPos = lovr.math.newVec3(vectors:get(vecId).computedPos)
                local handStartPos = lovr.math.newVec3(handPos)
                activeAction = actionVecPos(vecId, vecStartPos, handStartPos)
                activeVecs = {vecId}
            elseif t == REGION_VEC_MAKE_NORMALIZED then
                local v = vectors:get(selectedRegion.info.data.vecId)
                v.valueFunc = valueFunctions.normalize(v.valueFunc)
                selectedVecs = {}
            elseif t == REGION_VEC_TOGGLE_PLANE then
                local v = vectors:get(selectedRegion.info.data.vecId)
                v.showPlane = not v.showPlane
            elseif t == REGION_2VEC_ADD_CROSS then
                local vec1Id = selectedRegion.info.data.vec1Id
                local vec2Id = selectedRegion.info.data.vec2Id

                vectors:add(MBVec:new(
                    valueFunctions.cross(vec1Id, vec2Id),
                    vectors:get(vec1Id):getPosArgument()
                ))

                selectedVecs = {}
            elseif t == REGION_2VEC_PROJECT_PLANE then
                local vec1Id = selectedRegion.info.data.vec1Id
                local vec2Id = selectedRegion.info.data.vec2Id

                vectors:add(MBVec:new(
                    valueFunctions.projectPlane(vec1Id, vec2Id),
                    vectors:get(vec1Id):getPosArgument()
                ))

                selectedVecs = {}
            end
        end

        if not activeAction then
            -- None of the regions we clicked above triggered their own action.
            -- Make a new vector.

            if lovr.headset.isDown('hand/right', 'menu') then
                vectors:add(MBVec:newPoint(posWorldToScene(handPos)))
            else
                local handStartPos = lovr.math.newVec3(handPos)
                local newVecPos = lovr.math.newVec3(posWorldToScene(handStartPos))

                if selectedRegion then
                    local t = selectedRegion.info.type
                    if t == REGION_VEC_SNAP_TAIL then
                        local other = vectors:get(selectedRegion.info.data.vecId)
                        if other.parentId then
                            newVecPos = other.parentId -- TODO: Someday could we just add a notion of "region priority" and give priority to tips?
                        else
                            newVecPos = other.freePos
                        end
                    elseif t == REGION_VEC_SNAP_TIP then
                        newVecPos = selectedRegion.info.data.vecId
                    end
                end

                activeAction = actionNewVector(handStartPos, newVecPos)
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

        if vec.isPoint then
            table.insert(regions, MBSphereRegion:new(
                posSceneToWorld(vec.computedValue),
                0.07,
                MBRegionInfo:new(REGION_VEC_VALUE, {
                    vecId = id,
                })
            ))
            table.insert(regions, MBSphereRegion:new(
                posSceneToWorld(vec.computedValue),
                0.07,
                MBRegionInfo:new(REGION_VEC_SNAP_TIP, {
                    vecId = id,
                })
            ))
        else
            table.insert(regions, MBSphereRegion:new(
                posSceneToWorld(vec.computedPos + vec.computedValue / 2),
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
                    posSceneToWorld(vec.computedPos),
                    0.07,
                    MBRegionInfo:new(REGION_VEC_SNAP_TAIL, {
                        vecId = id,
                    })
                ))
                table.insert(regions, MBSphereRegion:new(
                    posSceneToWorld(vec.computedPos + vec.computedValue),
                    0.07,
                    MBRegionInfo:new(REGION_VEC_SNAP_TIP, {
                        vecId = id,
                    })
                ))
            end
        end
    end

    if #selectedVecs == 1 then
        local v = vectors:get(selectedVecs[1])

        local valueWorld = valueSceneToWorld(v.computedValue)
        local posWorld = posSceneToWorld(v.computedPos)

        -- Show normalize gizmo
        local halfway = posWorld + (valueWorld / 2)
        local gizmoOffset = vec3(valueWorld):cross(vec3(lovr.headset.getPosition()) - halfway):normalize() * -0.07
        local normalizeGizmoPos = halfway + gizmoOffset;
        table.insert(gizmos, NormalizeGizmo:new(normalizeGizmoPos))
        table.insert(regions, MBSphereRegion:new(
            normalizeGizmoPos,
            0.07,
            MBRegionInfo:new(REGION_VEC_MAKE_NORMALIZED, {
                vecId = selectedVecs[1],
            })
        ))

        -- Show plane gizmo
        local planeGizmoPos = posWorld + (valueWorld * 0.2) + gizmoOffset
        table.insert(gizmos, TogglePlaneGizmo:new(planeGizmoPos, v.showPlane))
        table.insert(regions, MBSphereRegion:new(
            planeGizmoPos,
            0.07,
            MBRegionInfo:new(REGION_VEC_TOGGLE_PLANE, {
                vecId = selectedVecs[1],
            })
        ))
    elseif #selectedVecs == 2 then
        -- Check for cross product and stuff
        local v1 = vectors:get(selectedVecs[1])
        local v2 = vectors:get(selectedVecs[2])
        if nearEqual(v2.computedPos, v1.computedPos) then
            local v1PosWorld = posSceneToWorld(v1.computedPos)
            local v1ValueWorld = valueSceneToWorld(v1.computedValue)
            local v2ValueWorld = valueSceneToWorld(v2.computedValue)

            local pos = v1PosWorld + vec3(v1ValueWorld):cross(v2ValueWorld):normalize() * 0.15
            table.insert(gizmos, CrossGizmo:new(pos, quat(vec3(v1ValueWorld):normalize())))
            table.insert(regions, MBSphereRegion:new(
                pos,
                0.07,
                MBRegionInfo:new(REGION_2VEC_ADD_CROSS, {
                    vec1Id = selectedVecs[1],
                    vec2Id = selectedVecs[2],
                })
            ))

            if v2.showPlane then
                local projectGizmoPos = v1PosWorld + ((v1ValueWorld + vmath.projectOntoPlane(v1ValueWorld, v2ValueWorld)) / 2)
                table.insert(gizmos, ProjectOntoPlaneGizmo:new(projectGizmoPos))
                table.insert(regions, MBSphereRegion:new(
                    projectGizmoPos,
                    0.07,
                    MBRegionInfo:new(REGION_2VEC_PROJECT_PLANE, {
                        vec1Id = selectedVecs[1],
                        vec2Id = selectedVecs[2],
                    })
                ))
            end
        end
    end

    lastTrigger = trigger
end

vecMaterial = lovr.graphics.newMaterial(0xdddddd)
selectedVecMaterial = lovr.graphics.newMaterial(0xffeeaa)
regionMaterial = lovr.graphics.newMaterial(0xaaaadd)
function lovr.draw()
    for _, hand in pairs(lovr.headset.getHands()) do
        all_trackable_devices[hand].model:draw(pose2mat4(lovr.headset.getPose(hand)))
    end

    for id, vec in pairs(vectors.objs) do
        local valueScene = vec.computedValue
        local posScene = vec.computedPos

        local valueWorld = valueSceneToWorld(valueScene)
        local posWorld = posSceneToWorld(posScene)

        vecMaterial:setColor(vec.color)
        local mat = contains(selectedVecs, id) and selectedVecMaterial or vecMaterial

        if vec.isPoint then
            local worldPos = posWorld + valueWorld
            lovr.graphics.sphere(mat, worldPos, 0.02)

            local toHeadset = vec3(lovr.headset.getPosition()) - valueWorld;
            local viewRight = vec3(0, 1, 0):cross(toHeadset):normalize()
            local viewUp = vec3(toHeadset):cross(viewRight):normalize()
            local labelOffset = (viewRight * -0.07) + (viewUp * -0.07)
            local labelPos = worldPos + labelOffset;
            printLabel(vec.computedExpr, labelPos)
        else
            local TIP_LENGTH = 0.07

            local length = math.max(0.01, valueWorld:length() - 0.05)
            local rot = quat(vec3(valueWorld):normalize())

            lovr.graphics.cylinder(mat, posWorld + vec3(valueWorld):normalize() * length / 2, length, rot, 0.01, 0.01)
            lovr.graphics.cylinder(
                mat,
                posWorld + valueWorld - vec3(valueWorld):normalize() * TIP_LENGTH / 2,
                TIP_LENGTH, rot, 0, 0.03
            )

            if vec.showPlane then
                lovr.graphics.box(mat, posWorld, 0.5, 0.5, 0.001, rot)
            end

            local halfway = posWorld + (valueWorld / 2)
            local labelOffset = vec3(valueWorld):cross(vec3(lovr.headset.getPosition()) - halfway):normalize() * 0.07
            local labelPos = halfway + labelOffset;
            printLabel(vec.computedExpr, labelPos)
        end
    end

    -- for _, region in pairs(regions) do
    --     lovr.graphics.sphere(regionMaterial, region.center, region.radius)
    -- end

    for _, gizmo in ipairs(gizmos) do
        gizmo:draw()
    end
end

-- Returns an action function that will create a new vector if the user drags far
-- enough. The vecPos argument will be passed to MBVec:new when the vector is created,
-- so it can take either a position or a parent ID.
function actionNewVector(handStartPosWorld, vecPos)
    local didAddVec = false
    local newVecId = -1
    local vecValueAction = nil

    return function(handPos)
        if not didAddVec and (handPos - handStartPosWorld):length() > 0.02 then
            newVecId = vectors:add(MBVec:new(
                valueWorldToScene(handPos - handStartPosWorld),
                vecPos
            ))

            didAddVec = true
            vecValueAction = actionVecValue(newVecId, lovr.math.newVec3(0, 0, 0), handStartPosWorld)
        elseif didAddVec then
            assert(newVecId ~= -1)
            vecValueAction(handPos)
        end
    end
end

-- Returns an action function that modifies a vector's value. The primary function that handles
-- dragging the tip of a vector around, snapping it to things, etc.
function actionVecValue(vecId, vecStartValue, handStartPos)
    return function(handPos)
        local v = vectors:get(vecId)

        local snapRegions = filter(getRegionsContainingPoint(regions, handPos), function(v)
            return (
                v.info.type == REGION_VEC_SNAP_TIP
                and v.info.data.vecId ~= vecId
            )
        end)

        local didSnap = false
        if #snapRegions > 0 and v.parentId then
            local otherId = snapRegions[1].info.data.vecId

            if vecId ~= otherId then
                local selfChain = getVecAndParents(vectors, vecId)
                local otherChain = getVecAndParents(vectors, otherId)

                local selfRoot = vectors:get(selfChain[#selfChain])
                local otherRoot = vectors:get(otherChain[#otherChain])

                -- Check if they share a root, and if so, work up until they diverge
                if nearEqual(selfRoot.computedPos, otherRoot.computedPos) then
                    local closestRoot = nil
                    for i = 0, math.min(#selfChain, #otherChain) - 1 do
                        if selfChain[#selfChain - i] == otherChain[#otherChain - i] then
                            closestRoot = selfChain[#selfChain - i]
                        else
                            break
                        end
                    end

                    local function addValuesUntil(vecs, startId, stopId)
                        local startVec = vecs:get(startId)
                        local resultExpr = nil
                        local resultVal = vec3(0, 0, 0)

                        local currentVec = startVec
                        while true do
                            local currentVal, expr = currentVec:valueFunc(vecs) -- TODO: visited?
                            resultVal = resultVal + currentVal
                            if not resultExpr then
                                resultExpr = (expr or '?')
                            else
                                resultExpr = (expr or '?') .. ' + ' .. resultExpr
                            end

                            if not currentVec.parentId or currentVec.parentId == stopId then
                                break
                            end

                            currentVec = vecs:get(currentVec.parentId)
                        end

                        return resultVal, '(' .. resultExpr .. ')'
                    end

                    local aId = v.parentId
                    local bId = otherId

                    v.valueFunc = function(self, vecs, visited)
                        visited = visited or {}

                        local aResult, aExpr = addValuesUntil(vecs, aId, closestRoot) -- TODO: Visited?
                        local bResult, bExpr = addValuesUntil(vecs, bId, closestRoot)

                        return bResult - aResult, '(' .. bExpr .. ' - ' .. aExpr .. ')'
                    end
                    didSnap = true
                end
            end
        end

        if not didSnap then
            v:makeFreeValue()
            v.freeValue:set(vecStartValue + valueWorldToScene(handPos - handStartPos))
        end
    end
end

-- Returns an action function that modifies a vector's position. Handles snapping vectors' tails
-- to things - either other vectors' tips or tails.
function actionVecPos(vecId, vecStartPos, handStartPos)
    return function(handPos)
        local newPosWorld = posSceneToWorld(vecStartPos) + (handPos - handStartPos)
        local snapRegions = groupBy(getRegionsContainingPoint(regions, newPosWorld), function(v) return v.info.type end)

        local tips = snapRegions[REGION_VEC_SNAP_TIP]
        local tails = snapRegions[REGION_VEC_SNAP_TAIL]

        local v = vectors:get(vecId)
        if tips then
            v.parentId = tips[1].info.data.vecId
        else
            v.parentId = nil
            v.freePos:set(posWorldToScene(
                (tips and tips[1].center)
                or (tails and tails[1].center)
                or newPosWorld
            ))
        end
    end
end

function pose2mat4(x, y, z, angle, ax, ay, az)
    local pos = vec3(x, y, z)
    local rot = quat(angle, ax, ay, az)
    local scale = vec3(1, 1, 1)

    return mat4(pos, scale, rot)
end

function valueHandlePos(vecValue, vecPos)
    local valueWorld = valueSceneToWorld(vecValue)
    local posWorld = posSceneToWorld(vecPos)
    return posWorld + valueWorld - (vec3(valueWorld):normalize() * 0.10)
end

function posHandlePos(vecValue, vecPos)
    local valueWorld = valueSceneToWorld(vecValue)
    local posWorld = posSceneToWorld(vecPos)
    return posWorld + (vec3(valueWorld):normalize() * 0.05)
end

function contains(t, v)
    for _, tv in ipairs(t) do
        if v == tv then
            return true
        end
    end

    return false
end

function instanceof(subject, super)
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

function getVecAndParents(vecs, startId)
    local result = {}
    local currentId = startId
    while true do
        table.insert(result, currentId)

        local v = vecs:get(currentId)
        if not v.parentId then
            return result
        end

        currentId = v.parentId
    end
end

function nearEqual(vec1, vec2)
    return (vec2 - vec1):length() < 0.02
end

function printLabel(text, pos)
    lovr.graphics.print(
        text,
        pos,
        0.1,
        quat(mat4():lookAt(vec3(lovr.headset.getPosition()), pos)),
        nil,
        'center',
        'middle'
    )
end

function valueSceneToWorld(val)
    return val * sceneScale
end

function posSceneToWorld(pos)
    return pos * sceneScale + scenePos
end

function valueWorldToScene(val)
    return val / sceneScale
end

function posWorldToScene(pos)
    return (pos - scenePos) / sceneScale
end
