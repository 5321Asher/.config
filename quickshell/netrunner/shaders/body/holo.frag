// The ripperdoc's body, as the game draws it on its cyberware screen: translucent red flesh lit from
// the rim, scanlines crawling up it, a warmer core in the chest, the heart (at `heart`, rest pose)
// glowing with every beat (`beats`: the heartbeats so far), and the picked implant traced at `focus`
// (rest pose) in `hot`. `build` 0..1 draws it up from the feet behind a bright front. The vessels
// running through it are their own model (vessels.frag), seen through the flesh.
// Uniforms: tint (the flesh), veins, hot, heart (vec3), focus (vec3), focusAmt, build, time, beats, flicker
VARYING vec3 vPos;
VARYING vec3 vWorld;
VARYING vec3 vNormal;

void MAIN()
{
    float top = build * 1.86;
    if (vPos.y > top + 0.002) discard;
    vec3 V = normalize(CAMERA_POSITION - vWorld);
    float ndv = abs(dot(normalize(vNormal), V));
    float rim = pow(1.0 - ndv, 2.4);

    // fine scanlines on the skin, crawling up
    float scan = smoothstep(0.6, 1.0, sin(vPos.y * 260.0 - time * 2.0)) * (0.3 + 0.7 * ndv);

    float bp = fract(beats);
    float thump = exp(-pow(bp * 9.0, 2.0)) + 0.6 * exp(-pow((bp - 0.22) * 9.0, 2.0));
    float chest = 1.0 - smoothstep(0.0, 0.22, distance(vPos, vec3(0.0, 1.3, 0.05)));
    float glow = (1.0 - smoothstep(0.0, 0.09, distance(vPos, heart))) * thump;

    float f = focusAmt * (1.0 - smoothstep(0.03, 0.13, distance(vPos, focus)));
    float front = 1.0 - smoothstep(0.0, 0.025, abs(vPos.y - top));

    // dark red flesh, lit at the rim
    vec3 col = tint.rgb * (0.012 + rim * 0.8 + 0.012 * ndv + scan * 0.025);
    col += mix(tint.rgb, veins.rgb, 0.35) * chest * 0.06;
    col += veins.rgb * glow * 1.1;
    col = mix(col, hot.rgb * (0.25 + rim * 1.1 + scan * 0.3) * (0.85 + 0.2 * sin(time * 7.0)), f);
    col += vec3(1.0, 0.85, 0.7) * front * step(build, 0.999) * 1.2;
    col *= 0.92 + 0.08 * flicker;
    FRAGCOLOR = vec4(col, max(col.r, max(col.g, col.b)));
}
