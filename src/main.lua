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
                activeAction = actionVecValue(vecId, vecStartValue, handStartPos)
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
                    function(self, vecs, visited)
                        visited = visited or {}
                        if visited[vec1Id] or visited[vec2Id] then
                            print(
                                "Cycle detected in cross product value: "
                                .. (visited[vec1Id] and "already visited vector " .. vec1Id .. ", ")
                                .. (visited[vec2Id] and "already visited vector " .. vec2Id)
                            )
                            return self.computedValue
                        end

                        -- TODO: Check for errors and wrong result types
                        local v1value = vecs:get(vec1Id):valueFunc(vecs, visit(visited, vec1Id))
                        local v2value = vecs:get(vec2Id):valueFunc(vecs, visit(visited, vec2Id))
                        return vec3(v1value):cross(v2value)
                    end,
                    function(self, vecs, visited)
                        visited = visited or {}
                        if visited[vec1Id] then
                            print("Cycle detected in cross product pos: already visited vector " .. vec1Id)
                            return self.computedPos
                        end

                        -- TODO: Check for errors
                        return vecs:get(vec1Id):posFunc(vecs, visit(visited, vec1Id))
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
                local vecValueAction = nil

                activeAction = function(handPos)
                    if not didAddVec and (handPos - handStartPos):length() > 0.02 then
                        newVecId = vectors:add(MBVec:new(
                            handPos - handStartPos,
                            posFunc or handStartPos
                        ))

                        didAddVec = true
                        vecValueAction = actionVecValue(newVecId, lovr.math.newVec3(0, 0, 0), handStartPos)
                    elseif didAddVec then
                        assert(newVecId ~= -1)
                        vecValueAction(handPos)
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

            local toHeadset = vec3(lovr.headset.getPosition()) - value;
            local viewRight = vec3(0, 1, 0):cross(toHeadset):normalize()
            local viewUp = vec3(toHeadset):cross(viewRight):normalize()
            local labelOffset = (viewRight * -0.07) + (viewUp * -0.07)
            local labelPos = value + labelOffset;
            lovr.graphics.print(
                vec.label,
                labelPos,
                0.1,
                quat(mat4():lookAt(vec3(lovr.headset.getPosition()), labelPos))
            )
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

            local halfway = pos + (value / 2)
            local labelOffset = vec3(value):cross(vec3(lovr.headset.getPosition()) - halfway):normalize() * 0.07
            local labelPos = halfway + labelOffset;
            lovr.graphics.print(
                vec.label,
                labelPos,
                0.1,
                quat(mat4():lookAt(vec3(lovr.headset.getPosition()), labelPos))
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
        if #snapRegions > 0 then
            local otherId = snapRegions[1].info.data.vecId

            if vecId ~= otherId then
                local pos, absolute = v:posFunc(vectors)
                local otherPos, otherAbsolute = vectors:get(otherId):posFunc(vectors)

                if absolute and otherAbsolute then
                    v.valueFunc = function(self, vecs, visited)
                        local visited = visited or {}

                        local pos, absolute = self:posFunc(vecs, visited)

                        if visited[otherId] then
                            print("Cycle detected in subtraction value func: already visited vector " .. otherId)
                            return self.computedValue
                        end
                        local newVisited = visit(visited, otherId)

                        local other = vecs:get(otherId)
                        local otherPos, otherAbsolute = other:posFunc(vecs, newVisited)

                        return (otherPos + other:valueFunc(vecs, newVisited)) - pos;
                    end
                    didSnap = true
                end
            end
        end

        if not didSnap then
            v:makeFreeValue()
            v.freeValue:set(vecStartValue + (handPos - handStartPos))
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

function visit(t, id)
    local result = {}
    for k, v in pairs(t) do
        result[v] = v
    end
    t[id] = true

    return result
end

function posFuncSnapToTip(vecId)
    return function(self, vecs, visited)
        local visited = visited or {}

        if visited[vecId] then
            print("Cycle detected in posFuncSnapToTip: already visited vector " .. vecId)
            return self.computedPos
        end

        local newVisited = visit(visited or {}, vecId)

        local v = vecs:get(vecId)
        local val = v:valueFunc(vecs, newVisited)
        local pos, absolute = v:posFunc(vecs, newVisited)
        return pos + val, absolute
    end
end
