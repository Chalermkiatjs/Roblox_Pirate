# Architecture

## Design Pillars

- Ship is the character: progression, health, cargo, speed, crew, and combat stats live on the ship.
- Ocean is progression: deeper waters unlock higher risk, better loot, stronger events, and the Kraken.
- PvE first: early systems assume cooperative play, shared exploration, and environmental threats.
- Server authoritative: loot, upgrades, events, boss state, and saves are controlled by server modules.

## Runtime Layers

### Shared

Shared modules provide static definitions:

- ship tiers
- island definitions
- ocean event definitions
- treasure tables
- crew roles
- save schema defaults
- gameplay constants

### Server

Server services own game state:

- `DataService`: profile loading, migration, session state, save writes
- `ShipService`: ship stats, cargo, damage, repair, upgrades
- `TreasureService`: rarity rolls, rewards, collection registration
- `OceanEventService`: random event selection and rewards
- `IslandService`: island discovery and loot rolls
- `CrewService`: basic crew assignment bonuses
- `BossService`: Kraken spawn, damage, and reward logic

### Client

Client controllers currently bootstrap a small local HUD placeholder and listen for state snapshots. Visuals and input should be expanded after Studio world setup.

## Networking

`ServerMain.server.lua` creates remotes under `ReplicatedStorage.PirateOcean.Remotes`:

- `RequestSnapshot`
- `PrepareVoyage`
- `ExploreIsland`
- `TriggerOceanEvent`
- `AttackKraken`
- `UpgradeShip`
- `AssignCrew`
- `SellCargo`

The client can call these remotes, but the server validates progression and calculates outcomes.

## Next Roblox Studio Work

1. Build port spawn and ship dock.
2. Add five island models with named markers matching `IslandConfig`.
3. Add ocean zone parts or distance/depth detection.
4. Connect boat movement controller so ship stats affect steering.
5. Replace placeholder HUD with production UI.
