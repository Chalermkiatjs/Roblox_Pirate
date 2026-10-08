# Combat

This is a PvE cutlass combat prototype. Players cannot damage other players.
Each island has one raider that approaches nearby characters, guards incoming
attacks and alternates ordinary strikes with a slower heavy attack. Defeated
raiders respawn after 45 seconds. The Sparring Mate at harbor (64, 11, 30) only
attacks after its Spar prompt is used. It gives no gold or bounty and resets
eight seconds after defeat. Leave its area to end the spar.

## Controls

Equip Cutlass through Roblox's backpack/hotbar. Combat actions only bind while
the sword is equipped, the character is alive and not seated, and the ledger is
closed. Helm controls remain separate.

| Action | Keyboard/Mouse | Gamepad |
| --- | --- | --- |
| Slash | Tool activation / left click | Tool activation / R2 |
| Thrust | T | X |
| Heavy | R | Y |
| Hold guard | F or right mouse | L2 |
| Feint | Q during windup | B during windup |

Mobile uses the Slash, Thrust, Heavy, Block, Feint and Stow buttons. Mobile Block
toggles guard; tap Release to lower it. Changing tools, opening the ledger,
sitting down or losing window focus releases guard.
Drawing the cutlass replaces the harbor orders with combat orders; Stow restores
them. Both modes leave room below for Roblox's native tool hotbar.
Mouse movement directly turns the shoulder camera and facing direction; the
cursor stays hidden during mouse look. Hold Alt to click HUD buttons. Menus,
text entry and the ledger release the cursor automatically. Right mouse guards
without being required to rotate the camera.

## Rules

The server owns attack timing, stamina, hit validation and rewards. Clients send
an action name, never a target, damage amount, stamina value or bounty amount.
At the end of windup, the server selects the nearest valid enemy within the
attack's range and forward cone. A world raycast rejects hits through walls;
vertical separation over six studs rejects hits between decks. Each swing hits
at most one target. Unequipping, defeat, a successful feint or a stagger cancels
pending hits. Spawn ForceFields protect characters.

Guard only protects the front. The first 0.24 seconds are a parry window; tapping
guard cannot reopen the window before its cooldown. Parry staggers the attacker
and grants one faster, stronger riposte within one second. Release guard before
counterattacking. Later blocks cost stamina; insufficient stamina causes a
guard break. Holding guard drains stamina and prevents regeneration. Feints
cancel during windup, cost additional stamina and retain a recovery interval.

Player HP is native Humanoid Health/MaxHealth, initially 100. Melee changes only
that HP. Ship HP remains ShipService's health and is used only by naval damage,
ocean events and Kraken retaliation. HUD labels PLAYER and HULL separately.
Character defeat follows the existing harbor respawn flow; it does not clear
cargo, reset bounty or repair the hull. Sinking still uses the existing cargo
loss and harbor recovery rules. Stamina resets when a new character spawns.

## Bounty

Raider victories grant 25 bounty and 12 gold per island depth, once per defeated
raider. Training gives neither. A Kraken victory grants 500 bounty in addition
to its existing rewards. Bounty is separate from spendable gold and is capped
at 999,999,999. Save schema version 2 adds bounty and combatDefeats while keeping
the existing DataStore name; old profiles gain zero-valued defaults. Studio
profiles remain temporary, as before.

Tune balance in `src/shared/CombatConfig.lua`. This prototype does not implement
PvP, player bounty hunting or persistent wounds.

## Moveset

Drawing the cutlass enables an upper-body stance. Slash has a lateral windup,
Thrust extends forward, and Heavy raises the weapon overhead. Guard, parry,
stagger and feint recovery have separate visual states. Native walking remains
in control of player legs. Server cues use synchronized server time, including
the shortened riposte windup, and are visible to other clients for both players
and NPCs. Damage remains server-owned; animation events cannot award hits.

`src/shared/MovesetConfig.lua` has separate R6 and R15 slots for Idle, Guard,
Slash, Thrust, Heavy, Parry, Stagger and Feint. Zero IDs use temporary procedural
joint poses, not authored animation assets. To replace them, create clips in
Roblox Animation Editor or Moon Animator and publish under the experience owner.
Set each slot's Id to the published numeric Animation ID. For attack clips,
set HitTime to the contact timestamp in the source clip; playback speed aligns
that timestamp with the authoritative windup, including ripostes. Idle and
Guard loop. Other clips should return toward the ready pose before recovery ends.
Author upper-body-only clips if legs should retain the default walk cycle.

The server creates the Animator and plays clips. Clients apply fallback joint
poses after native animation evaluation; they restore their previous additive
offset before the next evaluation. If a configured clip has not loaded, fallback
poses remain visible. Test asset ownership and playback in a published session.
There are no uploaded animation assets or new third-party plugins in this change.

The current seven R15 uploads are mapped in MovesetConfig. They were authored
with reversed forward axes, so their slots set MirrorForward for client-side
correction after Animator evaluation. This supports both Motor6D and
AnimationConstraint rigs. When replacing an ID with a forward-corrected clip,
remove MirrorForward on that slot to avoid correcting the direction twice.

## Verification

Run `tests/moveset.spec.luau` for pose/contact timing, recovery, riposte timing,
rig configuration and 30/60/120 Hz sampling. Run the portable Luau interpreter
with `tests/combat.spec.luau` for attack spam,
feint cancellation, front/back guard, parry cooldown, riposte consumption, guard
breaks, stamina at 30/60/120 Hz, hit ranges and bounty limits.

After syncing Rojo and pressing Play, run in the server Command Bar:

```lua
require(game.ServerScriptService.PirateOceanServer.Tests.CombatSmoke)()
```

This uses a separate temporary profile and character to check player/ship HP
isolation, old-profile migration and bounty retention on character defeat.
Also run the existing ServiceSmoke to check Kraken bounty and naval progression.

Manual Studio checks still required: equip/stow, all strikes and feints, visible
windups, parry into riposte, stamina exhaustion, hits blocked by scenery, enemy
movement and respawn, death/respawn, native tool activation on gamepad, mobile
portrait/landscape layout, and a two-player session to confirm no PvP damage or
duplicate rewards. Check both R6 and R15, two-client visibility, seating/stowing
during a windup, and no accumulated joint offsets after repeated attacks.
The shipped R6 enemy rigs have combat poses but no authored walking clips.
