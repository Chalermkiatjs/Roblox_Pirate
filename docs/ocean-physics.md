# Ocean Physics Direction

The new water model lives in `src/shared/OceanPhysics.lua`. It is intentionally
shared-safe so server ship motion and client ocean presentation can sample the
same wave field.

Design goals:

- Layer several wave sizes for readable ocean motion instead of a flat sine bob.
- Use multiple hull probes so boats pitch and roll into waves instead of moving
  as a single hovering point.
- Increase drag and reduce handling in shallow water, while keeping control
  forgiving enough for Roblox play.
- Expose wake intensity for foam, spray and trailing water effects.
- Keep tuning arcade-readable, closer to a Sea of Thieves feel than a strict
  simulator.

Recommended next integration:

1. In `ShipPhysics.lua`, call `OceanPhysics.buoyancyAt()` for each active boat
   and apply the returned force/torque to the hull assembly.
2. Pass island or zone depth into `buoyancyAt()` when available so shoals slow
   boats before hard grounding.
3. In `OceanVisuals.client.lua`, sample `OceanPhysics.heightAt()` for water mesh
   motion and use `wakeIntensity()` for foam and spray emitters.
4. Tune wave amplitude, spring and damping separately for raft, sloop and
   brigantine after a Studio playtest.
