local vmath = require('vmath')

local valueFunctions = {}

-------------------

function valueFunctions.normalize(originalValueFunc)
    return function(self, vecs, visited)
        local val, expr = originalValueFunc(self, vecs, visited)
        return val:normalize(), "normalize(" .. expr .. ")"
    end
end

function valueFunctions.cross(vec1Id, vec2Id)
    return function(self, vecs, visited)
        local v1 = vecs:get(vec1Id)
        local v2 = vecs:get(vec2Id)

        visited = visited or {}
        if visited[vec1Id] or visited[vec2Id] then
            print(
                "Cycle detected in cross product value: "
                .. (visited[vec1Id] and "already visited vector " .. v1.label .. ", ")
                .. (visited[vec2Id] and "already visited vector " .. v2.label)
            )
            return self.computedValue
        end

        -- TODO: Check for errors and wrong result types
        local v1value, v1expr = v1:valueFunc(vecs, visit(visited, vec1Id))
        local v2value, v2expr = v2:valueFunc(vecs, visit(visited, vec2Id))
        return vec3(v1value):cross(v2value), v1expr .. ' x ' .. v2expr
    end
end

function valueFunctions.projectPlane(vec1Id, vec2Id)
    return function(self, vecs, visited)
        local v1 = vecs:get(vec1Id)
        local v2 = vecs:get(vec2Id)

        visited = visited or {}
        if visited[vec1Id] or visited[vec2Id] then
            print(
                "Cycle detected in plane projection value: "
                .. (visited[vec1Id] and "already visited vector " .. v1.label .. ", ")
                .. (visited[vec2Id] and "already visited vector " .. v2.label)
            )
            return self.computedValue
        end

        local v1value, v1expr = v1:valueFunc(vecs, visit(visited, vec1Id))
        local v2value, v2expr = v2:valueFunc(vecs, visit(visited, vec2Id))
        return vmath.projectOntoPlane(v1value, v2value), 'proj_(' .. v2expr .. ') ' .. v1expr
    end
end

-------------------

function visit(t, id)
    local result = {}
    for _, v in pairs(t) do
        result[v] = v
    end
    t[id] = true

    return result
end

-------------------

return valueFunctions
