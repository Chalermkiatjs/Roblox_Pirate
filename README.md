# PirateOcean

Roblox MVP for an ocean-based pirate survival game where the ship is the character.

Core loop:

1. Port
2. Prepare ship
3. Sail
4. Islands and ocean events
5. Loot
6. Choose to go deeper or return
7. Sell, collect, craft
8. Upgrade ship

## MVP Scope

- 1 starter port
- 5 islands
- 3 ship tiers
- 1 Kraken boss encounter
- 5 random ocean events
- Treasure rarity and collection systems
- Basic crew support
- Ship upgrade progression
- Save data architecture
- PvE-first gameplay

## Tooling

This project is structured for Rojo.

Recommended setup:

1. Install Rojo.
2. Open Roblox Studio.
3. Open the Rojo plugin.
4. Run `rojo serve default.project.json` from this folder.
5. Connect the plugin to the running Rojo server.

The game source maps into `ReplicatedStorage`, `ServerScriptService`, and `StarterPlayerScripts`.

## Project Layout

- `src/shared`: shared config, schemas, constants, and utility modules
- `src/server`: authoritative gameplay systems and services
- `src/client`: player-facing client controllers
- `docs`: architecture notes, data schema, and roadmap

## Current MVP Behavior

The server creates a simple runtime loop:

- players receive a ship profile from saved data or defaults
- port preparation and upgrades are modeled through `ShipService`
- ocean events are selected by depth and risk through `OceanEventService`
- island loot and boss rewards are generated with rarity-aware treasure tables
- collection state, crew assignments, cargo, gold, and ship upgrades are saved through `DataService`

This is intentionally code-first and asset-light so the next pass can connect Roblox Studio models, UI, and world geometry without rewriting the data architecture.

