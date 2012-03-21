module(..., package.seeall)

require('bmlua.set')

-- Topologically sort a dependency graph. "dependencies" is a table where keys
-- are nodes and values are neighbors of that node. A node's neighbors are its
-- dependencies. (Nodes point to their dependencies.) This returns an array of
-- nodes in topologically sorted order, or nil if sorting is impossible.
function topological_sort(dependencies)
    sorted = {}
    unsorted = bmlua.set.Set()
    for parent in pairs(dependencies) do
        unsorted:add(parent)
    end
    while unsorted:length() > 0 do
        has_leaf = false
        for parent in unsorted:iter() do
            has_children = false
            for _, child in ipairs(dependencies[parent]) do
                if unsorted:contains(child) then
                    has_children = true
                    break
                end
            end
            if not has_children then
                sorted[#sorted+1] = parent
                unsorted:discard(parent)
                has_leaf = true
                break
            end
        end
        if not has_leaf then
            return nil
        end
    end
    return sorted
end
