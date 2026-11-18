// A building: dark glass, its edges drawn as neon lines (constant width on screen), a grid of
// windows on the sides (some lit, flickering now and then), fog with distance.
// Uniforms (CustomMaterial properties): base, edge, lights (colours), glow, seed, time, fogColor, fogNear, fogFar
VARYING vec3 vWorld;
VARYING vec3 vNormal;
VARYING vec2 vUv;
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 7.13) * 43758.5453); }
void MAIN()
{
    vec2 fw = max(fwidth(vUv), vec2(1e-5));
    vec2 e2 = min(vUv, 1.0 - vUv) / fw;
    float edgeLine = 1.0 - smoothstep(0.0, 1.8, min(e2.x, e2.y));
    float side = 1.0 - abs(vNormal.y);
    float top = step(0.5, vNormal.y);

    // windows: rows by height, columns along the face
    float u = abs(vNormal.x) > 0.5 ? vWorld.z : vWorld.x;
    vec2 cell = vec2(u * 0.9, vWorld.y * 1.15);
    vec2 f = fract(cell);
    float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.3, f.y) * step(f.y, 0.72);
    float r = h21(floor(cell));
    float lit = step(0.62, r) * (0.75 + 0.25 * sin(time * (1.0 + r * 3.0) + r * 40.0));
    float ground = smoothstep(0.0, 2.0, vWorld.y);           // no windows at street level

    vec3 col = base.rgb * (0.35 + 0.45 * side + 0.2 * top);
    col += lights.rgb * win * lit * side * ground * (0.55 + glow * 0.6);
    col += edge.rgb * edgeLine * (0.45 + glow * 1.2);
    col += edge.rgb * top * glow * 0.12;
    float d = length(vWorld - CAMERA_POSITION);
    col = mix(col, fogColor.rgb, smoothstep(fogNear, fogFar, d));
    FRAGCOLOR = vec4(col, 1.0);
}
