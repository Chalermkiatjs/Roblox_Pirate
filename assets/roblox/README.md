# Reference Frigate: Roblox Import

The FBX is a separate import copy of the revised Blender master. Exporting does
not save changes to the master or modify the existing sailing implementation.

## Revision 3: Closed Stern And Authored Collision

The missing horizontal transom bands were inward-facing single-sided surfaces,
not texture gaps. They are replaced by one connected 0.18-unit-thick closed
transom; both cambered aft roofs now have closed undersides and perimeter edges.
The FBX contains explicit triangles, and its reimported transom is tested from
outside for front-facing normals. Look for `Frigate_Stern_Transom_Planking` in the
new import. Runtime selection prefers this revision over the cached old model.

Startup now freezes and removes every recognized source import from Workspace,
not just the selected template. Duplicate and named merged/incomplete imports
are preserved under `ServerStorage.PirateOceanAssets.ImportBackups`; the selected
complete model remains `PirateOceanAssets.ReferenceFrigate`. Runtime boats are
excluded. This prevents leftover giant/unanchored import previews from falling
onto the harbor. Sync this code, Stop, then Play again to apply the cleanup.

`src/shared/FrigateCollision.lua` is generated from the Blender source and adds
760 native primitive hitboxes: tapered/cambered floors, hull/transom/cabin walls,
railings, hatch guards, stairs, three masts, deck fittings/barrels, all twenty
cannons, wheel, beams, bulkheads, cargo, berths, lanterns and the rudder.
Rudder hitboxes weld to the moving rudder meshes, not to the static hull. Only
the mass-bearing hull receives fluid forces. Sails and ropes remain noncolliding.
The broad quarterdeck stair has a clear route beside the mizzenmast; the mast
remains solid rather than becoming a walk-through object.

Offline coverage checks sample 6,212 floor points, 2,763 shell rays and 444
avatar-volume points along the three stair routes. These are geometry checks,
not proof that Roblox humanoid walking/physics passes. Studio Play remains pending.
760 proxies plus detailed art per boat need profiling before large multiplayer use.

During Studio Play, show/hide a chosen runtime boat's hitboxes on the server with:

```lua
local visual = require(game.ServerScriptService.PirateOceanServer.Services.FrigateVisual)
visual.setCollisionDebug(boatModel, true) -- Replace boatModel with the selected runtime Model.
visual.setCollisionDebug(boatModel, false)
```

Rebuild collision using Blender with the master and `build_frigate_collision.py`,
then run `validate_collision.py`. Re-export with `export_frigate.py` and run
`validate_frigate.py` in a fresh factory-startup process. This revision does not
overwrite the current `.rbxlx` place or publish/import assets into Studio.

## Interior And Sealed Planks

Reimport the FBX in this folder to obtain the new geometry. Code synchronization
alone cannot change uploaded meshes. The prior import was confirmed by the user;
this revised upload and hands-on playtest remain pending.

- Hull, main deck and aft roof plank edges meet without light-leaking gaps.
- Tapered bow deck planks include the triangular edge pieces.
- The wheel is a separate mesh, with its pedestal toward the bow and grips aft.
  It is moved slightly forward to clear the upper cabin behind the helmsman.
- An open 2.8-by-6.2 source-unit hatch leads down fourteen steps to the gun deck.
  At the runtime 3x scale, the stair width is 5.4 studs; beam clearance is 5.7.
- The lower room has a continuous floor, mast feet, beams, bulkheads, cargo,
  berths, lanterns and the existing decorative cannons. There are six runtime lights.
- Main-floor colliders leave the hatch open. Interior floors, walls, treads,
  cargo and guards have separate simple collision; decorative meshes do not.
- Aft deck access now has visible stairs and matching rail openings.

Import the revised model without merging its meshes, leave it in Workspace,
sync Rojo, then Stop/Play. Save your current place before changing imports.
The runtime prefers the revised model and preserves an older Workspace template
as a ServerStorage legacy backup. If only old art exists, its main deck remains
closed and the old wheel anchor is retained. The room is accessed physically
through the hatch, not through a teleport or a water-facing opening.

Wood/canvas procedural grain is retained in the Blender master. This FBX still
uses vertex base colors, not baked PBR texture maps. The gap correction is real
geometry, not a texture painted across a missing surface.

