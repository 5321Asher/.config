#version 440
// The lock's backdrop. The desktop snapshot tears apart (`glitch`: bands sliding sideways, the
// colours splitting red / cyan, now and then inverting) while a wall of black ICE seals over it:
// hexagonal cells flipping shut, sweeping in from the left (`dir` 0) as `cover` goes 0 -> 1, or
// opening from the centre outwards (`dir` 1) as it goes back to 0. At cover 1 nothing of the desktop
// shows. The sealed wall breathes faintly; `alert` turns its seams red. No snapshot (`hasShot` 0):
// black under the wall.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float glitch;
    float cover;
    float dir;
    float alert;
    float time;
    float hasShot;
    vec4 ice;
    vec4 red;
    vec4 base;
};
layout(binding = 1) uniform sampler2D shot;

#include "noise.glsl"

float hexDist(vec2 p) { p = abs(p); return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;

    // ---- the desktop, tearing
    float a = clamp(glitch, 0.0, 1.0);
    float t = floor(time * 30.0);
    float bandH = 3.0 + 46.0 * hash1(t + 1.3);
    float band = floor(px.y / bandH);
    float moves = step(1.0 - a * 0.85, hash(vec2(band * 1.3, t)));
    float shift = (hash(vec2(band, t + 4.0)) - 0.5) * 0.3 * a * moves;
    vec2 p = vec2(clamp(uv.x + shift, 0.0, 1.0), uv.y);
    float split = a * 0.018 + abs(shift) * 0.2;
    vec3 desk = vec3(texture(shot, p + vec2(split, 0.0)).r, texture(shot, p).g, texture(shot, p - vec2(split, 0.0)).b);
    if (hash1(t + 7.0) < a * 0.12) desk = 1.0 - desk;
    desk = mix(desk, desk * vec3(1.25, 0.35, 0.45), a * 0.45);
    desk *= 1.0 - a * 0.35 * step(0.5, fract(px.y / 2.0));
    desk *= hasShot;

    // ---- the ICE: pointy hexes 34 px across
    vec2 g = px / 34.0;
    const vec2 r = vec2(1.0, 1.7320508);
    vec2 ha = mod(g, r) - r * 0.5;
    vec2 hb = mod(g - r * 0.5, r) - r * 0.5;
    vec2 gv = dot(ha, ha) < dot(hb, hb) ? ha : hb;
    vec2 id = g - gv;
    float edgeD = 0.5 - hexDist(gv);                       // 0 on a seam, 0.5 in the middle
    float h = hash(id * 0.731 + 3.1);
    vec2 cellUv = id * 34.0 / size;
    float order = dir < 0.5 ? cellUv.x * 0.78 + h * 0.22
                            : length((cellUv - 0.5) * vec2(size.x / size.y, 1.0)) / 0.9 * 0.78 + h * 0.22;
    float sealed = dir < 0.5 ? step(order, cover * 1.06) : 1.0 - step(order, (1.0 - cover) * 1.06);
    float flip = dir < 0.5 ? 1.0 - smoothstep(0.0, 0.07, abs(cover * 1.06 - order))
                           : 1.0 - smoothstep(0.0, 0.07, abs((1.0 - cover) * 1.06 - order));
    flip *= step(0.001, cover) * step(cover, 0.999);

    float seam = 1.0 - smoothstep(0.0, 0.045, edgeD);
    float breathe = 0.55 + 0.45 * sin(time * 0.8 + h * 6.28);
    float lit = step(0.93, hash(id + floor(time * 0.5))) * 0.5;      // a few cells glow, changing slowly
    vec3 seamCol = mix(ice.rgb, red.rgb, clamp(alert, 0.0, 1.0));
    vec3 wall = base.rgb * (0.75 + 0.25 * h);
    wall += seamCol * seam * (0.16 + 0.12 * breathe);
    wall += seamCol * lit * edgeD * 0.12;
    wall += red.rgb * alert * 0.06;

    vec3 col = mix(desk, wall, sealed);
    col += mix(ice.rgb, vec3(1.0), 0.35) * flip * (seam * 1.2 + 0.25);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
