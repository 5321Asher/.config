#version 440
// The dark behind the arcana: the desk sinking into shadow, a pool of warm candlelight where the
// cards lie, and smoke drifting slowly up through it. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float time;
    vec2 pool;          // where the light falls, in 0..1
    vec4 dark;
    vec4 warm;
    vec4 arcane;
};

#include "noise.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = size.x / max(size.y, 1.0);
    vec2 p = vec2((uv.x - pool.x) * aspect, uv.y - pool.y);

    // smoke: two layers of warped noise drifting upwards at different speeds
    vec2 q = vec2(uv.x * aspect, uv.y) * 2.2;
    float w = fbm(q + vec2(0.0, time * 0.035));
    float smoke = fbm(q * 1.3 + vec2(w * 1.6, time * 0.06));
    smoke = smoothstep(0.42, 0.95, smoke);

    float light = exp(-dot(p, p) * 2.4);
    float vignette = smoothstep(0.35, 1.25, length((uv - 0.5) * vec2(aspect, 1.0)));

    float a = mix(0.8, 0.94, vignette) - light * 0.14;
    vec3 col = dark.rgb * (1.0 - vignette * 0.5);
    col += warm.rgb * light * 0.12;
    col += mix(arcane.rgb, warm.rgb, light) * smoke * (0.05 + light * 0.08);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