## Import Into Studio

1. Stop any playtest and open the intended PirateOcean place.
2. Select File > Import and choose `reference_frigate_roblox.fbx` in this folder.
3. Use these import settings:
   - Name: `ReferenceFrigate`
   - Import Only As Model: enabled
   - Upload to Roblox: enabled, with the intended creator selected
   - Add to Workspace: enabled
   - Anchored: enabled
   - Set Pivot to Scene Origin: enabled
   - Scale Unit: Studs
   - Merge Meshes: disabled
   - Ignore Vertex Colors: disabled on the mesh objects
4. Review the preview and any warnings, then click Import.
5. Right-click the imported item and choose Find in Workspace.
6. Save the place. Asset upload does not publish the place itself.

The bow is oriented toward Roblox -Z and the ship is Y-up. The manifest contains
the expected dimensions and per-mesh triangle counts. The over-budget hull is
split at disconnected plank boundaries; no planks are cut open. Other components
remain separate. Vertex colors preserve base wood, canvas, brass and paint colors,
not the procedural weathering shaders in Blender. Keep mesh merging disabled.

## Current Status

The user confirmed importing the FBX into Studio. Asset IDs are not recorded in
the repository. Codex cannot inspect the current unsaved Studio scene because
the Windows control runtime failed to start. The corrections below are tested
as code and with a Blender FBX round trip, not yet verified in a Studio playtest.

## Sailing Integration

`src/server/Services/FrigateVisual.lua` connects the imported art to the existing
ship controls. With the latest Rojo code synced, leave the imported model named
`ReferenceFrigate` in Workspace, then Stop/Play. Other model names are detected
from the ship's component names. At startup the server moves it
to `ServerStorage.PirateOceanAssets`, clones a ship for each player and adds:

- An invisible mass-bearing hull for native Terrain-water buoyancy.
- Tapered main/stern floors, both full aft decks, access slopes and rail collision.
- Bow/stern-based import orientation and a helm directly behind the wheel.
- Static welds plus Motor6D joints for all 11 sails/seams and the rudder.
- Sail I/II deployment, automatic stowing when leaving the helm, steering,
  braking, owner-only boarding, docking and respawn through the existing systems.

Existing tier stats and upgrades are unchanged. All three tiers use the reference
art by default; configure `src/shared/FrigateConfig.lua` to restrict it. If no
valid template is present, the game warns and uses the original blockout boats.
The runtime uses a 3x art scale (about 167 studs including the bowsprit), scales
colliders consistently and moves berths away from the dock. Boarding prompts
remain reachable at the hull/water level. Scale and deck layout are in
`FrigateConfig.lua`. The revision-2 interior and wheel geometry require reimport.

The rudder's Motor6D C0 is at the actual stock center and C1 preserves each
piece's neutral pose. Steering rotates this fixed hinge rather than translating
the mesh center sideways. Code sync does not import or upload the FBX itself;
hands-on playtesting remains pending because the control runtime could not start.

`OceanConfig.lua` and `Util/WaveMotion.lua` add bounded swell-based pitch/roll
through AlignOrientation, without replacing native water buoyancy. Client-only
bow/side splash and foam effects check for water and remain on the water plane
while the hull tilts. Native Terrain waves are set to their 1-stud limit; the
swell sampler is a presentation approximation, not a query of the Terrain
shader's exact wave phase or a fluid simulation.

After import, run this in the server Command Bar during Studio Play:

```lua
require(game.ServerScriptService.PirateOceanServer.Tests.FrigateSmoke)()
```

This optional test creates and removes a separate ship, checking welds, sail
deployment, rudder steering, motion, buoyancy and docking. Also manually test
walking through the hatch in both directions, steering from the wheel, boarding,
shoreline collisions and multiplayer. The detailed reference art needs LOD work
before large multiplayer/mobile use; current counts are in the export manifest.

## Rebuild

Run Blender in background mode with the master `.blend` and `export_frigate.py`.
The script evaluates modifiers, splits closed mesh islands as needed, adds vertex
colors and exports only the ship, without the studio floor, lights or cameras.

Official references:
- https://create.roblox.com/docs/studio/importer
- https://create.roblox.com/docs/art/modeling/specifications
