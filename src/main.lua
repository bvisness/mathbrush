local inspect = require('inspect')

all_trackable_devices = {
    ['hand/left'] = {
        model = lovr.headset.newModel('hand/left'),
    },
    ['hand/right'] = {
        model = lovr.headset.newModel('hand/right'),
    }
}

function lovr.load()
    lovr.graphics.setBackgroundColor(0x333344)
    -- for name, device in pairs(all_trackable_devices) do
    --     device.model = lovr.headset.newModel(name)
    -- end
end

function lovr.draw()
    lovr.graphics.print('hello world', 0, 1.7, -3, .5)

    for i, hand in pairs(lovr.headset.getHands()) do
        all_trackable_devices[hand].model:draw(pose2mat4(lovr.headset.getPose(hand)))
    end
end

function pose2mat4(x, y, z, angle, ax, ay, az)
    pos = vec3(x, y, z)
    rot = quat(angle, ax, ay, az)
    scale = vec3(1, 1, 1)

    return mat4(pos, scale, rot)
end
