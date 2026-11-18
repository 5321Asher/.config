#version 440
// The holocall's projection, as a layer effect over the call panel. `build` 0..1 draws the panel
// top to bottom behind a bright scan front; `settle` 0..1 calms the jitter and the red / cyan split;
// `staticAmt` 0..1 drowns it in static (signal lost, access denied); `flash` brightens it (hanging up).
// Always: interlaced lines, a slow rolling band, a faint flicker.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float build;
    float settle;
    float staticAmt;
    float flash;
    float time;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

#include "noise.glsl"

vec4 at(vec2 p) {
    if (p.x < 0.0 || p.x > 1.0) return vec4(0.0);
    return texture(source, p);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float py = uv.y * size.y;
    float frame = floor(time * 30.0);
    float unsettled = 1.0 - clamp(settle, 0.0, 1.0);

    // rows jitter sideways while the signal locks on
    float rowN = floor(py / 3.0);
    float jit = (hash(vec2(rowN, frame)) - 0.5) * 0.035 * unsettled * unsettled;
    jit += (hash(vec2(floor(py / 24.0), frame + 3.0)) - 0.5) * 0.06 * staticAmt;
    vec2 p = uv + vec2(jit, 0.0);
    float split = 0.0012 + 0.009 * unsettled + 0.006 * staticAmt;
    vec4 c = at(p);
    vec4 cr = at(p + vec2(split, 0.0));
    vec4 cb = at(p - vec2(split, 0.0));
    vec4 col = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));

    // interlace and the rolling band
    col.rgb *= 1.0 - 0.16 * mod(floor(py), 2.0);
    float roll = fract(uv.y * 0.6 - time * 0.11);
    col.rgb += tint.rgb * smoothstep(0.93, 1.0, roll) * 0.07 * col.a;

    // build: nothing below the scan front, the front itself a bright line
    float front = build * 1.04;
    col *= step(uv.y, front);
    float edge = smoothstep(4.0 / size.y, 0.0, abs(uv.y - front)) * (1.0 - step(0.999, build));
    col += vec4(mix(tint.rgb, vec3(1.0), 0.4), 1.0) * edge * 0.9;

    // static
    float n = hash(vec2(floor(uv.x * size.x / 2.0), floor(py / 2.0)) + fract(time * 13.7));
    vec4 stat = vec4(mix(tint.rgb, vec3(1.0), n) * n, 1.0) * 0.75 * step(0.25, n);
    col = mix(col, stat * max(col.a, 0.35), staticAmt);

    // flash and flicker
    col.rgb += tint.rgb * flash * col.a;
    col.rgb = mix(col.rgb, vec3(col.a), flash * 0.5);
    col *= 0.95 + 0.05 * hash1(frame);
    fragColor = col * qt_Opacity;
}
