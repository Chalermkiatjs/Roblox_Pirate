# Cutlass Animation Workspace

Open `assets/animations/PirateOcean_Animations.rbxlx` separately from the game.
It contains two standard-bind block rigs, Cutlass_R6 and Cutlass_R15, and eight
editable KeyframeSequence clips per rig: Idle, Guard, Slash, Thrust, Heavy,
Parry, Stagger and Feint. These are draft clips baked from the existing moveset,
not polished motion-capture assets. Player legs are unweighted so native
locomotion can continue when the clips play at Action priority.

Select a rig and open Avatar > Animation Editor. Use the editor's saved clip
menu to load Cutlass_Slash (or another clip) from that rig's AnimSaves reference.
The clips live under ServerStorage.RBX_ANIMSAVES. Do not use Play mode to author.
If the editor was already open before the file loaded, reselect the rig.

Attack Contact markers are at Slash 0.24s, Thrust 0.18s and Heavy 0.65s.
Keep contact times synchronized with HitTime in MovesetConfig. RecoveryEnd
markers document the return to the ready stance. Idle and Guard loop.

Publish each finalized clip under the same user/group owner as the experience.
Put the numeric asset IDs in the matching R6 or R15 table in
`src/shared/MovesetConfig.lua`. The workspace itself is not used at runtime,
and its rigs do not need to be copied into the game. No clips have been
published automatically; zero IDs still use the game's procedural fallback.

Rebuild the draft workspace with:

```powershell
node tools/build-animation-place.mjs 'D:\Personal Project\Tools\Luau\0.741\luau.exe'
```

Rebuilding overwrites the generated workspace file. Preserve edited clips in
a separately named Studio file before rebuilding. The generator reads the
existing Luau pose/balance modules and native rig bindings captured from Studio.
Its assertions validate endpoints and exact contact frames; XML validation and
Studio playback are separate checks.

## Forward Direction Fix

`PirateOcean_Animations_ForwardFix.rbxlx` contains corrected drafts. The original
workspace is preserved. Positive shoulder X raises the arm toward Roblox's -Z
forward direction; the original drafts used negative X and reached backward.
The game's existing uploaded IDs have a temporary MirrorForward compatibility
flag. Remove that flag on each slot when publishing and mapping corrected clips.

To rebuild only the corrected draft file:

```powershell
node tools/build-animation-place.mjs 'D:\Personal Project\Tools\Luau\0.741\luau.exe' PirateOcean_Animations_ForwardFix.rbxlx
```
