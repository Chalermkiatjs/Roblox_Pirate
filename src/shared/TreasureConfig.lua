local TreasureConfig = {
    RarityWeights = {
        Common = 62,
        Uncommon = 25,
        Rare = 9,
        Epic = 3,
        Legendary = 1,
    },
    SellValues = {
        Common = 12,
        Uncommon = 35,
        Rare = 110,
        Epic = 320,
        Legendary = 1000,
    },
    Items = {
        Driftwood = { rarity = "Common", kind = "Material" },
        RustyCoin = { rarity = "Common", kind = "Treasure" },
        Sailcloth = { rarity = "Uncommon", kind = "Material" },
        IronScrap = { rarity = "Uncommon", kind = "Material" },
        RubyCompass = { rarity = "Rare", kind = "Treasure" },
        StormPearl = { rarity = "Epic", kind = "Treasure" },
        KrakenHeart = { rarity = "Legendary", kind = "BossTrophy" },
    },
}

function TreasureConfig.getItem(itemId)
    return TreasureConfig.Items[itemId]
end

return TreasureConfig

