#version 440

// Ripple: an expanding ring spreads from the centre, refracting the image as
// it passes and leaving the new wallpaper in its wake.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

void main() {
    vec2  d       = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5);
    float dist    = length(d);
    float maxDist = length(vec2(0.5 * aspect, 0.5));
    float nd      = dist / maxDist;                 // 0 at centre, 1 at corner

    float edge = 0.12;
    float p    = progress * (1.0 + 2.0 * edge) - edge;

    // displace the sample along the radial direction, strongest right at the
    // wavefront so the ring visibly distorts the picture as it travels.
    float band   = smoothstep(edge, 0.0, abs(nd - p));
    float ripple = sin((nd - p) * 60.0) * 0.03 * band;
    vec2  dir    = d / max(dist, 1e-4);
    vec2  uv     = qt_TexCoord0 + dir * ripple;

    float wTo = 1.0 - smoothstep(p - edge, p + edge, nd);

    fragColor = mix(texture(fromTex, uv),
                    texture(toTex,   uv), wTo) * qt_Opacity;
}
