// Emissive, additive: the GPS route and the beacon. `tint` colour, `strength`; a beam (beacon) fades
// out going up (uses the model's own height, VERTEX y from -50 to 50 on the built-in cylinder).
VARYING float vUp;
VARYING float vAlong;
void MAIN()
{
    float a = strength * mix(1.0, 1.0 - smoothstep(-0.5, 0.5, vUp), beam);
    float pulse = 0.65 + 0.35 * sin(vAlong * 0.6 - time * 9.0);
    FRAGCOLOR = vec4(tint.rgb * a * mix(1.0, pulse, 1.0 - beam), a);
}
