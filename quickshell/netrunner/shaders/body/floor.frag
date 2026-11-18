// The projector under the hologram: rings, a turning arc, tick marks round the rim, additive.
// Uniforms: tint, time, open (0..1, the disc grows out as the rig opens)
VARYING vec2 vXz;
void MAIN()
{
    float r = length(vXz) / max(open, 0.001);
    if (r > 1.0) discard;
    float a = atan(vXz.y, vXz.x);
    float fr = max(fwidth(r), 1e-4);
    float rings = 0.0;
    rings += 1.0 - smoothstep(0.0, 1.5, abs(r - 0.98) / fr);
    rings += (1.0 - smoothstep(0.0, 1.5, abs(r - 0.72) / fr)) * 0.6;
    rings += (1.0 - smoothstep(0.0, 1.5, abs(r - 0.42) / fr)) * 0.45;
    float ticks = step(0.86, r) * step(r, 0.94) * step(0.82, fract(a * 36.0 / 6.28318));
    float arcA = mod(a - time * 0.9, 6.28318);
    float arc = (1.0 - smoothstep(0.0, 1.5, abs(r - 0.85) / fr)) * step(arcA, 1.2) * (1.0 - arcA / 1.2) * 2.0;
    float glow = (1.0 - smoothstep(0.0, 0.5, r)) * 0.18;
    float a2 = mod(-a - time * 0.5, 6.28318);
    float arc2 = (1.0 - smoothstep(0.0, 1.5, abs(r - 0.6) / fr)) * step(a2, 2.4) * 0.7;
    vec3 col = tint.rgb * (rings * 0.55 + ticks * 0.35 + arc * 0.6 + arc2 * 0.4 + glow);
    FRAGCOLOR = vec4(col * (1.0 - smoothstep(0.92, 1.0, r) * 0.3), 1.0);
}
