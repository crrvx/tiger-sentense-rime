-- Bounded FIFO memoization. Cached false/zero are values, never misses.
-- Callers own cache lifetime; scoring caches must belong to a model/score epoch.
local M = {}
function M.new(limit)
    assert(type(limit) == "number" and limit >= 1 and limit % 1 == 0, "invalid cache limit")
    return {values={}, keys={}, next=1, limit=limit}
end
function M.put(cache, key, value)
    if cache.values[key] ~= nil then
        cache.values[key] = value
        return value
    end
    local old = cache.keys[cache.next]
    if old ~= nil then cache.values[old] = nil end
    cache.values[key] = value
    cache.keys[cache.next] = key
    cache.next = cache.next % cache.limit + 1
    return value
end
return M
