#version 440
// The "dots" switch transition (Glyph): a wave runs out from the centre; where it passes, the old
// picture collapses into a matrix of round dots (each the colour of its cell's centre, draining to
// grey), and the dots shrink away, showing the new desktop. Compiled to dots.frag.qsb with
// /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o dots.frag.qsb dots.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;      // 0 = the old picture whole, 1 = gone
    vec2 size;           // px
    float pitch;         // the dots' spacing, px
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;
    vec2 o = size * 0.5;
    float band = pitch * 26.0;
    float far = length(o) + band;
    // k: 0 = untouched … 1 = gone, per cell, behind a front moving out from the centre
    float k = clamp((progress * (far + band) - distance(c, o)) / band, 0.0, 1.0);

    float a = clamp(k / 0.35, 0.0, 1.0);             // the picture gathering into dots
    float b = clamp((k - 0.35) / 0.65, 0.0, 1.0);    // the dots shrinking away
    vec2 uv = mix(p, c, a) / size;
    vec4 t = texture(source, uv);
    float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(t.rgb, vec3(l), b);

    float r = pitch * mix(0.75, 0.34, a) * (1.0 - b);
    float m = 1.0 - smoothstep(r - 0.7, r + 0.7, distance(p, c));
    if (k <= 0.0) m = 1.0;
    fragColor = vec4(col, 1.0) * m * qt_Opacity;
}
