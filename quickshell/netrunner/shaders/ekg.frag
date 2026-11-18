#version 440
// The flatline lock's screen: a medical monitor. The desktop snapshot drains to red (`drain`) and
// squeezes into a band round the middle (`squeeze` 1 = only a line left), with the band's edges lit;
// a monitor grid behind; and the EKG trace across the middle, written by a head sweeping left to
// right (`head`, 0..1), each beat a PQRST complex at its x with its own amplitude (b0..b3: x, amp
// pairs; amp < 0 = an arrhythmic, jagged one), the older trace fading, a gap ahead of the head.
// `flash` whites it out (the defibrillator), `alert` turns the trace red.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float squeeze;
    float drain;
    float flash;
    float alert;
    float head;
    float time;
    float hasShot;
    float trace;      // how much of the trace shows (0..1)
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 line;
    vec4 red;
    vec4 base;
};
layout(binding = 1) uniform sampler2D shot;

#include "noise.glsl"

float pqrst(float t)
{
    return 0.12 * exp(-pow((t - 0.15) / 0.035, 2.0))
         - 0.15 * exp(-pow((t - 0.31) / 0.012, 2.0))
         + 1.00 * exp(-pow((t - 0.35) / 0.014, 2.0))
         - 0.25 * exp(-pow((t - 0.39) / 0.014, 2.0))
         + 0.22 * exp(-pow((t - 0.62) / 0.06, 2.0));
}
float jag(float t)
{
    if (t < 0.0 || t > 1.0) return 0.0;
    return (hash1(floor(t * 14.0) + 3.7) - 0.5) * 1.6 * sin(t * 3.14159);
}
float beatAt(float x, vec2 b)
{
    const float W = 0.11;
    if (b.y == 0.0) return 0.0;
    float t = (x - b.x) / W;
    if (t < 0.0 || t > 1.0) return 0.0;
    return b.y > 0.0 ? b.y * pqrst(t) : -b.y * jag(t);
}
float traceY(float x)
{
    return beatAt(x, b0.xy) + beatAt(x, b0.zw) + beatAt(x, b1.xy) + beatAt(x, b1.zw)
         + beatAt(x, b2.xy) + beatAt(x, b2.zw) + beatAt(x, b3.xy) + beatAt(x, b3.zw);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float mid = 0.5;

    // the monitor's grid
    vec2 cell = abs(fract(px / 40.0) - 0.5);
    float minor = 1.0 - smoothstep(0.0, 0.03, 0.5 - max(cell.x, cell.y));
    vec2 big = abs(fract(px / 200.0) - 0.5);
    float major = 1.0 - smoothstep(0.0, 0.008, 0.5 - max(big.x, big.y));
    vec3 col = base.rgb + red.rgb * (minor * 0.035 + major * 0.06);

    // the desktop, drained and squeezed into the band
    float hw = (1.0 - clamp(squeeze, 0.0, 1.0)) * 0.5;
    float inBand = step(abs(uv.y - mid), hw);
    if (hw > 0.0005 && hasShot > 0.5) {
        vec2 s = vec2(uv.x, mid + (uv.y - mid) / max(hw * 2.0, 0.001));
        vec3 d = texture(shot, s).rgb;
        float l = dot(d, vec3(0.3, 0.59, 0.11));
        d = mix(d, red.rgb * l * 1.6, clamp(drain, 0.0, 1.0));
        d *= 1.0 - 0.6 * drain;
        col = mix(col, d, inBand);
    }
    float bandEdge = exp(-pow((abs(uv.y - mid) - hw) * size.y / 2.0, 2.0)) * step(0.0005, hw) * step(hw, 0.4999);
    col += red.rgb * bandEdge * 0.9;

    // the trace
    if (trace > 0.0) {
        const float A = 0.12;                      // a full beat's height, in screen heights
        float x = uv.x;
        float y0 = mid - traceY(x) * A;
        float yl = mid - traceY(x - 1.0 / size.x) * A;
        float yr = mid - traceY(x + 1.0 / size.x) * A;
        float slope = (yr - yl) * size.y / 2.0;
        float dist = abs(uv.y - y0) * size.y / sqrt(1.0 + slope * slope);
        float age = fract(head - x + 1.0);          // 0 = just written
        float shown = (1.0 - smoothstep(0.92, 0.97, age)) * (1.0 - age * 0.75);
        vec3 tc = mix(line.rgb, red.rgb, clamp(alert, 0.0, 1.0));
        float core = 1.0 - smoothstep(0.6, 1.8, dist);
        float glow = exp(-dist * 0.18) * 0.35;
        col += tc * (core + glow) * shown * trace;
        // the write head
        float hy = mid - traceY(head) * A;
        float hd = length((uv - vec2(head, hy)) * size);
        col += mix(tc, vec3(1.0), 0.6) * exp(-hd * 0.25) * 1.2 * trace;
    }

    col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
