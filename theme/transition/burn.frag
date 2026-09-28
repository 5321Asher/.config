#version 440
// The "burn" switch transition (Grimoire): the old picture burns away from a scatter of embers. A
// ragged front eats across it, leaving a scorched brown band with a glowing edge in the new accent.
// Compiled to burn.frag.qsb (qsb; see quickshell/grimoire/shaders/build.sh).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;      // 0 = the old picture whole, 1 = burned away
    float aspect;        // width / height
    float seed;
    vec4 accent;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y);
    // where it catches first: near a few embers, then wherever the paper is thin
    float spots = 1.0;
    for (int i = 0; i < 4; i++) {
        vec2 c = vec2(hash(vec2(seed, float(i))) * aspect, hash(vec2(float(i), seed + 3.0)));
        spots = min(spots, length(p - c) / (0.9 + aspect * 0.35));
    }
    float n = fbm(p * 3.2 + seed) * 0.55 + spots * 0.75;          // 0 .. ~1.3: burn order
    float front = progress * 1.45 - 0.08;
    float edge = n - front;                                          // > 0: still paper
    if (edge <= 0.0) { fragColor = vec4(0.0); return; }

    vec4 c = texture(source, uv);
    float ember = 1.0 - smoothstep(0.0, 0.035, edge);                // the glowing lip
    float scorch = 1.0 - smoothstep(0.0, 0.14, edge);                // the brown band before it
    vec3 col = mix(c.rgb, c.rgb * vec3(0.35, 0.22, 0.12), scorch * 0.9);
    vec3 hot = mix(accent.rgb, vec3(1.0, 0.93, 0.7), ember * ember);
    col = mix(col, hot * 1.3, ember);
    float a = smoothstep(0.0, 0.006, edge);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
