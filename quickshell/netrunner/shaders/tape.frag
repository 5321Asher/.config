#version 440
// The braindance viewer: scrubbing the recording. `amount` 0..1 is the rewind (wobbling rows,
// tears rolling down, a red / cyan split, noise lines, a tint wash); `pixel` > 1 is the
// reconstruction (the frame resolving from blocks of that many pixels): sharp above `sweep`, blocks
// below it, and a bright scan line at the front.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float amount;
    float pixel;
    float sweep;
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
    float a = clamp(amount, 0.0, 1.0);
    vec2 q = uv;
    if (pixel > 1.5 && uv.y > sweep) {
        vec2 b = vec2(pixel) / size;
        q = (floor(uv / b) + 0.5) * b;
    }
    float py = uv.y * size.y;
    float frame = floor(time * 60.0);
    float wob = sin(py * 0.045 + time * 37.0) * 0.004 * a;
    float tearY = fract(time * 1.3);
    float tear = smoothstep(0.07, 0.0, abs(uv.y - tearY)) * a;
    float tear2 = smoothstep(0.025, 0.0, abs(uv.y - fract(time * 2.7 + 0.37))) * a;
    q.x += wob + tear * 0.07 * (hash(vec2(floor(py / 2.0), frame)) - 0.25) + tear2 * 0.035;
    float split = a * 0.007 + tear * 0.01;
    vec4 c = at(q);
    vec4 cr = at(q + vec2(split, 0.0));
    vec4 cb = at(q - vec2(split, 0.0));
    vec4 col = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));
    float nl = step(0.988, hash(vec2(floor(py / 1.5), frame))) * a;
    col += vec4(vec3(0.55), 0.55) * nl;
    col.rgb = mix(col.rgb, col.rgb * (0.6 + tint.rgb), a * 0.3);
    col.rgb *= 1.0 - 0.12 * a * mod(floor(py / 2.0), 2.0);
    float front = smoothstep(3.0 / size.y, 0.0, abs(uv.y - sweep)) * step(0.001, sweep) * (1.0 - step(0.999, sweep));
    col += vec4(tint.rgb, 1.0) * front * 0.85;
    fragColor = col * qt_Opacity;
}
