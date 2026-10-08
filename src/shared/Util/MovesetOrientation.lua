local Orientation = {}

-- S * rotation * S with S = diag(1, 1, -1), preserving lateral motion.
function Orientation.mirrorForward(c)
    return {c[1], c[2], -c[3], c[4], c[5], -c[6], c[7], c[8], -c[9], -c[10], -c[11], c[12]}
end

return Orientation
