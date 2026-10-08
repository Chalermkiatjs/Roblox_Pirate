# Reference Frigate

An original modeled interpretation of the large three-masted ship at the upper
centre of the supplied reference sheet. The image contains several ships; this
asset follows that ship's general silhouette rather than reproducing every detail.

- `reference_frigate.blend`: editable master, open in the live Blender session.
- `reference_frigate.glb`: ship only, with base-color materials.
- `reference_frigate.fbx`: ship only, for further import work.
- `reference_frigate_preview.png`: rendered three-quarter view.
- `reference_frigate_profile.png`: rendered side view.
- `reference_frigate_bow_detail.png`: close-up of the projecting curved bow stem.
- `reference_frigate_stern_detail.png`: close-up of the revised stern and aft gallery.
- `reference_frigate_interior.png`: view through the accessible gun deck.
- `reference_frigate_hatch.png`: open companionway and stairs, sails hidden for inspection.
- `reference_frigate_wheel.png`: wheel from the helmsman's side.
- `reference_frigate_plank_joins.png`: sealed hull plank joins.
- `reference_frigate_manifest.json`: per-component geometry counts and export notes.

The ship has a curved planked hull, twenty decorative cannons and open gunport
lids, raked two-tier stern gallery windows, projecting curved bow stem, sternpost,
longitudinal rudder blade and stock, wheel, anchors, deck hatches, barrels,
three masts, eight square sails, two jibs, a mizzen gaff sail, and standing/running
rigging with ratlines. Hull, deck, masts, sails and rigging are separate collections.
The original default Blender scene is preserved as `Scene`.

Blender units are metres, bow points along -X, and Z is up. The master retains
procedural wood and canvas materials. These shaders are not baked textures:
interchange files use explicit base colors. This is a detailed source model;
game LODs, collision shapes, animation and Roblox integration are not included.

To rebuild in a fresh Blender file, run `build_reference_frigate.py` with Blender's
Python. It creates a new scene and refuses to overwrite an existing Reference
Frigate scene. To export/render a saved master, run `export_reference_frigate.py`.
`refine_reference_frigate.py` applies the detail revision to the earlier generated
master and saves `reference_frigate_before_hull_detail.blend` before replacing the
affected parts. The aft stairs and original ladder-like rudder fitting are removed.

`refine_interior.py` selectively replaces planking, deck fittings and rails, adds
the open companionway/gun-deck interior, and retains other hull and rigging art.
It saves `reference_frigate_before_interior.blend` before its first revision.
The old external stern ladder is still absent; new stairs serve the interior
and forward access to the aft deck levels. `validate_interior.py` ray-tests
closed plank seams, tapered bow edges, hatch clearance and lower floors.
`render_interior.py` generates the four close inspection views.
