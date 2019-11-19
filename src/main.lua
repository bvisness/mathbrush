local inspect = require('inspect')
local MBExpression = require('data/mbexpression')
local MBObjectList = require('data/mbobjectlist')
local MBRegionInfo = require('data/mbregioninfo')
local MBSphereRegion = require('data/mbsphereregion')
local MBVec = require('data/mbvec')

local REGION_VEC_VALUE = 'mbvec.value'
local REGION_VEC_POS = 'mbvec.pos'

local HANDLE_DISTANCE = 0.05

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
function lovr.update()
    local handPos = vec3(lovr.headset.getPosition('hand/right'))
    local trigger = lovr.headset.isDown('hand/right', 'trigger')

    if trigger and not lastTrigger then
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
            if t == REGION_VEC_VALUE then
                local vecId = selectedRegion.info.data.vecId
                activeAction = function(handPos)
                    local pos = vectors:get(vecId).computedPos
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
            end
        else
            local vecStartPos = lovr.math.newVec3(handPos)
            local newVecId = vectors:add(MBVec:new(
                MBExpression.FreeVector:new(vec3(0, 0, 0)),
                MBExpression.FreeVector:new(vecStartPos)
            ))
            activeAction = function(handPos)
                vectors:get(newVecId).valueExpr:set(handPos - vecStartPos)
            end
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
    end

    lastTrigger = trigger
end

function lovr.draw()
    lovr.graphics.print('hello world', 0, 1.7, -3, .5)

    for i, hand in pairs(lovr.headset.getHands()) do
        all_trackable_devices[hand].model:draw(pose2mat4(lovr.headset.getPose(hand)))
    end

    for id, vec in pairs(vectors.objs) do
        local value = vec.computedValue
        local pos = vec.computedPos
        local length = math.max(0.01, value:length())

        local rot = quat(vec3(value):normalize())

        lovr.graphics.cylinder(pos + value / 2, length, rot, 0.01, 0.01)
    end

    for _, region in pairs(regions) do
        -- local c = lovr.graphics.getColor()
        -- lovr.graphics.setColor(0xff0000)

        lovr.graphics.sphere(region.center, region.radius)

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
    return vecPos + vecValue - (vec3(vecValue):normalize() * HANDLE_DISTANCE)
end

function posHandlePos(vecValue, vecPos)
    return vecPos + (vec3(vecValue):normalize() * HANDLE_DISTANCE)
end
