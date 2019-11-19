local inspect = require('inspect')
local MBExpression = require('data/mbexpression')
local MBObjectList = require('data/mbobjectlist')
local MBVec = require('data/mbvec')

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

lastTrigger = false
activeVec = nil
vecStartPos = nil
function lovr.update()
    handPos = vec3(lovr.headset.getPosition('hand/right'))
    trigger = lovr.headset.isDown('hand/right', 'trigger')

    if trigger and not lastTrigger then
        vecStartPos = lovr.math.newVec3(handPos)
        activeVec = vectors:add(MBVec:new(
            MBExpression.FreeVector:new(vec3(0, 0, 0)),
            MBExpression.FreeVector:new(vecStartPos)
        ))
    elseif not trigger and lastTrigger then
        activeVec = nil
    end

    if activeVec then
        print(handPos - vecStartPos)
        vectors:get(activeVec).value:set(handPos - vecStartPos)
    end

    lastTrigger = trigger
end

function lovr.draw()
    lovr.graphics.print('hello world', 0, 1.7, -3, .5)

    for i, hand in pairs(lovr.headset.getHands()) do
        all_trackable_devices[hand].model:draw(pose2mat4(lovr.headset.getPose(hand)))
    end

    for id, vec in pairs(vectors.objs) do
        local value, pos = vec:compute()
        local length = math.max(0.01, value:length())

        local rot = quat(vec3(value):normalize())
        local angle, ax, ay, az = rot:unpack()

        lovr.graphics.cylinder(pos + value / 2, length, rot, 0.01, 0.01)
    end
end

function pose2mat4(x, y, z, angle, ax, ay, az)
    local pos = vec3(x, y, z)
    local rot = quat(angle, ax, ay, az)
    local scale = vec3(1, 1, 1)

    return mat4(pos, scale, rot)
end
