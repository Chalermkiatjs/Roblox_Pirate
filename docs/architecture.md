# Architecture

## Design Pillars

- Ships own naval progression, hull health, cargo, speed, crew and cannon stats. Characters own Humanoid health and cutlass combat stamina; bounty belongs to the saved player profile.
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
- `CombatService`: native character health snapshots, cutlass validation, stamina, guard/parry/feint/riposte, island raiders and server-awarded bounty

### Client

Client controllers build the playable HUD, send helm steering and per-press speed-step input, and render local-only ocean presentation such as foam wakes, light spray and oar motion. W/S adjust Reverse, Stopped, Paddles, Sail I and Sail II one step at a time; held keys do not repeat. The server validates the helm occupant and step direction, applies a dedicated input rate limit, and owns the persistent speed stage. Mobile uses +/- actions and gamepad uses D-pad or triggers. Server snapshots and model attributes remain the source of truth for profile, ship state, island proximity and sailing telemetry.

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
- `SetSailStage`
- `StepSailStage` (RemoteEvent, direction -1 or +1)
- `CombatAction` (RemoteEvent, validated Attack/Block/Feint commands)
- `CombatFeedback` (RemoteEvent, server-confirmed outcomes)

`RequestSnapshot` includes a separate `player` health/stamina record alongside
`ship`, while replicated character attributes supply live stamina and stance.
Save schema version 2 adds bounty without changing the existing DataStore key.
See `combat.md` for the PvE rules and verification requirements.

`ServerMain.server.lua` also creates:

- `ShipControl` RemoteEvent for frequent helm throttle/steer input
- `Notice` RemoteEvent for short player feedback

The client can call these remotes, but the server validates progression and calculates outcomes.

## Next Roblox Studio Work

The reference frigate uses `FrigateVisual` to clone an imported mesh template,
align the actual bow/stern, normalize its size/origin, and add a simple buoyancy hull, walkable deck/collision
proxies and a helm. `ShipPhysics` welds static pieces and creates Motor6D joints
for the 22 sail/seam pieces and three rudder pieces. Visual deployment follows
the same authoritative deployment value used for propulsion; the top of each
sail stays fixed. Steering turns the rudder around its stock, not its mesh center.
The fixed rudder hinge is derived from the imported stock center; C1 stores
each mesh's neutral offset. No remote accepts a mesh ID or model from clients.

Art and collision proxies share a 3x scale. The helm is behind the wheel,
tapered main floors continue through the stern, and both aft deck levels have
full-length collision and access slopes. Frigate berths have extra spacing and
setback to clear the dock; the port predicate also accepts a small radius around
the player's own berth. A hull-level Board prompt remains reachable from water.

Revision-2 art adds a gun deck above the solid buoyancy proxy. Its floor is at
source Y=4.18, leaving at least 5.7 runtime studs under the structural beams.
The companionway is source Z=2.4..8.6, width 2.8: main-floor collision is split
around it, with no longitudinal overlap into the opening. Fourteen tread boxes
and a supporting slope connect it to the lower floor. Walls, cargo, mast feet,
berths and hatch guards use simple collision proxies; detailed art stays
non-colliding and massless. Six hull-attached point lights illuminate the room.
Existing aft access slopes now have matching visible steps and rail openings.
The wheel's support is forward of its grips; the helm faces it and the bow.

Revision-3 art replaces disconnected inward-facing transom bands with a closed
solid shell and adds solid undersides to the cambered aft roofs. Its separate
`Frigate_Stern_Transom_Planking` mesh identifies the newer import. Selection
prefers this revision over cached revision-2 art and preserves the prior template.
`FrigateCollision` is generated from source geometry: native wedges trace tapered
and cambered floors, while blocks/cylinders cover hull/cabin walls, rails, props,
cannons, masts, wheel, interior structures and stairs. Rudder collision carries
`CollisionFollow` and welds to its moving mesh instead of the hull. Only the hull
receives fluid forces. `FrigateVisual.setCollisionDebug` exposes proxy geometry
for Studio checks. Offline mesh/raycast tests are separate from pending Studio
humanoid/physics tests; 760 proxies per boat still require multiplayer profiling.

Interior collision is enabled only for a template with the new floor, stairs
and wheel meshes. Older art keeps its closed deck and old wheel anchor, avoiding
invisible holes or a helm at the revised wheel's position. A revised import is
preferred over an older template; the old Workspace source is retained in
ServerStorage as a legacy backup, not deleted.

`WaveMotion` supplies bounded directional swells to AlignOrientation and local
impact effects. The server samples height and vertical wave velocity at the bow,
stern and sides, then feeds a damped rocking state so water impact leads hull
motion instead of instantly imposing the water slope. Server-time sampling keeps
motion time consistent across clients, but does not reproduce Terrain shader
phases. Native water remains the source of buoyancy; no wave teleportation or
extra vertical lift is applied.
Client splash/foam emitters use water raycasts, distance culling and rate limits;
their attachments intersect the horizontal water plane even while the hull rolls.

The template lives at `ServerStorage.PirateOceanAssets.ReferenceFrigate`; an
imported `Workspace.ReferenceFrigate` (or the default FBX filename) is moved there
at server startup. It is not managed by Rojo, so code synchronization does not
overwrite the imported asset. Missing templates produce a warning and retain
the legacy blockout boats. `FrigateConfig.Tiers` controls which existing tiers use
the visual; all are enabled initially without changing stats or progression.

The user confirmed FBX import; the current corrections and physics playtests
still need hands-on Studio verification.
It remains a detailed asset without mobile LODs; see the export manifest for
current mesh/triangle counts. Run the
optional server `Tests.FrigateSmoke` after importing, then manually test boarding,
walking the quarterdeck and both directions through the companionway,
stage interruption/auto-stow, shoreline collisions,
mobile input, two players, return-to-port and respawn.

1. Playtest buoyancy, swimming, boarding and shoreline ladders for all three ship tiers.
2. Verify per-press W/S speed steps, held-key suppression, reverse/stopped states, mobile/gamepad input, Paddles/Sail I/Sail II visuals, proportional sail deployment, braking, upwind return and auto-stow in Studio.
3. Verify mobile/gamepad helm controls and a two-player session.
4. Tune economy, event cadence and ship progression after hands-on playtests.
5. Add DataStore session locking, save retries and autosave before public release.
