// The hologram's circulatory system: every beat of the heart (`beats`: the beats so far, `heartRate`
// a second now) sends a bright pressure wave out along every vessel at `speed` m/s, the head of it
// white-hot with a tail fading back towards the heart; the blood itself streams outwards under it. On opening, the blood
// fills the vessels from the heart outwards (`fill`: metres reached). `surge` (0..1) runs it all
// hotter (the circulatory implant selected); near `focus` (the selected implant, rest pose) it turns `hot`.
// Uniforms: tint (the blood), hot, focus (vec3), focusAmt, fill, surge, time, beats, heartRate, speed, flicker
VARYING vec3 vPos;
VARYING vec3 vWorld;
VARYING vec3 vNormal;
VARYING vec2 vUv;
VARYING float vThin;
void MAIN()
{
    float d = vUv.x;
    if (d > fill) discard;
    vec3 V = normalize(CAMERA_POSITION - vWorld);
    float core = pow(abs(dot(normalize(vNormal), V)), 1.6);

    // the wave: how far behind the last front this point is, in metres
    float behind = fract(beats - d * heartRate / speed) * speed / heartRate;
    float wave = exp(-behind / (0.05 + 0.04 * surge)) * (1.0 - 0.45 * smoothstep(0.2, 1.8, d));
    float stream = smoothstep(0.35, 1.0, sin(d * 70.0 - time * (8.0 + 6.0 * surge)));
    float edge = 1.0 - smoothstep(0.0, 0.06, fill - d);      // the blood's front, filling

    float f = focusAmt * (1.0 - smoothstep(0.04, 0.16, distance(vPos, focus)));
    vec3 blood = mix(tint.rgb, hot.rgb, f);
    vec3 col = blood * (0.22 + 0.18 * surge + stream * (0.12 + 0.1 * surge)) * (0.35 + 0.65 * core);
    col += mix(blood, vec3(1.0, 0.95, 0.85), 0.55) * wave * (0.9 + 0.8 * surge) * (0.5 + 0.5 * core);
    col += vec3(1.0, 0.9, 0.7) * edge * 1.4;
    col *= vThin * (0.92 + 0.08 * flicker);
    FRAGCOLOR = vec4(col, max(col.r, max(col.g, col.b)));
}
