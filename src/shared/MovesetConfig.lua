return {
    Tag = "PirateOceanCombatant",
    FadeTime = 0.1,
    -- Publish clips under the experience owner, then replace zero with asset IDs.
    -- Attack HitTime is the contact time in the source clip, in seconds.
    R6 = {
        Idle = {Id = 0}, Guard = {Id = 0},
        Slash = {Id = 0, HitTime = 0.24}, Thrust = {Id = 0, HitTime = 0.18},
        Heavy = {Id = 0, HitTime = 0.65},
        Parry = {Id = 0}, Stagger = {Id = 0}, Feint = {Id = 0},
    },
    R15 = {
        -- These original uploads face backward; remove MirrorForward after replacing with corrected clips.
        Idle = {Id = 0}, Guard = {Id = 133905011307267, MirrorForward = true},
        Slash = {Id = 110352296762065, HitTime = 0.24, MirrorForward = true},
        Thrust = {Id = 109316465851527, HitTime = 0.18, MirrorForward = true},
        Heavy = {Id = 102936727309865, HitTime = 0.65, MirrorForward = true},
        Parry = {Id = 125299629511759, MirrorForward = true},
        Stagger = {Id = 122356023333903, MirrorForward = true},
        Feint = {Id = 76419039334730, MirrorForward = true},
    },
}
