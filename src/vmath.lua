local vmath = {}

function vmath.projectOntoVector(v1, v2)
    return vec3(v2):mul(vec3(v1):dot(v2) / (v2:length() * v2:length()))
end

function vmath.projectOntoPlane(v, planeNormal)
    return v - vmath.projectOntoVector(v, planeNormal)
end

return vmath
