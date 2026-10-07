# Data Schema

Current schema version: `1`

```lua
{
    schemaVersion = 1,
    gold = 0,
    currentShipTier = "Raft",
    discoveredIslands = {},
    collection = {},
    cargo = {},
    crew = {
        navigator = nil,
        gunner = nil,
        quartermaster = nil,
    },
    stats = {
        voyages = 0,
        krakenDefeats = 0,
        deepestDepth = 0,
    },
}
```

## Collection

`collection` is keyed by treasure id. Each value stores how many times the player has found that treasure.

```lua
collection = {
    RustyCoin = 4,
    StormPearl = 1,
}
```

## Cargo

Cargo is temporary voyage inventory. It is designed to be sold, crafted, or lost when the ship is defeated.

```lua
cargo = {
    Driftwood = 12,
    IronScrap = 3,
}
```

## Migration Rule

`DataService.migrateProfile` should only add missing fields and convert known old fields. Never delete unknown future fields during migration.

