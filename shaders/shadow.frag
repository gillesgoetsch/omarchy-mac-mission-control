#version 440

// A window's drop shadow exactly as Hyprland draws it (render/shaders/shadow.frag):
// full strength at the window's edge, falling to nothing over `range` pixels
// as (distance from the outer edge / range) ^ power, radial at the corners.
// Compiled to the plugin's shadow.frag.qsb by scripts/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float range;
    float power;
    vec2 size;
    vec4 tint;   // straight alpha
};

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = min(p, size - p);
    float a = 1.0;
    if (d.x < range && d.y < range) {
        float dist = distance(d, vec2(range));
        a = dist >= range ? 0.0 : pow((range - dist) / range, power);
    } else {
        float s = min(d.x, d.y);
        if (s < range)
            a = pow(max(s, 0.0) / range, power);
    }
    float alpha = tint.a * a * qt_Opacity;
    fragColor = vec4(tint.rgb * alpha, alpha);
}
