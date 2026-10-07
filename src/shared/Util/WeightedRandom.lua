local WeightedRandom = {}

function WeightedRandom.choose(weightedItems, getWeight)
    local totalWeight = 0

    for key, item in pairs(weightedItems) do
        local weight = getWeight and getWeight(item, key) or item.weight
        if weight and weight > 0 then
            totalWeight += weight
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = Random.new():NextNumber(0, totalWeight)
    local cursor = 0

    for key, item in pairs(weightedItems) do
        local weight = getWeight and getWeight(item, key) or item.weight
        if weight and weight > 0 then
            cursor += weight
            if roll <= cursor then
                return item, key
            end
        end
    end

    return nil
end

return WeightedRandom

